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
    num_acceptors <+ [[0]]
    propose_num <+ [[1]]
    slot_num <+ [[0]]
  end

  bloom do
    #rewrite joins to be faster
    #learnerlist <= connect_learner { |c| [c.val]}
    #nodelist <= connect { |c| [c.val] } #rename connect_acceptor
    #num_acceptors <= nodelist.group([], count(nodelist.key))
    #clientlist <= client_request {|c| [c.val[0]]}

    #A Proposer creates a message, which we call a "Prepare", identified with a number n.
    #Note that n is not the value to be proposed and maybe agreed on, but just a number which uniquely identifies this initial message by the proposer (to be sent to the acceptors).
    #The number n must be greater than any number used in any of the previous Prepare messages by this Proposer. Then, it sends the Prepare message containing n to a Quorum of Acceptors.
    #Note that the Prepare message only contains the number n (that is, it does not have to contain e.g. the proposed value, often denoted by v). The Proposer decides who is in the Quorum.
    #A Proposer should not initiate Paxos if it cannot communicate with at least a Quorum of Acceptors.

    #Assumes only 1 channel per tick
    #propose_num <- (propose_num * client_request).pairs {|p, c| [p.key]}
    #propose_num <+ (propose_num * client_request).pairs {|p, c| [p.key + 1]}
    #stdio <~ client_request.inspected

    #accept_sent <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}

    all_advocate_val <= (timer * slot_num).pairs {|c, p| [s.key, Time.now.to_f*10 + $proposer_id, Time.now.to_f*10 + 0.001]}

    slot_num <- (slot_num * all_advocate_val).pairs {|p, c| [p.key]}
    slot_num <+ (slot_num * all_advocate_val).pairs {|p, c| [p.key + 1]}

    #Assuming 10 > num proposers, this ensures that all IDs are unique
    client_request_temp <= (all_advocate_val * slot_num).combos {|c, s| [c.id, s.key]}

    #Send prepare message (after all the preparation)
    prepare <~ client_request_temp {|c| ["127.0.0.1:12346", [c.key, c.val]]}

    #Receive promise from acceptor
    #agreeing_acceptors <= promise {|p| [p.slot, p.ip, -1] if p.valid}
    #handle timeouts

    #If a Proposer receives a majority of Promises from a Quorum of Acceptors, it needs to set a value v to its proposal.
    #If any Acceptors had previously accepted any proposal, then they'll have sent their values to the Proposer, who now must set the value of its proposal, v,
    #to the value associated with the highest proposal number reported by the Acceptors, let's call it z. If none of the Acceptors had accepted a proposal up to this
    #point, then the Proposer may choose the value it originally wanted to propose, say x[17]. The Proposer sends an Accept message, (n, v), to a Quorum of Acceptors
    #with the chosen value for its proposal, v, and the proposal number n (which is the same as the number contained in the Prepare message previously sent to the Acceptors).
    #So, the Accept message is either (n, v=z) or, in case none of the Acceptors previously accepted a value, (n, v=x).

    #all_advocate_val <= promise {|p| [p.slot, p.max_prev_id, p.max_prev_val] if p.valid and p.have_prev_val}
    #max_advocate_val_temp <= all_advocate_val.group([all_advocate_val.slot], max(all_advocate_val.id))
    #stdio <~ all_advocate_val.inspected
    #max_advocate_val <= (max_advocate_val_temp * all_advocate_val).combos(max_advocate_val_temp.slot => all_advocate_val.slot) {|m, a| [m.slot, m.id, a.val] if m.id == a.id}
    #all_advocate_val <- max_advocate_val {|m| [m.slot, m.id, m.val]}
    all_advocate_val <- all_advocate_val {|a| a}
    #sink2 <= all_advocate_val {|a| [a.slot, 1] if ding(a.slot)}

    #agreeing_acceptors_for_slot <= (agreeing_acceptors * promise).pairs(:key=>:slot) {|a, p| [a.val]}
    #agreeing_acceptor_size <= agreeing_acceptors_for_slot.group([], count(agreeing_acceptors_for_slot.key))

    #accept_sent <= (num_acceptors * agreeing_acceptor_size * promise).combos {|n, a, p| [p.ip.to_s+p.slot.to_s, p.slot, p.ip] if (p.valid and (a.key + 1)*2 > n.key)}
    #sent_for_slot <= accept_sent.group([accept_sent.key], count(accept_sent.val))
    #do a group with a scratch

    #stdio <~ accept_sent.inspected
    #stdio <~ sent_for_slot.inspected

    #majority <= (num_acceptors * agreeing_acceptor_size * promise * sent_for_slot).combos(promise.slot => sent_for_slot.key) {|n, a, p, s| [p.slot, p.id] if (p.valid and (a.key + 1)*2 > n.key and s.val == 1)}
    sink <= promise {|p| [test_print(Time.now.to_f - p.timestamp)]}

    #Send accept message to acceptors
    #accept <~ (majority * nodelist * max_advocate_val).combos(max_advocate_val.slot => majority.key) {|m, n, a| [n.key, [m.val, a.val, m.key, Time.now.to_f]]}#

    #all_advocate_val <- (majority * max_advocate_val).combos(max_advocate_val.slot => majority.key) {|m, a| [m.key]}
    #accept_sent <- (majority * max_advocate_val).combos(max_advocate_val.slot => majority.key) {|m, a| [m.key]}
    #agreeing_acceptors <- (majority * max_advocate_val).combos(max_advocate_val.slot => majority.key) {|m, a| [m.key]}
    #majority <- (majority * max_advocate_val).combos(max_advocate_val.slot => majority.key) {|m, a| [m.val]}
    #majority <- majority {|m| [m.key]}

    #accepted_to_learner <~ (accepted * clientlist * num_acceptors).combos {|a, l, n| [l.key, append_info_for_learner(a.val, n.key)]}
    #accepted_to_learner <~ accepted {|a| ["127.0.0.1:12347", append_info_for_learner(a.val, 1, Time.now.to_f)]}

    #sink <= test_channel {|c| [test_print(Time.now.to_f - c.val[0])]}
  end

  def print_gc()
    #puts GC.stat
  end

  def ding(val)
    puts val
    return true #val
  end

  def test_print(val)
    puts "test_delta, " + val.to_s
    return true
  end

  def append_info_for_learner(val, val2, t)
    val.push(val2)
    #puts "appending info"
    #print_gc()
    puts "issue_delta, " + (t - val[2]).to_s
    val[2] = Time.now.to_f
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
addr = ARGV[1]
ip, port = addr.split(":")
acceptor_addr = ARGV[2]
puts "Proposer"
puts "Server address: #{ip}:#{port}"
puts "Acceptor address: #{acceptor_addr}"
program = PaxosProposer.new(unique_id, acceptor_addr, :ip => ip, :port => port.to_i, :stdin => $stdin)
program.run_fg