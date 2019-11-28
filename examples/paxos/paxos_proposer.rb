require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosProposer
  include Bud
  include PaxosProtocol
  $total_acceptors = 0
  $propose_number = 0
  $advocate_val = 0
  $agreeing_acceptors = 0
  $highest_id_responded = 0
  $transaction_in_progress = 0

  state { table :nodelist }

  bloom do
    nodelist <= connect { |c| [c.val] if register_new_acceptor}
    prepare <~ (client_request * nodelist).pairs {|c, n| [n.key, get_new_num(c.val[3])]}
    accept <~ (promise * nodelist).pairs {|p, n| [n.key, [$propose_number, $advocate_val]] if process_promise(p.val)}
  end

  def register_new_acceptor()
    $total_acceptors = $total_acceptors + 1
    return true
  end

  def get_new_num(advocate)
    $transaction_in_progress = 1
    $agreeing_acceptors = 0
    $propose_number = $propose_number + 1
    $advocate_val = advocate.to_i
    return $propose_number;
  end

  def end_transaction()
    $advocate_val = 0
    $agreeing_acceptors = 0
    $highest_id_responded = 0
    $transaction_in_progress = 0
  end

  def process_promise(promise_val)
    if promise_val[1] == false
      return false
    else
      $agreeing_acceptors += 1
      if promise_val[3] > $highest_id_responded and promise[2] = true
        $highest_id_responded = promise_val[3]
        $advocate_val = promise_val[4]
      end
      return $agreeing_acceptors > $total_acceptors/2
    end
  end
end

# ruby command-line wrangling
addr = ARGV.first ? ARGV.first : PaxosProtocol::DEFAULT_PROPOSER_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = PaxosProposer.new(:ip => ip, :port => port.to_i)
program.run_fg