require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class Client
  include Bud
  include Protocol

  $number_of_yes = {}
  $entries_in_slots = {}
  $last_time = 0

  def initialize(time_delay, opts={})
    @time_delay = time_delay.to_f
    super opts
  end

  bloom do
    test_channel <~ timer { |s| ["127.0.0.1:12346", Time.now.to_f] }
  end
end

client_address = ARGV[0]
ip, port = client_address.split(":")

program = Client.new(0, :ip => "127.0.0.1", :port => "12345") #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg

