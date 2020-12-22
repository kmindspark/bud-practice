module RingAllReduce
    state do

        table :data_allreduce
        table :received_allreduce
        table :ips_scatter
        table :ips_allreduce
        periodic :timer, 10

        channel :message_func_allreduce, [:@addr, :key] => [:val]
        channel :send_around, [:@addr, :key] => [:val]

        data_allreduce <+ [[0, 0.1], [1, 3.2], [2, 1], [3, 18]]
        #received_allreduce <+ [[0, 0]]
        ips_allreduce <+ [[0, "127.0.0.1:12345"], [1, "127.0.0.1:12346"], [2, "127.0.0.1:12347"], [3, "127.0.0.1:12348"]]
      end

      bloom do

          message_func_allreduce <~ (ips_allreduce * data_allreduce * timer).pairs {|i, d, t| [i.val, d.key, d.val] if i.key == (d.key + 1) % 4}

          message_func_allreduce <~ (message_func_allreduce * data_allreduce * ips_allreduce).combos {|m, d, i| [i.val, m.key, d.val + m.val] if i.key == (@client_id + 1) % 4 and m.key == d.key and m.key != @client_id}

          send_around <~ (message_func_allreduce * ips_allreduce).combos {|m, i| [i.val, m.key, m.val] if i.key == (m.key + 1) % 4 and m.key == @client_id }

          send_around <~ (send_around * ips_allreduce).pairs {|s, i| [i.val, s.key, s.val] if i.key == (@client_id + 1) % 4 and s.key != @client_id}# and #pp(s.key.to_s + ", " + s.val.to_s)}

          received_allreduce <= send_around {|s| [s.key, s.val]}

          stdio <~ received_allreduce.inspected
      end
end