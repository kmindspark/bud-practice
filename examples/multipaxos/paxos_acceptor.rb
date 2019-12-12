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
    promise <~ prepare {|p| [@proposer, check_nums(p.val)]}
    accepted <~ accept {|a| [@proposer, check_accept(a.val)]}    
  end

  def check_accept(id_and_val)
    puts "Received accept message"
    id = id_and_val[0]
    val = id_and_val[1]
    slot = id_and_val[2]
    if id < $max_promise_id[slot]
      return [false]
    else
      $max_accept_val[slot] = val
      return [true, val]
    end
  end

  def check_nums(new_id)
    #        new_id, id big, have prev val, max accept id, max accept val
    cur_slot = new_id[1]
    new_id = new_id[0]
    return_arr = [new_id, true, false, $max_promise_id[cur_slot] || 0, $max_accept_val[cur_slot] || 0, cur_slot]
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