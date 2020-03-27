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
  end

  bloom do
    #Any of the Acceptors waits for a Prepare message from any of the Proposers. If an Acceptor receives a Prepare message, 
    #the Acceptor must look at the identifier number n of the just received Prepare message. There are two cases.
    #If n is higher than every previous proposal number received, from any of the Proposers, by the Acceptor, then the Acceptor
    # must return a message, which we call a "Promise", to the Proposer, to ignore all future proposals having 
    #a number less than n. If the Acceptor accepted a proposal at some point in the past, it must include the previous proposal 
    #number, say m, and the corresponding accepted value, say w, in its response to the Proposer.
    #Otherwise (that is, n is less than or equal to any previous proposal number received from any Proposer by the Acceptor) the Acceptor can ignore the received proposal. It does not have to answer in this case for Paxos to work. 
    #However, for the sake of optimization, sending a denial (Nack) response would tell the Proposer that it can stop its attempt to create consensus with proposal n.
    cur_prep <= prepare {|p| [p.val[1]]}

    existing_id <= cur_prep.notin(max_promise_id, :key=>:key) {|c, pid| true}
    existing_val <= cur_prep.notin(max_accept_val, :key=>:key) {|c, pid| true}
    
    all_promise_id <+ prepare {|p| [p.val[1], p.val[0]]}
    max_promise_id <= all_promise_id.group([all_promise_id.key], max(all_promise_id.val))

    #stdio <~ max_promise_id.inspected

    #max_promise_id <- (max_promise_id * prepare).pairs {|pid, p| [pid.key, pid.val] if p.val[1] == pid.key and p.val[0] > pid.val}
    #max_promise_id <+ (prepare * max_promise_id).pairs {|p, pid| [p.val[1], p.val[0]] if p.val[1] == pid.key and p.val[0] > pid.val}
    #max_promise_id <+ (prepare * existing_id).pairs {|p, eid| [p.val[1], p.val[0]]}

    promise <~ (prepare * max_promise_id * max_accept_val).combos(max_promise_id.key => max_accept_val.key) {|p, mp, ma| [@proposer, p.val[0], p.val[0] == mp.val, ma.val > 0, mp.val, ma.val, p.val[1], ip_port] if p.val[1] == mp.key and p.val[0] > mp.val}
    promise <~ (prepare * max_promise_id * existing_val).combos {|p, mp, ma| [@proposer, p.val[0], p.val[0] == mp.val, false, mp.val, 0, p.val[1], ip_port] if p.val[1] == mp.key}
    promise <~ (prepare * existing_id * existing_val).combos {|p, mp, ma| [@proposer, p.val[0], true, false, 0, 0, p.val[1], ip_port] if p.val[1] == ma.key}
    #ensure that both are not populated at the same time, why mutually exclusive, enforce

    #If an Acceptor receives an Accept message, (n, v), from a Proposer, it must accept it if and only if it has not already promised (in Phase 1b of the Paxos protocol) to only consider proposals having an identifier greater than n.
    #If the Acceptor has not already promised (in Phase 1b) to only consider proposals having an identifier greater than n, it should register the value v (of the just received Accept message) as the accepted value (of the Protocol), 
    #and send an Accepted message to the Proposer and every Learner (which can typically be the Proposers themselves). Else, it can ignore the Accept message or request.
    #Note that an Acceptor can accept multiple proposals. This can happen when another Proposer, unaware of the new value being decided, starts a new round with a higher identification number n. 
    #In that case, the Acceptor can promise and later accept the new proposed value even though it has accepted another one earlier. These proposals may even have different values in the presence of certain failures[example needed]. 
    #However, the Paxos protocol will guarantee that the Acceptors will ultimately agree on a single value.
    all_accept_val <= accept {|a| [a.val[2], a.val[0], a.val[1]]}
    max_accept_val <= all_accept_val.group([all_accept_val.slot, all_accept_val.val], max(all_accept_val.id))

    accepted <~ (accept * max_promise_id).pairs {|a, pid| [@proposer, [false, a.val[2], a.val[1]]] if (pid.key == a.val[2] and a.val[0] < pid.val) }
    accepted <~ (accept * max_promise_id).pairs {|a, pid| [@proposer, [true, a.val[2], a.val[1]]] if pid.key == a.val[2] and a.val[0] >= pid.val }
    
    #max_accept_val <- (max_accept_val * accept * max_promise_id).combos {|mpv, a, pid| [mpv.key, mpv.val] if mpv.key == pid.key and pid.key == a.val[2] and a.val[0] >= pid.val }
    #max_accept_val <+ (accept * max_promise_id).pairs {|a, pid| [a.val[2], a.val[0]] if pid.key == a.val[2] and a.val[0] >= pid.val }
  end

  def check_accept(id_and_val)
    puts "Received accept message"
    id = id_and_val[0]
    val = id_and_val[1]
    slot = id_and_val[2]
    if id < $max_promise_id[slot]
      return [false, slot, val]
    else
      $max_accept_val[slot] = val
      return [true, slot, val]
    end
  end

  def check_nums(new_id)
    #        new_id, id big, have prev val, max accept id, max accept val
    cur_slot = new_id[1]
    new_id = new_id[0]
    return_arr = [new_id, true, false, $max_promise_id[cur_slot] || 0, $max_accept_val[cur_slot] || 0, cur_slot]
    puts cur_slot
    puts new_id
    if new_id > ($max_promise_id[cur_slot] || 0)
        $max_promise_id[cur_slot] = new_id
        if ($max_accept_val[cur_slot] || 0) > 0
            return_arr[2] = true;
        end
    else
        return_arr[1] = false;
    end
    return return_arr;
  end
end

# ruby command-line wrangling
server = (ARGV.length == 2) ? ARGV[1] : PaxosProtocol::DEFAULT_PROPOSER_ADDR
puts "Server address: #{server}"
program = PaxosAcceptor.new(server, :stdin => $stdin)
program.run_fg

#Non-monotone downstream of network
#Chunks without non-monotone
#Counting till a threshold, use a table
#Nesting a lattice within a tuple (sandbox)
#Put in comments