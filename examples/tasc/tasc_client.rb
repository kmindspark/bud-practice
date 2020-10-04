require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosClient
  include Bud
  include PaxosProtocol

  $number_of_yes = {}
  $entries_in_slots = {}
  $last_time = 0

  def initialize(proposer, time_delay, opts={})
    @proposer = proposer
    @time_delay = time_delay.to_f
    super opts
  end

  bloom do
    client_get_request <~ stdio do |s|
        [@proposer, [ip_port, 'get', s.line[2:].split(',')[0].to_i, Time.now.to_f]] if s.line[0] == "g"
    end

    client_put_request <~ stdio do |s|
      [@proposer, [ip_port, 'put', s.line.split(',')[0].to_i, s.line.split(',')[1]].to_i, Time.now.to_f] if s.line[0] == "p"
    end

    sink <= accepted_to_learner{|a| [process_print(a.val)]}
  end

end

client_address = ARGV[0]
ip, port = client_address.split(":")
proposer = ARGV[1]
time_delay = ARGV[2]
puts "Client"
puts "Proposer address: #{proposer}"
puts "IP Port address: #{ip}:#{port}"
#puts File.open("in.txt")#/bud-practice/examples/multipaxos_cloudburst/
program = PaxosClient.new(proposer, time_delay, :ip => ip, :port => port)#, :stdin => File.open("/bud-practice/examples/multipaxos_cloudburst/in.txt")) #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg

