require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosLearner
  include Bud
  include PaxosProtocol
  $max_promise_id = {}
  $max_accept_val = {}

  bootstrap do
    connect <~ [[@proposer, ip_port]]
  end

  bloom do
    promise <~ prepare {|p| [@proposer, check_nums(p.val)]}
    accepted <~ accept {|a| [@proposer, check_accept(a.val)]}    
  end

# ruby command-line wrangling
server = (ARGV.length == 2) ? ARGV[1] : PaxosProtocol::DEFAULT_PROPOSER_ADDR
puts "Server address: #{server}"
program = PaxosLearner.new(:stdin => $stdin)
program.run_fg