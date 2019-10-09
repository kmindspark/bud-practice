require 'rubygems'
require 'backports'
require 'bud'
require_relative 'chat_protocol'

class ChatClient
  include Bud
  include ChatProtocol

  def initialize(nick, server, opts={})
    @nick = nick
    @server = server
    super opts
  end

  bootstrap do
    connect <~ [[@server, ip_port, @nick]]
  end

  bloom do
    mcast <~ stdio do |s|
      [@server, [ip_port, s.line.split("/")[0], @nick, Time.new.strftime("%I:%M.%S"), s.line]]
    end

    stdio <~ mcast { |m| [pretty_print(m.val)] }
  end

  # format chat messages with color and timestamp on the right of the screen
  def pretty_print(val)
    x = ''
    if val[4].to_s.split("/").length > 1 then
      x = val[4].to_s.split("/")[1]
    end

    str = "\033[34m"+val[2].to_s + ": " + "\033[31m" + (x || '') + "\033[0m"
    pad = "(" + val[3].to_s + ")"
    return str + " "*[66 - str.length,2].max + pad
  end
end

server = (ARGV.length == 2) ? ARGV[1] : ChatProtocol::DEFAULT_ADDR
puts "Server address: #{server}"
program = ChatClient.new(ARGV[0], server, :stdin => $stdin)
program.run_fg