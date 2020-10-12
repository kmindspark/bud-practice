require 'rubygems'
require 'backports'
require 'bud'
require_relative 'paxos_protocol'

class Recipient
  include Bud
  include Protocol

  $number_of_yes = {}
  $entries_in_slots = {}
  $last_time = 0

  def initialize(opts={})
    super opts
  end

  bloom do
    #sink <= test_channel{|t| ["sink", print_here(Time.now.to_f - t.val)]}
    response <~ test_channel {|p| [p.ip, p.slot, p.id, p.val]}

    #stdio <~ temp_table.inspected
  end
end

def print_time()
  cur_time = Time.now.to_f
  puts cur_time - $last_time
  $last_time = cur_time
end

def print_here(t)
  puts t
end

program = Recipient.new(:ip => "127.0.0.1", :port => "12347") #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg
