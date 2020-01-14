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
    propose_num <+ [[1]]
    slot_num <+ [[0]]
  end

  bloom do
    learnerlist <= connect_learner { |c| [c.val]}
    
    nodelist <= connect { |c| [c.val] }
    num_acceptors <= nodelist.group([], count(nodelist.key))
    #stdio <~ num_acceptors.inspected

    clientlist <= client_request {|c| [c.val[0]]}

    #A Proposer creates a message, which we call a "Prepare", identified with a number n. 
    #Note that n is not the value to be proposed and maybe agreed on, but just a number which uniquely identifies this initial message by the proposer (to be sent to the acceptors). 
    #The number n must be greater than any number used in any of the previous Prepare messages by this Proposer. Then, it sends the Prepare message containing n to a Quorum of Acceptors. 
    #Note that the Prepare message only contains the number n (that is, it does not have to contain e.g. the proposed value, often denoted by v). The Proposer decides who is in the Quorum.
    #A Proposer should not initiate Paxos if it cannot communicate with at least a Quorum of Acceptors.
    propose_num <- (propose_num * client_request).pairs {|p, c| [p.key]}
    propose_num <+ (propose_num * client_request).pairs {|p, c| [p.key + 1]}

    accept_sent <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}
    #agreeing_acceptors <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}
    highest_id_responded <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}
    advocate_val <+ (client_request * slot_num).pairs {|c, s| [s.key, c.val[3]]}

    slot_num <- (slot_num * client_request).pairs {|p, c| [p.key]}
    slot_num <+ (slot_num * client_request).pairs {|p, c| [p.key + 1]}
    
    client_request_temp <= (client_request * propose_num * slot_num).combos {|c, p, s| [p.key*10 + $proposer_id, s.key]}

    prepare <~ (client_request_temp * nodelist).pairs {|c, n| [n.key, [c.key, c.val]]}

    agreeing_acceptors <= promise {|p| [p.val[5], p.val[6], -1] if p.val[1]}

    highest_id_responded <- (highest_id_responded * promise).pairs {|a, p| [p.val[5], a.val] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}
    highest_id_responded <+ (highest_id_responded * promise).pairs {|a, p| [p.val[5], p.val[3]] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}

    advocate_val <- (highest_id_responded * promise).pairs {|a, p| [p.val[5], a.val] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}
    advocate_val <+ (highest_id_responded * promise).pairs {|a, p| [p.val[5], p.val[4]] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}

    agreeing_acceptors_for_slot <= (agreeing_acceptors * promise).pairs {|a, p| [a.val] if a.key == p.val[5]}
    agreeing_acceptor_size <= agreeing_acceptors_for_slot.group([], count(agreeing_acceptors_for_slot.key))

    accept_sent <- (num_acceptors * agreeing_acceptor_size * promise * accept_sent).combos {|n, a, p, s| [s.key, 0] if (p.val[5] == s.key and p.val[1] and (a.key + 1)*2 > n.key and s.val == 0)}
    accept_sent <+ (num_acceptors * agreeing_acceptor_size * promise * accept_sent).combos {|n, a, p, s| [s.key, 1] if (p.val[5] == s.key and p.val[1] and (a.key + 1)*2 > n.key and s.val == 0)}

    #stdio <~ agreeing_acceptors.inspected

    majority <= (num_acceptors * agreeing_acceptor_size * promise * accept_sent).combos {|n, a, p, s| [p.val[5], p.val[0]] if (p.val[5] == s.key and p.val[1] and (a.key + 1)*2 > n.key and s.val == 0)}
    #majority_for_slot <= (promise * majority) {|p, m| [m.key, m.val] if m.key == p.val[5]}

    accept <~ (majority * nodelist * advocate_val).combos {|m, n, a| [n.key, [m.val, a.val, m.key]] if a.key == m.key}
    #accepted_to_client <~ (accepted * clientlist).pairs {|a, c| [c.key, a.val]}

    accepted_to_learner <~ (accepted * learnerlist * num_acceptors).combos {|a, l, n| [l.key, append_info_for_learner(a.val, ding(n.key))]} 
    stdio <~ accepted.inspected
    stdio <~ learnerlist.inspected
  end

  def ding(val)
    puts val
    return val
  end

  def test_print(val)
    puts val
    return true
  end

  def append_info_for_learner(val, val2)
    val.push(val2)
    return val
  end

  def get_new_num(advocate)
    $slot_number = $slot_number + 1
    client_addr = advocate[0]
    advocate = advocate[3]
    puts advocate
    $transaction_in_progress[$slot_number + 1] = 1
    $agreeing_acceptors[$slot_number] = 0
    $propose_number = $propose_number + 1
    $advocate_val[$slot_number] = advocate
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