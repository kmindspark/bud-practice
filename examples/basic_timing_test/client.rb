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
    timer_buffer <= (timer * slot_num).pairs { |t, s| [s.key, Time.now.to_f, Time.now.to_f + 0.0001, ip_port] }

    slot_num <- (slot_num * timer_buffer).pairs {|p, c| [p.key]}
    slot_num <+ (slot_num * timer_buffer).pairs {|p, c| [p.key + 1]}

    test_channel <~ (timer_buffer * slot_num).combos {|b, s| ["127.0.0.1:12347", s.key, b.id, b.val, b.ip]}

    stdio <~ test_channel.inspected

    timer_buffer <- timer_buffer {|c| c}
    sink <= timer_buffer.group([timer_buffer.val], max(timer_buffer.id))
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

