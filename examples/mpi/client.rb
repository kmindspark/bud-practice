require 'rubygems'
require 'backports'
require 'bud'
require_relative 'protocol'
require_relative 'client_module'

class Client
  include Bud
  #include Protocol
  include ClientModule

  def initialize(server, sender, num_receivers, id, opts={})
    @server = server
    @sender = sender.to_i
    @num_receivers = num_receivers.to_i
    @fn_ip_port = "127.0.0.1:1235"
    @client_id = id.to_i
    super opts
  end

  def wait()
    sleep(10)
    puts("sending...")
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
