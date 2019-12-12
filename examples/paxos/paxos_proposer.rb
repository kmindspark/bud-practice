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
  $client_addr = 0

  state { table :nodelist }
  state { table :clientlist}

  bloom do
    nodelist <= connect { |c| [c.val] if register_new_acceptor}
    #stdio <~ nodelist.inspected

    clientlist <= client_request {|c| [c.val[0]]}
    prepare <~ (client_request * nodelist).pairs {|c, n| [n.key, get_new_num(c.val)]}
    majority <= promise {|p| [$propose_number] if process_promise(p.val)}
    accept <~ (majority * nodelist).pairs {|m, n| [n.key, [$propose_number, $advocate_val]] if m.key == $propose_number}
    accepted_to_client <~ (accepted * clientlist).pairs {|a, c| [c.key, a.val]}
    stdio <~ accepted.inspected
  end

  def register_new_acceptor()
    puts "Total acceptors: " + $total_acceptors.to_s
    $total_acceptors = $total_acceptors + 1
    return true
  end

  def get_new_num(advocate)
    client_addr = advocate[0]
    advocate = advocate[3]
    $transaction_in_progress = 1
    $agreeing_acceptors = 0
    $propose_number = $propose_number + 1
    $advocate_val = advocate.to_i
    return $propose_number
  end

  def end_transaction()
    $advocate_val = 0
    $agreeing_acceptors = 0
    $highest_id_responded = 0
    $transaction_in_progress = 0
  end

  def process_promise(promise_val)
    puts promise_val
    if promise_val[1] == false
      return false
    else
      $agreeing_acceptors += 1
      if promise_val[3] > $highest_id_responded and promise_val[2] == true
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