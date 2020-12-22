module Scatter
  state do
    table :data_scatter
    table :received_scatter
    table :ips_scatter
    channel :message_func_scatter
    periodic :timer, 1

    data_scatter <+ [[0, 4.2], [1, 4.2], [2, 4.2], [3, 4.2]]
    ips_scatter <+ [[0, "127.0.0.1:12346"], [1, "127.0.0.1:12347"], [2, "127.0.0.1:12348"]]
  end

  bloom do
      message_func_scatter <~ (ips_scatter * data_scatter * timer).combos {|i, d, t| [i.val, d.val] if (@sender > 0 and (d.key % @num_receivers) == i.key and ping(i.val))}
      received_scatter <= message_func_scatter {|m| [m.val]}
      stdio <~ message_func_scatter.inspected
  end
end