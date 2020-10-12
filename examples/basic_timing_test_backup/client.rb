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

  state do
    slot_num <+ [[0]]
  end

  bloom do
    slot_num <- (slot_num * timer).pairs {|p, c| [p.key]}
    slot_num <+ (slot_num * timer).pairs {|p, c| [p.key + 1]}

    timer_buffer <= (timer * slot_num).pairs { |t, s| [s.key, Time.now.to_f, Time.now.to_f + 0.0001, ip_port] }
    test_channel <~ (timer_buffer * slot_num).pairs {|b, s| ["127.0.0.1:12347", s.key, b.id, b.val, b.ip]}

    stdio <~ test_channel.inspected
    temp_table <+ timer_buffer {|c| [c.id, c.val]}
    temp_table <- temp_table {|c| c}
    sink <= temp_table.group([temp_table.val], max(temp_table.key))
    sink2 <= response {|s| [s.val] if print_time()}
  end
end

def print_time()
  cur_time = Time.now.to_f
  puts cur_time - $last_time
  $last_time = cur_time
end

client_address = ARGV[0]
ip, port = client_address.split(":")

program = Client.new(0, :ip => "127.0.0.1", :port => "12345") #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg

