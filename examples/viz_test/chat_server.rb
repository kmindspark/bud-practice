require 'rubygems'
require 'backports'
require 'bud'
require_relative 'chat_protocol'
require_relative 'chat_server_module'

class ChatServer
  include Bud
  include ChatProtocol
  include ChatServerModule
end

# ruby command-line wrangling
addr = ARGV.first ? ARGV.first : ChatProtocol::DEFAULT_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = ChatServer.new(:ip => ip, :port => port.to_i)
program.run_fg
