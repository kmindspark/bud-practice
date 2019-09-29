require 'rubygems'
require 'backports'
require 'bud'
require_relative 'chat_protocol'

class ChatServer
  include Bud
  include ChatProtocol

  state { table :nodelist }

  bloom do
    nodelist <= connect_backup { |c| [c.client, c.nick] }
    nodelist <= connect { |c| [c.client, c.nick] }
    #stdio <~ nodelist.inspected
    mcast <~ (mcast * nodelist).pairs { |m,n| [n.key, m.val] }
    ack <~ mcast { |m| [m.val[0], m.val[2]] }
  end
end

# ruby command-line wrangling
addr = ARGV.first ? ARGV.first : ChatProtocol::DEFAULT_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = ChatServer.new(:ip => ip, :port => port.to_i)
program.run_fg
