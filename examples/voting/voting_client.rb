require 'rubygems'
require 'backports'
require 'bud'
require_relative 'voting_protocol'
require 'timeout'
require 'Time'

class VotingClient
  include Bud
  include VotingProtocol

  def initialize(nick, server1, server2, opts={})
    @nick = nick
    @server1 = server1
    @server2 = server2
    super opts
  end

  bootstrap do
    connect <~ [[@server1, ip_port, @nick]]
    connect <~ [[@server2, ip_port, @nick]]
  end

  bloom do
    mcast <~ stdio do |s|
      [@server1, [ip_port, @nick, Time.new.strftime("%I:%M.%S"), s.line]]
    end
    mcast <~ stdio do |s|
      [@server2, [ip_port, @nick, Time.new.strftime("%I:%M.%S"), s.line]]
    end

    stdio <~ resp do |r|
      [[r.val]]
    end
  end

  # format voting messages with color and timestamp on the right of the screen
  def pretty_print(val)
    str = "\033[34m"+val[1].to_s + ": " + "\033[31m" + (val[3].to_s || '') + "\033[0m"
    pad = "(" + val[2].to_s + ")"
    return str + " "*[66 - str.length,2].max + pad
  end
end

server = (ARGV.length == 2) ? ARGV[1] : VotingProtocol::DEFAULT_ADDR
server_backup = (ARGV.length == 2) ? ARGV[1] : VotingProtocol::DEFAULT_BACKUP_ADDR
puts "Server address: #{server}"
puts "Backup server address: #{server_backup}"
program = VotingClient.new(ARGV[0], server, server_backup, :stdin => $stdin)
program.run_fg
