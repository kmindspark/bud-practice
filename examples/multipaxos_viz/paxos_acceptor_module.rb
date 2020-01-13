module PaxosAcceptorModule
  bootstrap do
    connect <~ [["127.0.0.1:12346", ip_port]]
  end

  bloom do
    cur_prep <= prepare {|p| [p.val[1]]}

    existing_id <= cur_prep.notin(max_promise_id, :key=>:key) {|c, pid| true}
    existing_val <= cur_prep.notin(max_accept_val, :key=>:key) {|c, pid| true}
    
    max_promise_id <- (max_promise_id * prepare).pairs {|pid, p| [pid.key, pid.val] if p.val[1] == pid.key}
    max_promise_id <+ (prepare * max_promise_id).pairs {|p, pid| [p.val[1], p.val[0]] if p.val[1] == pid.key and p.val[0] > pid.val }
    max_promise_id <+ (prepare * existing_id).pairs {|p, eid| [p.val[1], p.val[0]] }

    promise <~ (prepare * max_promise_id * max_accept_val).combos {|p, mp, ma| ["127.0.0.1:12346", [p.val[0], p.val[0] > mpi.val, ma.val > 0, mp.val, ma.val, p.val[1]]] if mp.key == ma.key and p.val[1] == mp.key and p.val[0] > mp.val}
    promise <~ (prepare * max_promise_id * existing_val).combos {|p, mp, ma| ["127.0.0.1:12346", [p.val[0], p.val[0] > mpi.val, false, mp.val, 0, p.val[1]]] if p.val[1] == mp.key}
    promise <~ (prepare * existing_id * existing_val).combos {|p, mp, ma| ["127.0.0.1:12346", [p.val[0], true, false, 0, 0, p.val[1]]] if p.val[1] == ma.key}

    accepted <~ (accept * max_promise_id).pairs {|a, pid| ["127.0.0.1:12346", [false, a.val[2], a.val[1]]] if (pid.key == a.val[2] and a.val[0] < pid.val) }
    accepted <~ (accept * max_promise_id).pairs {|a, pid| ["127.0.0.1:12346", [false, a.val[2], a.val[1]]] if pid.key == a.val[2] and a.val[0] >= pid.val }
    max_accept_val <- (max_accept_val * accept * max_promise_id).combos {|mpv, a, pid| [mpv.key, mpv.val] if mpv.key == pid.key and pid.key == a.val[2] and a.val[0] >= pid.val }
    max_accept_val <+ (accept * max_promise_id).pairs {|a, pid| [a.val[2], a.val[0]] if pid.key == a.val[2] and a.val[0] >= pid.val }
  end
end