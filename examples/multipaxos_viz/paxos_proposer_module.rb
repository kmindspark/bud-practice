module PaxosProposerModule
  state { table :nodelist }
  state { table :clientlist}
  state { table :learnerlist}

  bloom do
    learnerlist <= connect_learner { |c| [c.val]}
    nodelist <= connect { |c| [c.val] if register_new_acceptor}
    clientlist <= client_request {|c| [c.val[0]]}
    client_request_temp <= client_request {|c| [get_new_num(c.val), $slot_number]}
    prepare <~ (client_request_temp * nodelist).pairs {|c, n| [n.key, [c.key, c.val]]}

    majority <= promise {|p| [p.val[5], p.val[0]] if process_promise(p.val)}
    accept <~ (majority * nodelist).pairs {|m, n| [n.key, [m.val, $advocate_val[m.key], m.key]]}
    accepted_to_client <~ (accepted * clientlist).pairs {|a, c| [c.key, a.val]}
    accepted_to_learner <~ (accepted * learnerlist).pairs {|a, c| [c.key, append_info_for_learner(a.val)]}
    stdio <~ accepted.inspected
  end
end