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
        [@proposer, [ip_port, nil, Time.now.to_f.round(2), Time.now.to_f.round(5)]]
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
puts File.open("in.txt")
program = PaxosClient.new(proposer, :ip => ip, :port => port, :stdin => File.open("in.txt")) #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg
