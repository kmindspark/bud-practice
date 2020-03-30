module PaxosProxyModule
  bootstrap do 
    num_acceptors <+ [[0]]
    connect_proxy <~ [[PaxosProtocol::DEFAULT_PROPOSER_ADDR, ip_port, $proxy_id]]
  end

  bloom do
    #rewrite joins to be faster
    nodelist <= acceptor_to_proxy {|a| [a.val, a.group_num]} #rename connect_acceptor

    acceptors_group_zero <= nodelist {|n| [n.key] if n.val == 0}
    num_acceptors <= acceptors_group_zero.group([], count(acceptors_group_zero.key))

    all_advocate_val <+ prepare_to_proxy {|p| [p.val[1], p.val[0], p.val[2]]} #slot, val to advocate, id

    prepare <~ (prepare_to_proxy * nodelist).pairs {|p, n| [n.key, [p.val[0], p.val[1], ip_port]] if p.val[1] % 3 == n.val}

    #prepare <~ (client_request_temp * nodelist).pairs {|c, n| [n.key, [c.key, c.val]]}

    #Receive promise from acceptor
    agreeing_acceptors <= promise {|p| [p.slot, p.ip, -1] if p.valid}
    #handle timeouts

    #If a Proposer receives a majority of Promises from a Quorum of Acceptors, it needs to set a value v to its proposal. 
    #If any Acceptors had previously accepted any proposal, then they'll have sent their values to the Proposer, who now must set the value of its proposal, v, 
    #to the value associated with the highest proposal number reported by the Acceptors, let's call it z. If none of the Acceptors had accepted a proposal up to this 
    #point, then the Proposer may choose the value it originally wanted to propose, say x[17]. The Proposer sends an Accept message, (n, v), to a Quorum of Acceptors 
    #with the chosen value for its proposal, v, and the proposal number n (which is the same as the number contained in the Prepare message previously sent to the Acceptors).
    #So, the Accept message is either (n, v=z) or, in case none of the Acceptors previously accepted a value, (n, v=x).
    #stdio <~ promise.inspected
    all_advocate_val <= promise {|p| [p.slot, p.max_prev_id, p.max_prev_val] if p.valid and p.have_prev_val}
    max_advocate_val <= all_advocate_val.group([all_advocate_val.slot, all_advocate_val.val], max(all_advocate_val.id))

    agreeing_acceptors_for_slot <= (agreeing_acceptors * promise).pairs(:key=>:slot) {|a, p| [a.val]}
    agreeing_acceptor_size <= agreeing_acceptors_for_slot.group([], count(agreeing_acceptors_for_slot.key))

    accept_sent <= (num_acceptors * agreeing_acceptor_size * promise).combos {|n, a, p| [p.ip.to_s+p.slot.to_s, p.slot, p.ip] if (p.valid and (a.key + 1)*2 > n.key)}
    sent_for_slot <= accept_sent.group([accept_sent.key], count(accept_sent.val))
    #do a group with a scratch

    #stdio <~ accept_sent.inspected
    #stdio <~ sent_for_slot.inspected

    majority <= (num_acceptors * agreeing_acceptor_size * promise * sent_for_slot).combos(promise.slot => sent_for_slot.key) {|n, a, p, s| [p.slot, p.id] if test_print("IM HERE1") and p.valid and test_print("IM HERE2") and (a.key + 1)*2 > n.key and test_print("IM HERE3") and s.val == 1 and test_print("IM HERE4")}
    stdio <~ majority.inspected
    stdio <~ max_advocate_val.inspected

    #Send accept message to acceptors
    accept <~ (majority * nodelist * max_advocate_val).combos(max_advocate_val.slot => majority.key) {|m, n, a| [n.key, [m.val, a.val, m.key, ip_port]] if test_print("IM HERE") and a.slot % 3 == n.val}

    accepted_to_proposer <~ (accepted * num_acceptors).combos {|a, n| [PaxosProtocol::DEFAULT_PROPOSER_ADDR, append_info_for_learner(a.val, n.key)]}
  end
end