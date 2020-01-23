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
    #rewrite joins to be faster
    learnerlist <= connect_learner { |c| [c.val]}
    nodelist <= connect { |c| [c.val] } #rename connect_acceptor
    num_acceptors <= nodelist.group([], count(nodelist.key))
    clientlist <= client_request {|c| [c.val[0]]}

    #A Proposer creates a message, which we call a "Prepare", identified with a number n. 
    #Note that n is not the value to be proposed and maybe agreed on, but just a number which uniquely identifies this initial message by the proposer (to be sent to the acceptors). 
    #The number n must be greater than any number used in any of the previous Prepare messages by this Proposer. Then, it sends the Prepare message containing n to a Quorum of Acceptors. 
    #Note that the Prepare message only contains the number n (that is, it does not have to contain e.g. the proposed value, often denoted by v). The Proposer decides who is in the Quorum.
    #A Proposer should not initiate Paxos if it cannot communicate with at least a Quorum of Acceptors.

    #Assumes only 1 channel per tick
    propose_num <- (propose_num * client_request).pairs {|p, c| [p.key]}
    propose_num <+ (propose_num * client_request).pairs {|p, c| [p.key + 1]}

    accept_sent <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}
    all_advocate_val <+ (client_request * slot_num * propose_num).pairs {|c, s, p| [s.key, c.val[3], p.key + 1]}

    slot_num <- (slot_num * client_request).pairs {|p, c| [p.key]}
    slot_num <+ (slot_num * client_request).pairs {|p, c| [p.key + 1]}
    
    #Assuming 10 > num proposers, this ensures that all IDs are unique
    client_request_temp <= (client_request * propose_num * slot_num).combos {|c, p, s| [p.key*10 + $proposer_id, s.key]} 

    #Send prepare message (after all the preparation)
    prepare <~ (client_request_temp * nodelist).pairs {|c, n| [n.key, [c.key, c.val]]}

    #Receive promise from acceptor
    agreeing_acceptors <= promise {|p| [p.val[5], p.val[6], -1] if p.val[1]}
    #handle timeouts

    #If a Proposer receives a majority of Promises from a Quorum of Acceptors, it needs to set a value v to its proposal. 
    #If any Acceptors had previously accepted any proposal, then they'll have sent their values to the Proposer, who now must set the value of its proposal, v, 
    #to the value associated with the highest proposal number reported by the Acceptors, let's call it z. If none of the Acceptors had accepted a proposal up to this 
    #point, then the Proposer may choose the value it originally wanted to propose, say x[17]. The Proposer sends an Accept message, (n, v), to a Quorum of Acceptors 
    #with the chosen value for its proposal, v, and the proposal number n (which is the same as the number contained in the Prepare message previously sent to the Acceptors).
    #So, the Accept message is either (n, v=z) or, in case none of the Acceptors previously accepted a value, (n, v=x).

    all_advocate_val <= promise {|p| [p.val[5], p.val[3], p.val[4]] if p.val[1] and p.val[2]}
    max_advocate_val <= all_advocate_val.group([all_advocate_val.slot, all_advocate_val.id], max(all_advocate_val.val))

    agreeing_acceptors_for_slot <= (agreeing_acceptors * promise).pairs {|a, p| [a.val] if a.key == p.val[5]}
    agreeing_acceptor_size <= agreeing_acceptors_for_slot.group([], count(agreeing_acceptors_for_slot.key))

    accept_sent <= (num_acceptors * agreeing_acceptor_size * promise).combos {|n, a, p| [p.val[6].to_s+p.val[5].to_s, p.val[5], p.val[6]] if (p.val[1] and (a.key + 1)*2 > n.key)}
    stdio <~ promise.inspected
    stdio <~ agreeing_acceptor_size.inspected
    sent_for_slot <= accept_sent.group([accept_sent.key], count(accept_sent.val))
    #do a group with a scratch

    majority <= (num_acceptors * agreeing_acceptor_size * promise * sent_for_slot).combos {|n, a, p, s| [p.val[5], p.val[0]] if (p.val[5] == s.key and p.val[1] and (a.key + 1)*2 > n.key and s.val == 1)}

    #Send accept message to acceptors
    accept <~ (majority * nodelist * max_advocate_val).combos {|m, n, a| [n.key, [m.val, a.val, m.key]] if a.slot == m.key}

    accepted_to_learner <~ (accepted * learnerlist * num_acceptors).combos {|a, l, n| [l.key, append_info_for_learner(a.val, ding(n.key))]}
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