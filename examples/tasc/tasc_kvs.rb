require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosProposer
  include Bud
  include PaxosProtocol
  $propose_number = 0
  $slot_number = 0
  $advocate_map = {}
  $advocate_val = {}
  $agreeing_acceptors = {}
  $highest_id_responded = {}
  $transaction_in_progress = {}
  $accept_sent = {}
  $client_addr = 0
  $proposer_id = 0
  $acceptor_addr

  def initialize(proposer_id, acceptor_addr, opts={})
    $proposer_id = proposer_id
    $acceptor_addr = acceptor_addr
    puts $acceptor_addr
    super opts
  end

  state do
    key_node_read.notin(main_storage, :key=>:key) {|c, pid| true}
  end

  bloom do

  end
end

# ruby command-line wrangling
unique_id = ARGV[0].to_i
addr = ARGV[1]
ip, port = addr.split(":")
acceptor_addr = ARGV[2]
puts "Proposer"
puts "Server address: #{ip}:#{port}"
puts "Acceptor address: #{acceptor_addr}"
program = PaxosProposer.new(unique_id, acceptor_addr, :ip => ip, :port => port.to_i, :stdin => $stdin)
program.run_fg