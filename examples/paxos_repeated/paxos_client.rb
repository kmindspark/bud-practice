require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosClient
  include Bud
  include PaxosProtocol

  def initialize(nick, server, opts={})
    @nick = nick
    @proposer = server
    super opts
  end

  state { table :nodelist }

  bloom do
    client_request <~ timer do |s|
      [@proposer, [ip_port, nil, Time.now.to_f.round(2), Time.now.to_f.round(5)]]
    end
    sink <= to_client{|a| [process_print(a.val)]}
  end
end

def process_print(val)
  #puts "PRINTING"
  #puts val[3]
  puts String(val[1].to_f) + ", " + String(Time.now.to_f.round(5) - val[1].to_f)

  #puts "Done printing update"
end

proposer = (ARGV.length == 2) ? ARGV[1] : PaxosProtocol::DEFAULT_PROPOSER_ADDR
puts "Proposer address: #{proposer}"
program = PaxosClient.new(ARGV[0], proposer, :stdin => $stdin)
program.run_fg
