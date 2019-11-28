require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosAcceptor
  include Bud
  include PaxosProtocol
  $max_promise_id = 0
  $max_accept_val = 0

  def initialize(proposer, opts={})
    @proposer = proposer
    super opts
  end

  bootstrap do
    connect <~ [[@proposer, ip_port]]
  end

  bloom do
    promise <~ prepare {|p| [@proposer, check_nums(p.val)]}
    accept {|a| [@proposer, a.val] }

  end

  def check_accept(id_and_val)
    id = id_and_val[0]
    val = id_and_val[1]
    if id < max_promise_id
      return [false]
    else
      $max_accept_val = val
      return [true]
    end
  end

  def check_nums(new_id)
    #        new_id, id big, have prev val, max accept id, max accept val
    return_arr = [new_id, true, false, $max_promise_id, $max_accept_val]
    if new_id > $max_promise_id
        $max_promise_id = new_id
        if $max_accept_val > 0
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