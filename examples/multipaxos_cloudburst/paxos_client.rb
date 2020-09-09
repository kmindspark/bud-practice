require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosClient
  include Bud
  include PaxosProtocol

  $number_of_yes = {}
  $entries_in_slots = {}

  def initialize(proposer, opts={})
    @proposer = proposer
    super opts
  end

  bloom do
    client_request <~ stdio do |s|
        [@proposer, [ip_port, nil, Time.now.to_f.round(2), Time.now.to_f.round(5)]]
    end
    #stdio <~ accepted_to_learner.inspected
    sink <= accepted_to_learner{|a| [process_print(a.val)]}
  end

  def process_print(val)
    #puts "PRINTING"
    #puts val[3]
    puts Time.now.to_f.round(5) - val[2].to_f
    $latest_num_acceptors = val[3]
    $number_of_yes[val[1]] = 1 + ($number_of_yes[val[1]] || 0)
    if $number_of_yes[val[1]] > $latest_num_acceptors/2
      $entries_in_slots[val[1]] = val[2]
      #pp $entries_in_slots
    end
    #puts "Done printing update"
  end
end

client_address = ARGV[0]
ip, port = client_address.split(":")
proposer = ARGV[1]
puts "Client"
puts "Proposer address: #{proposer}"
puts "IP Port address: #{ip}:#{port}"
#puts File.open("/bud-practice/examples/multipaxos_cloudburst/in.txt")
program = PaxosClient.new(proposer, :ip => ip, :port => port, :stdin => File.open("/bud-practice/examples/multipaxos_cloudburst/in.txt")) #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg

