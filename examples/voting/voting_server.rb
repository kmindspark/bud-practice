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

    #nodelist <= connect { |c| [c.client, c.nick] }

    stdio <~ mcast.inspected

    voter_log <= votesA {|a| [a]}
    voter_log <= votesB {|b| [b]}
    cur_matches <= (mcast*voter_log).pairs {|m, v| [m.val[0]] if m.val[0] == v.key}
    #cur_matches <= (voter_log {|v| [v] if v }
    stdio <~ cur_matches.inspected

    votesA <+ mcast {|m| [m.val[0]] if (m.val[3].split('/')[1] == "A" and m.val[3].split('/')[0] == "passwd" and Time.now.to_f > 1570835457 and Time.now.to_f < 2570835557 and not cur_matches.exists?)}
    votesB <+ mcast {|m| [m.val[0]] if (m.val[3].split('/')[1] == "B" and m.val[3].split('/')[0] == "passwd" and Time.now.to_f > 1570835457 and Time.now.to_f < 2570835557 and not cur_matches.exists?)} # 
    
    #voter_log <= mcast {|m| [m.val[0]] if ((m.val[3].split('/')[1] == "A" or m.val[3].split('/')[1] == "B") and m.val[3].split('/')[0] == "passwd" and Time.now.to_f > 1570835457 and Time.now.to_f < 2570835557)}
    #stdio <~ voter_log.inspected

    resp <~ mcast {|m| [m.val[0], ["Invalid Password"]] if m.val[3].split('/')[0] != "passwd"}
    resp <~ mcast {|m| [m.val[0], ["Election not in session"]] if Time.now.to_f <= 1570835457 or Time.now.to_f >= 2570835557}
    resp <~ mcast {|m| [m.val[0], ["Thank you for voting!"]] if ((m.val[3].split('/')[1] == "A" or m.val[3].split('/')[1] == "B") and m.val[3].split('/')[0] == "passwd" and Time.now.to_f > 1570835457 and Time.now.to_f < 2570835557)}

    vote_cnt_A <= votesA.size
    vote_cnt_B <= votesB.size

    both_votes <= [[votesA.reveal, votesB.reveal]]
    stdio <~ both_votes.inspected

    stdio <~ mcast {[["Election over"]] if Time.now.to_f >= 1573071000}
    stdio <~ mcast {[[vote_cnt_A.reveal, vote_cnt_B.reveal]] if Time.now.to_f >= 1573071000}
    #stdio <~ [[Time.now.to_f]]
    #stdio <~ vote_cnt_B
    #preventing one person from voting for 2 people, determining winner
  end

  def pretty_print(val)
    str = "\033[34m"+val[1].to_s + ": " + "\033[31m" + (val[3].to_s || '') + "\033[0m"
    pad = "(" + val[2].to_s + ")"
    return str + " "*[66 - str.length,2].max + pad
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