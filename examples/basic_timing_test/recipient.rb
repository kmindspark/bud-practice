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
    sink <= test_channel{|t| ["sink", print_here(Time.now.to_f - t.val)]}
  end
end

def print_here(t)
  puts t
end

program = Recipient.new(:ip => "127.0.0.1", :port => "12346") #/bud-practice/examples/multipaxos_cloudburst/
program.run_fg
