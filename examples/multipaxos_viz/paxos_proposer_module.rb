module PaxosProposerModule
  
  bloom do
    learnerlist <= connect_learner { |c| [c.val]}
    
    nodelist <= connect { |c| [c.val] }
    num_acceptors <- (connect * num_acceptors).pairs {|c, n| [n.key]}
    num_acceptors <+ (connect * num_acceptors).pairs {|c, n| [n.key + 1]}

    clientlist <= client_request {|c| [c.val[0]]}

    propose_num <- (propose_num * client_request).pairs {|p, c| [p.key]}
    propose_num <+ (propose_num * client_request).pairs {|p, c| [p.key + 1]}

    accept_sent <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}
    agreeing_acceptors <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}
    highest_id_responded <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}
    advocate_val <+ (client_request * slot_num).pairs {|c, s| [s.key, c.val[3]]}

    slot_num <- (slot_num * client_request).pairs {|p, c| [p.key]}
    slot_num <+ (slot_num * client_request).pairs {|p, c| [p.key + 1]}
    
    client_request_temp <= (client_request * propose_num * slot_num).combos {|c, p, s| [p.key*10 + $proposer_id, s.key]}

    prepare <~ (client_request_temp * nodelist).pairs {|c, n| [n.key, [c.key, c.val]]}

    agreeing_acceptors <- (agreeing_acceptors * promise).pairs {|a, p| [p.val[5], a.val] if (p.val[5] == a.key and p.val[1])}
    agreeing_acceptors <+ (agreeing_acceptors * promise).pairs {|a, p| [p.val[5], a.val + 1] if (p.val[5] == a.key and p.val[1])}

    highest_id_responded <- (highest_id_responded * promise).pairs {|a, p| [p.val[5], a.val] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}
    highest_id_responded <+ (highest_id_responded * promise).pairs {|a, p| [p.val[5], p.val[3]] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}

    advocate_val <- (highest_id_responded * promise).pairs {|a, p| [p.val[5], a.val] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}
    advocate_val <+ (highest_id_responded * promise).pairs {|a, p| [p.val[5], p.val[4]] if (p.val[5] == a.key and p.val[1] and p.val[2] and p.val[3] > a.val)}

    accept_sent <- (num_acceptors * agreeing_acceptors * promise * accept_sent).combos {|n, a, p, s| [[s.key, 0]] if (p.val[5] == a.key and a.key == s.key and p.val[1] and (a.val + 1)*2 > n.key and s.val == 0)}
    accept_sent <+ (num_acceptors * agreeing_acceptors * promise * accept_sent).combos {|n, a, p, s| [[s.key, 1]] if (p.val[5] == a.key and a.key == s.key and p.val[1] and (a.val + 1)*2 > n.key and s.val == 0)}

    majority <= (num_acceptors * agreeing_acceptors * promise * accept_sent).combos {|n, a, p, s| [p.val[5], p.val[0]] if (p.val[5] == a.key and a.key == s.key and p.val[1] and (a.val + 1)*2 > n.key and s.val == 0)}

    accept <~ (majority * nodelist * advocate_val).combos {|m, n, a| [n.key, [m.val, a.val, m.key]] if a.key == m.key}
    accepted_to_client <~ (accepted * clientlist).pairs {|a, c| [c.key, a.val]}

    accepted_to_learner <~ (accepted * learnerlist * num_acceptors).combos {|a, l, n| [l.key, append_info_for_learner(a.val, n.key)]} 
    stdio <~ accepted.inspected
  end
end