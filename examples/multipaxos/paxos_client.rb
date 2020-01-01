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
  
  bloom do
    client_request <~ stdio do |s|
        [@proposer, [ip_port, nil, Time.now.to_f.round(2), s.line]]
    end
    stdio <~ accepted_to_client.inspected 
  end
end

proposer = (ARGV.length == 2) ? ARGV[1] : PaxosProtocol::DEFAULT_PROPOSER_ADDR
puts "Proposer address: #{proposer}"
program = PaxosClient.new(ARGV[0], proposer, :stdin => $stdin)
program.run_fg
