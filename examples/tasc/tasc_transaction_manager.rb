require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosAcceptor
  include Bud
  include PaxosProtocol
  $max_promise_id = {}
  $max_accept_val = {}

  def initialize(proposer, opts={})
    @proposer = proposer
    super opts
  end

  bootstrap do
    connect <~ [[@proposer, ip_port]]
    tx_id <= [[0]]
  end

  bloom do
    tx_id <= (client_get_request * tx_id).pairs {|client, tx_id| [tx_id.key + 1]}
    get_transaction <= (client_get_request * tx_id).pairs {|client, tx_id| [tx_id.key, c.val] if c.val == "get"}
    put_transaction <= (client_get_request * tx_id).pairs {|client, tx_id| [tx_id.key, c.val] if c.val == "put"}

    read_result <~ (get_transaction * put_transaction).pairs {|get, put| [tx_id.key, c.val] if get.val[2] == put.val[2]} #compare keys


  end
end

# ruby command-line wrangling
my_addr = ARGV[0]
ip, port = my_addr.split(":")
server_addr = ARGV[1]
puts "Acceptor"
puts "Server address: #{server_addr}"
puts "IP Port address: #{ip}:#{port}"
program = PaxosAcceptor.new(server_addr, :ip => ip, :port => port, :stdin => $stdin)
program.run_fg

#Non-monotone downstream of network
#Chunks without non-monotone
#Counting till a threshold, use a table
#Nesting a lattice within a tuple (sandbox)
#Put in comments