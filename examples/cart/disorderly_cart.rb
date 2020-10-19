require 'rubygems'
require 'bud'

require 'multicast'
require 'cart_protocol'

module DisorderlyCart
  include CartProtocol

  state do
    table :action_log, [:session, :reqid] => [:item, :cnt]
    scratch :item_sum, [:session, :item] => [:num]
    scratch :session_final, [:session] => [:items, :counts]
  end

  bloom :on_action do
    action_log <= action_msg {|c| [c.session, c.reqid, c.item, c.cnt] }
  end

  bloom :on_checkout do
    temp :checkout_log <= (checkout_msg * action_log).rights(:session => :session)
    item_sum <= checkout_log.group([:session, :item], sum(:cnt)) do |s|
      # Don't return items with non-positive counts. XXX: "s" has no schema
      # information, so we can't reference the sum by column name.
      s if s.last > 0
    end
    session_final <= item_sum.group([:session], accum_pair(:item, :num))
    response_msg <~ (session_final * checkout_msg).pairs(:session => :session) do |c,m|
      [m.client, m.server, m.session, c.items.sort]
    end
  end
end

module ReplicatedDisorderlyCart
  include DisorderlyCart
  include Multicast

  bloom :replicate do
    mcast_send <= action_msg {|a| [a.reqid, [a.session, a.reqid, a.item, a.cnt]]}
    action_log <= mcast_done {|m| m.payload}
    action_log <= pipe_out {|c| c.payload}
  end
end
