require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class PaxosClient
  include Bud
  include PaxosProtocol

  def initialize(proposer, opts={})
    @proposer = proposer
    super opts
  end

  bloom do
    client_request <~ stdio do |s|
        [@proposer, [ip_port, nil, Time.now.to_f.round(2), s.line.to_i]]
    end
    stdio <~ accepted_to_client.inspected
  end
end

client_address = ARGV[0]
ip, port = client_address.split(":")
proposer = ARGV[1]
puts "Client"
puts "Proposer address: #{proposer}"
puts "IP Port address: #{ip}:#{port}"
puts File.open("examples/multipaxos_cloudburst/in.txt")
program = PaxosClient.new(proposer, :ip => ip, :port => port, :stdin => File.open("examples/multipaxos_cloudburst/in.txt"))
program.run_fg
