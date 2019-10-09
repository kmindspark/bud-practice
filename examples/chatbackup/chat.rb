require 'rubygems'
require 'backports'
require 'bud'
require_relative 'chat_protocol'
require 'timeout'
require 'Time'

class ChatClient
  include Bud
  include ChatProtocol

  def initialize(nick, server1, server2, opts={})
    @nick = nick
    @server1 = server1
    @server2 = server2
    super opts
  end

  bootstrap do
    connect <~ [[@server1, ip_port, @nick]]
    connect_backup <~ [[@server2, ip_port, @nick]]
  end

  bloom do
    curTimeCapture <= [[Time]]

    mcast <~ stdio do |s|
        [@server1, [ip_port, @nick, Time.now.to_f.round(2), s.line]]
    end

    pending <= stdio do |s|
        [Time.now.to_f.round(2), s.line]
    end

    acktimestamps <= ack { |a| [a.timestamp[0], a.timestamp[1]] }

    pending <- acktimestamps

    mcast <~ pending do |m|
        [@server2, [ip_port, @nick, m.key.round(2), m.val]] if Time.now.to_f - m.key.round(2) > 2.0
    end

    pending <- pending do |m|
      [m.key, m.val] if Time.now.to_f - m.key.round(2) > 2.0
    end
    
    stdio <~ mcast { |m| [pretty_print(m.val)] }
  end

  # format chat messages with color and timestamp on the right of the screen
  def pretty_print(val)
    str = "\033[34m"+val[1].to_s + ": " + "\033[31m" + (val[3].to_s || '') + "\033[0m"
    pad = "(" + val[2].to_s + ")"
    return str + " "*[66 - str.length,2].max + pad
  end
end

server = (ARGV.length == 2) ? ARGV[1] : ChatProtocol::DEFAULT_ADDR
server_backup = (ARGV.length == 2) ? ARGV[1] : ChatProtocol::DEFAULT_BACKUP_ADDR
puts "Server address: #{server}"
puts "Backup server address: #{server_backup}"
program = ChatClient.new(ARGV[0], server, server_backup, :stdin => $stdin)
program.run_fg
