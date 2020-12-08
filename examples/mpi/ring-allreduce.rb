module ClientModule
    state do
        table :data_scatter
        table :received_scatter
        table :data_allreduce
        table :received_allreduce
        table :ips_scatter
        table :ips_allreduce
        periodic :timer

        channel :message_func_scatter, [:@addr, :key] => [:val]
        channel :message_func_allreduce, [:@addr, :key] => [:val]

        #data_scatter <+ [[0, 4.2], [1, 4.2], [2, 4.2], [3, 4.2]]
        data_allreduce <+ [[0, 0.1], [1, 3.2], [2, 1], [3, 18]]
        received_allreduce <+ [[0, 0]]
        #ips_scatter <+ [[0, "127.0.0.1:12350"], [1, "127.0.0.1:12351"], [2, "127.0.0.1:12352"], [3, "127.0.0.1:12353"]]
        ips_allreduce <+ [[0, "127.0.0.1:12345"], [1, "127.0.0.1:12346"], [2, "127.0.0.1:12347"], [3, "127.0.0.1:12348"]]
    end

    bootstrap do
        #stdio <~ ips_allreduce.inspected
        #message_func_allreduce <~ (ips_allreduce * data_allreduce).pairs {|i, d| [d.val, 1, 1] }
        #message_func_allreduce <~ (ips_allreduce * data_allreduce).pairs {|i, d| ["127.0.0.1:12346", d.key, d.val] if wait()}
    end

    bloom do
        #message_func_scatter <~ (ips_scatter * data_scatter).pairs(:key=>:key) {|i, d| [i.val + (d.key % @num_receivers).to_s, d.val]} and @sender > 0}
        #received_scatter <= message_func_scatter {|m| [m.key]}
        #stdio <~ received.inspected

        message_func_allreduce <~ (ips_allreduce * data_allreduce).pairs {|i, d| [i.val, d.key, d.val]}

        message_func_allreduce <~ (message_func_allreduce * data_allreduce * ips_allreduce).combos {|m, d, i| [i.val, m.key, d.val + m.val] if i.key == (m.key + 1) % 4 and m.key == d.key}
        #data_allreduce <- data_allreduce {|d| d}

        received_allreduce <- (received_allreduce * message_func_allreduce).pairs(:key=>:key) {|r, m| r}
        received_allreduce <+ (received_allreduce * message_func_allreduce).pairs(:key=>:key) {|r, m| [r.key, 100 + r.val + m.val] if hello()}

        stdio <~ received_allreduce.inspected
    end
end