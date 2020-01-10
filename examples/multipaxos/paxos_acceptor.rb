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
    cur_prep <= prepare {|p| [p.val[1]]}

    existing_id <= cur_prep.notin(max_promise_id, :key=>:key) {|c, pid| true}
    existing_val <= cur_prep.notin(max_accept_val, :key=>:key) {|c, pid| true}
    
    max_promise_id <- (max_promise_id * prepare).pairs {|pid, p| [pid.key, pid.val] if p.val[1] == pid.key}
    max_promise_id <+ (prepare * max_promise_id).pairs {|p, pid| [p.val[1], p.val[0]] if p.val[1] == pid.key and p.val[0] > pid.val }
    max_promise_id <+ (prepare * existing_id).pairs {|p, eid| [p.val[1], p.val[0]] }

    promise <~ (prepare * max_promise_id * max_accept_val).combos {|p, mp, ma| [@proposer, [p.val[0], p.val[0] > mpi.val, ma.val > 0, mp.val, ma.val, p.val[1]]] if mp.key == ma.key and p.val[1] == mp.key and p.val[0] > mp.val}
    promise <~ (prepare * max_promise_id * existing_val).combos {|p, mp, ma| [@proposer, [p.val[0], p.val[0] > mpi.val, false, mp.val, 0, p.val[1]]] if p.val[1] == mp.key}
    promise <~ (prepare * existing_id * existing_val).combos {|p, mp, ma| [@proposer, [p.val[0], true, false, 0, 0, p.val[1]]] if p.val[1] == ma.key}

    accepted <~ (accept * max_promise_id).pairs {|a, pid| [@proposer, [false, a.val[2], a.val[1]]] if (pid.key == a.val[2] and a.val[0] < pid.val) }
    accepted <~ (accept * max_promise_id).pairs {|a, pid| [@proposer, [false, a.val[2], a.val[1]]] if pid.key == a.val[2] and a.val[0] >= pid.val }
    max_accept_val <- (max_accept_val * accept * max_promise_id).combos {|mpv, a, pid| [mpv.key, mpv.val] if mpv.key == pid.key and pid.key == a.val[2] and a.val[0] >= pid.val }
    max_accept_val <+ (accept * max_promise_id).pairs {|a, pid| [a.val[2], a.val[0]] if pid.key == a.val[2] and a.val[0] >= pid.val }

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