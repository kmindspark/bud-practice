require 'rubygems'
require 'backports'
require 'bud'
require_relative 'voting_protocol'

class VotingServer
  include Bud
  include VotingProtocol

  def initialize(addressOther, opts={})
    @addressOther = addressOther
    super opts
  end

  state { table :nodelist }

  bootstrap do
    recoveryRequest <~ [[@addressOther]]
  end

  bloom do
    tempA <= votesA {|a| [a]}
    tempB <= votesB {|a| [a]}

    recoveryA <~ (recoveryRequest * tempA).pairs {|r, a| [@addressOther, a.k]}
    recoveryB <~ (recoveryRequest * tempB).pairs {|r, b| [@addressOther, b.k]}

    votesA <= recoveryA {|r| [r.val]}
    votesB <= recoveryB {|r| [r.val]}

    nodelist <= connect { |c| [c.client, c.nick] }

    stdio <~ mcast.inspected

    votesA <= mcast {|m| [m.val[0]] if (m.val[3].split('/')[1] == "A" and m.val[3].split('/')[0] == "passwd" and Time.now.to_f > 1570835457 and Time.now.to_f < 2570835557)}
    votesB <= mcast {|m| [m.val[0]] if (m.val[3].split('/')[1] == "B" and m.val[3].split('/')[0] == "passwd" and Time.now.to_f > 1570835457 and Time.now.to_f < 2570835557)} # 

    resp <~ mcast {|m| [m.val[0], ["Invalid Password"]] if m.val[3].split('/')[0] != "passwd"}
    resp <~ mcast {|m| [m.val[0], ["Election not in session"]] if Time.now.to_f < 1570835457 or Time.now.to_f > 2570835557}

    vote_cnt_A <= votesA.size
    vote_cnt_B <= votesB.size

    both_votes <= [[votesA.reveal, votesB.reveal]]
    stdio <~ both_votes.inspected
    stdio <~ [[Time.now.to_f]]
    #stdio <~ vote_cnt_B
  end
end

# ruby command-line wrangling
addr = ARGV.first ? ARGV.first : VotingProtocol::DEFAULT_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
otherAddress = addr
if addr == (VotingProtocol::DEFAULT_ADDR)
  otherAddress = VotingProtocol::DEFAULT_BACKUP_ADDR
else
  otherAddress = VotingProtocol::DEFAULT_ADDR
end
program = VotingServer.new(otherAddress, :ip => ip, :port => port.to_i)
program.run_fg