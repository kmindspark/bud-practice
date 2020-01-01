require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'
require 'pp'

class PaxosLearner
  include Bud
  include PaxosProtocol
  $latest_num_acceptors = 0
  $number_of_yes = {}
  $entries_in_slots = {}

  def initialize(proposer, opts={})
    @proposer = proposer
    super opts
  end

  bootstrap do
    connect_learner <~ [[@proposer, ip_port]]
  end

  bloom do
    promise <~ prepare {|p| [@proposer, check_nums(p.val)]}
    accepted <~ accept {|a| [@proposer, check_accept(a.val)]}    
    stdio <~ accepted_to_learner{|a| [process_print(a.val)]}
  end
  
  def process_print(val)
    puts "PRINTING"
    puts val[3]
    $latest_num_acceptors = val[3]
    $number_of_yes[val[1]] = 1 + ($number_of_yes[val[1]] || 0)
    if $number_of_yes[val[1]] > $latest_num_acceptors/2
      $entries_in_slots[val[1]] = val[2]
      pp $entries_in_slots
    end
    puts "Done printing update"
  end
end

# ruby command-line wrangling
server = (ARGV.length == 2) ? ARGV[1] : PaxosProtocol::DEFAULT_PROPOSER_ADDR
puts "Server address: #{server}"
program = PaxosLearner.new(server, :stdin => $stdin)
program.run_fg