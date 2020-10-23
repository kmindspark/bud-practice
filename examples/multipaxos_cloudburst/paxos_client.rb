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
  $queue = []
  $num_received = 0

  def initialize(proposer, time_delay, client_address, opts={})
    @proposer = proposer
    @time_delay = time_delay.to_f
    @client_address = client_address
    super opts
  end

  state do
    #client_request <~ [[@proposer, [ip_port, nil, Time.now.to_f.round(2), Time.now.to_f.round(5)]]]
  end

  bloom do
    client_request <~ timer do |s|
        [@proposer, [ip_port, nil, Time.now.to_f.round(2), Time.now.to_f.round(5)]]
    end
    #stdio <~ accepted_to_learner.inspected
    #sink <= accepted_to_learner{|a| [process_print(a.val)]}
    sink <= throughput_timer {|a| [print_throughput]}

    client_request <~ accepted_to_learner{|a| [@proposer, [ip_port, nil, Time.now.to_f.round(2), Time.now.to_f.round(5)]] if hang() and process_print(a.val)} #(@client_address == a.val[4])
  end

  def hang()
    sleep(0.005)
    #puts 'hang'
    return true
  end

  def print_throughput()
    puts $num_received
    $num_received = 0
  end

  def process_time(val)
    count = 0
    if ($last_time == 0)
      $last_time = Time.now.to_f
    end
    while (Time.now.to_f - $last_time < @time_delay)
      count = count + 1
    end
    $last_time = Time.now.to_f
    puts "sending..."
    return true
  end

  def process_print(val)
    #puts "PRINTING"
    #puts val[3]
    #puts String(val[2].to_f) + ", " + String(Time.now.to_f.round(5) - val[2].to_f)
    $latest_num_acceptors = val[3]
    $number_of_yes[val[1]] = 1 + ($number_of_yes[val[1]] || 0)
    if $number_of_yes[val[1]] > $latest_num_acceptors/2
      $entries_in_slots[val[1]] = val[2]
      #pp $entries_in_slots
    end
    #puts "Done printing update"
    $num_received += 1
    return true
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
program = PaxosClient.new(proposer, time_delay, client_address, :ip => ip, :port => port, :stdin => File.open("in.txt")) #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg

