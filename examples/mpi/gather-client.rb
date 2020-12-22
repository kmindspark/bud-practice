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
    table :data_gather
    table :received_gather
    table :ips_gather
    channel :message_func_gather, [:@addr, :key] => [:val]
    periodic :timer, 1

    data_gather <+ [[0, 4.2], [1, 4.2], [2, 4.2], [3, 4.2]]
    root_ip <+ ["127.0.0.1:12345"]
  end

  bloom do
      message_func_gather <~ (root_ip * data_gather * timer).combos {|i, d, t| [i.key, @client_id, d.val] if (@sender > 0 and @client_id == d.key and ping(i.val))}
      received_gather <= message_func_gather {|m| [m.key, m.val]}
      stdio <~ message_func_gather.inspected
  end

  def wait()
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
