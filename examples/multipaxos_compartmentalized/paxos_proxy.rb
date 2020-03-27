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
  $proxy_id = 0

  def initialize(proxy_id, opts={})
    $proxy_id = proxy_id
    puts opts
    super opts
  end

  bootstrap do 
    num_acceptors <+ [[0]]
    connect_proxy <~ [[PaxosProtocol::DEFAULT_PROPOSER_ADDR, ip_port, $proxy_id]]
  end

  bloom do
    #rewrite joins to be faster
    nodelist <= acceptor_to_proxy {|a| [a.val, a.group_num]} #rename connect_acceptor

    acceptors_group_zero <= nodelist {|n| [n.key] if n.val == 0}
    num_acceptors <= acceptors_group_zero.group([], count(acceptors_group_zero.key))

    all_advocate_val <+ (prepare_to_proxy).pairs {|c| [p.val[1], p.val[2], p.val[0]]} #slot, val to advocate, id

    prepare <~ (prepare_to_proxy * nodelist).pairs {|p, n| [n.key, [p.val[0], p.val[1], ip_port]] if p.val[1] % 3 == n.val}

    #prepare <~ (client_request_temp * nodelist).pairs {|c, n| [n.key, [c.key, c.val]]}

    #Receive promise from acceptor
    agreeing_acceptors <= promise {|p| [p.slot, p.ip, -1] if p.valid}
    #handle timeouts

    #If a Proposer receives a majority of Promises from a Quorum of Acceptors, it needs to set a value v to its proposal. 
    #If any Acceptors had previously accepted any proposal, then they'll have sent their values to the Proposer, who now must set the value of its proposal, v, 
    #to the value associated with the highest proposal number reported by the Acceptors, let's call it z. If none of the Acceptors had accepted a proposal up to this 
    #point, then the Proposer may choose the value it originally wanted to propose, say x[17]. The Proposer sends an Accept message, (n, v), to a Quorum of Acceptors 
    #with the chosen value for its proposal, v, and the proposal number n (which is the same as the number contained in the Prepare message previously sent to the Acceptors).
    #So, the Accept message is either (n, v=z) or, in case none of the Acceptors previously accepted a value, (n, v=x).
    #stdio <~ promise.inspected
    all_advocate_val <= promise {|p| [p.slot, p.max_prev_id, p.max_prev_val] if p.valid and p.have_prev_val}
    max_advocate_val <= all_advocate_val.group([all_advocate_val.slot, all_advocate_val.val], max(all_advocate_val.id))

    agreeing_acceptors_for_slot <= (agreeing_acceptors * promise).pairs(:key=>:slot) {|a, p| [a.val]}
    agreeing_acceptor_size <= agreeing_acceptors_for_slot.group([], count(agreeing_acceptors_for_slot.key))

    accept_sent <= (num_acceptors * agreeing_acceptor_size * promise).combos {|n, a, p| [p.ip.to_s+p.slot.to_s, p.slot, p.ip] if (p.valid and (a.key + 1)*2 > n.key)}
    sent_for_slot <= accept_sent.group([accept_sent.key], count(accept_sent.val))
    #do a group with a scratch

    #stdio <~ accept_sent.inspected
    #stdio <~ sent_for_slot.inspected

    majority <= (num_acceptors * agreeing_acceptor_size * promise * sent_for_slot).combos(promise.slot => sent_for_slot.key) {|n, a, p, s| [p.slot, p.id] if test_print("IM HERE1") and p.valid and test_print("IM HERE2") and (a.key + 1)*2 > n.key and test_print("IM HERE3") and s.val == 1 and test_print("IM HERE4")}
    stdio <~ majority.inspected
    stdio <~ max_advocate_val.inspected

    #Send accept message to acceptors
    accept <~ (majority * nodelist * max_advocate_val).combos(max_advocate_val.slot => majority.key) {|m, n, a| [n.key, [m.val, a.val, m.key, ip_port]] if test_print("IM HERE") and a.slot % 3 == n.group_num}

    accepted_to_proposer <~ (accepted * num_acceptors).combos {|a, n| [PaxosProtocol::DEFAULT_PROPOSER_ADDR, append_info_for_learner(a.val, n.key)]}
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
proxynum = ARGV[0].to_i
addr = ARGV[1] ? ARGV[1] : PaxosProtocol::DEFAULT_PROXY_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = PaxosProposer.new(proxynum, :stdin => $stdin) #:ip => ip, :port => port.to_i
program.run_fg