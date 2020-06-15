require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosClient
  include Bud
  include PaxosProtocol
  include PaxosClientModule

  def initialize(nick, server, opts={})
    @nick = nick
    @proposer = server
    super opts
  end
end

proposer = (ARGV.length == 2) ? ARGV[1] : PaxosProtocol::DEFAULT_PROPOSER_ADDR
puts "Proposer address: #{proposer}"
program = PaxosClient.new(ARGV[0], proposer, :stdin => $stdin)
program.run_fg