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
  include RingAllReduce

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
    table :received_allreduce
    table :ips_scatter
    table :ips_allreduce
    periodic :timer, 10

    channel :message_func_allreduce, [:@addr, :key] => [:val]
    channel :send_around, [:@addr, :key] => [:val]

    data_allreduce <+ [[0, 0.1], [1, 3.2], [2, 1], [3, 18]]
    #received_allreduce <+ [[0, 0]]
    ips_allreduce <+ [[0, "127.0.0.1:12345"], [1, "127.0.0.1:12346"], [2, "127.0.0.1:12347"], [3, "127.0.0.1:12348"]]
  end

  bloom do

      message_func_allreduce <~ (ips_allreduce * data_allreduce * timer).pairs {|i, d, t| [i.val, d.key, d.val] if i.key == (d.key + 1) % 4}

      message_func_allreduce <~ (message_func_allreduce * data_allreduce * ips_allreduce).combos {|m, d, i| [i.val, m.key, d.val + m.val] if i.key == (@client_id + 1) % 4 and m.key == d.key and m.key != @client_id}

      send_around <~ (message_func_allreduce * ips_allreduce).combos {|m, i| [i.val, m.key, m.val] if i.key == (m.key + 1) % 4 and m.key == @client_id }

      send_around <~ (send_around * ips_allreduce).pairs {|s, i| [i.val, s.key, s.val] if i.key == (@client_id + 1) % 4 and s.key != @client_id}# and #pp(s.key.to_s + ", " + s.val.to_s)}

      received_allreduce <= send_around {|s| [s.key, s.val]}

      stdio <~ received_allreduce.inspected
  end

  def wait()
    #sleep(10)
    #puts("sending...")
    return true
  end

  def pp(a)
    puts a.to_s
    return true
  end

  def hello()
    puts("HELLO")
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
