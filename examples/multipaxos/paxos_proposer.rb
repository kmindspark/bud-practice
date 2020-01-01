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

  def initialize(proposer_id, opts={})
    $proposer_id = proposer_id
    super opts
  end

  state do 
    num_acceptors <+ [[0]]
  end

  bloom do
    learnerlist <= connect_learner { |c| [c.val]}
    
    nodelist <= connect { |c| [c.val] }
    num_acceptors <- (connect * num_acceptors).pairs {|c, n| [n.key]}
    num_acceptors <+ (connect * num_acceptors).pairs {|c, n| [n.key + 1]}

    clientlist <= client_request {|c| [c.val[0]]}
    client_request_temp <= client_request {|c| [get_new_num(c.val), $slot_number]}
    prepare <~ (client_request_temp * nodelist).pairs {|c, n| [n.key, [c.key, c.val]]}

    majority <= (promise * num_acceptors).pairs {|p, n| [p.val[5], p.val[0]] if process_promise(p.val, n.key)}
    accept <~ (majority * nodelist).pairs {|m, n| [n.key, [m.val, $advocate_val[m.key], m.key]]}
    accepted_to_client <~ (accepted * clientlist).pairs {|a, c| [c.key, a.val]}

    accepted_to_learner <~ (accepted * learnerlist * num_acceptors).combos {|a, l, n| [l.key, append_info_for_learner(a.val, n.key)]} 
    stdio <~ accepted.inspected
  end

  def test_print(val)
    puts val
    return true
  end

  def append_info_for_learner(val, val2)
    val.push(val2)
    return val
  end

  def register_new_acceptor()
    $total_acceptors = $total_acceptors + 1
    puts "Total acceptors: " + $total_acceptors.to_s
    return true
  end

  def get_new_num(advocate)
    $slot_number = $slot_number + 1
    client_addr = advocate[0]
    advocate = advocate[3]
    puts advocate
    $transaction_in_progress[$slot_number + 1] = 1
    $agreeing_acceptors[$slot_number] = 0
    $propose_number = $propose_number + 1
    $advocate_val[$slot_number] = advocate.to_i
    $accept_sent[$slot_number] = false
    return $propose_number*10 + $proposer_id
  end

  def end_transaction()
    $advocate_val = 0
    $agreeing_acceptors = 0
    $highest_id_responded = 0
    $transaction_in_progress = 0
  end

  def process_promise(promise_val, total_acceptors)
    puts promise_val
    slot_number = promise_val[5]
    if promise_val[1] == false
      return false
    else
      $agreeing_acceptors[slot_number] += 1
      if promise_val[3] > ($highest_id_responded[slot_number] || 0) and promise_val[2] == true
        $highest_id_responded[slot_number] = promise_val[3]
        $advocate_val[slot_number] = promise_val[4]
      end
      puts "PRINTING"
      puts $agreeing_acceptors[slot_number]
      puts total_acceptors
      puts $agreeing_acceptors[slot_number] - total_acceptors/2
      
      if $agreeing_acceptors[slot_number] > total_acceptors/2 and !$accept_sent[slot_number]
        $accept_sent[slot_number] = true
        return true
      end
      return false
    end
  end
end

# ruby command-line wrangling
unique_id = ARGV[0].to_i
addr = ARGV[1] ? ARGV[1] : PaxosProtocol::DEFAULT_PROPOSER_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = PaxosProposer.new(unique_id, :ip => ip, :port => port.to_i, :stdin => $stdin)
program.run_fg