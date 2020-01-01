require 'rubygems'
require 'backports'
require 'bud'
require_relative 'chat_protocol'
require_relative 'chat_client_module'

class ChatClient
  include Bud
  include ChatProtocol
  include ChatClientModule

  def initialize(nick, server, opts={})
    @nick = nick
    @server = server
    super opts
  end

  # format chat messages with color and timestamp on the right of the screen
  def pretty_print(val)
    str = "\033[34m"+val[1].to_s + ": " + "\033[31m" + (val[3].to_s || '') + "\033[0m"
    pad = "(" + val[2].to_s + ")"
    return str + " "*[66 - str.length,2].max + pad
  end
end

server = (ARGV.length == 2) ? ARGV[1] : ChatProtocol::DEFAULT_ADDR
puts "Server address: #{server}"
program = ChatClient.new(ARGV[0], server, :stdin => $stdin)
program.run_fg
