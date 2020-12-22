require 'rubygems'
require 'backports'
require 'bud'
#require_relative 'protocol'
#require_relative 'client_module'
require_relative 'ring-allreduce'

class Client
  include Bud
  #include Protocol
  #include ClientModule
  #include RingAllReduce

  def initialize(server, sender, num_receivers, id, opts={})
    @server = server
    @sender = sender.to_i
    @num_receivers = num_receivers.to_i
    @fn_ip_port = "127.0.0.1:1235"
    @client_id = id.to_i
    puts "Initialized, client #" + @client_id.to_s
    super opts
  end

  state do
    table :data_allreduce
    table :data_scatter
    table :received_allreduce
    table :received_scatter
    table :ips_scatter
    table :ips_allreduce
    periodic :timer, 1

    channel :message_func_allreduce, [:@addr, :key] => [:val]
    channel :message_func_scatter#, [:@addr, :key] => [:val]

    data_scatter <+ [[0, 4.2], [1, 4.2], [2, 4.2], [3, 4.2]]
    #data_allreduce <+ [[0, 0.1], [1, 3.2], [2, 1], [3, 18]]
    #received_allreduce <+ [[0, 0]]
    ips_scatter <+ [[0, "127.0.0.1:12346"], [1, "127.0.0.1:12347"], [2, "127.0.0.1:12348"]] #[[0, "127.0.0.1:12350"], [1, "127.0.0.1:12351"], [2, "127.0.0.1:12352"], [3, "127.0.0.1:12353"]]
    #ips_allreduce <+ [[0, "127.0.0.1:12345"], [1, "127.0.0.1:12346"], [2, "127.0.0.1:12347"], [3, "127.0.0.1:12348"]]
  end

  bloom do
      message_func_scatter <~ (ips_scatter * data_scatter * timer).combos {|i, d, t| [i.val, d.val] if (@sender > 0 and (d.key % @num_receivers) == i.key and ping(i.val))}
      #message_func_scatter <~ (ips_scatter * timer).pairs {|i, d| [i.val, d.key] if @sender > 0}

      received_scatter <= message_func_scatter {|m| [m.val]}

      #data_allreduce <= stdio {|s| [10, 0] if hello()}
      stdio <~ message_func_scatter.inspected
      #stdio <~ timer.inspected
  end

  def wait()
    #sleep(10)
    #puts("sending...")
    return true
  end

  def hello()
    puts("HELLO")
    return true
  end

  def ping(s)
    puts(s)
    return true
  end
end

server = ARGV[0]
sender = ARGV[1]
num_receivers = ARGV[2]
id = ARGV[3]
ip, port = server.split(":")
puts "Server address: #{server}"
program = Client.new(server, sender, num_receivers, id, :ip=>ip, :port=>port, :stdin => $stdin)
program.run_fg
