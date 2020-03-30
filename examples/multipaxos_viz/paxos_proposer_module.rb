module PaxosProposerModule
  bootstrap do 
    num_acceptors <+ [[0]]
    propose_num <+ [[1]]
    slot_num <+ [[0]]
  end

  bloom do
    #rewrite joins to be faster
    learnerlist <= connect_learner { |c| [c.val]}
    nodelist <= connect { |c| [c.val, c.group_num] } #rename connect_acceptor
    proxylist <= connect_proxy {|c| [c.val, c.proxy_id]}
    acceptor_to_proxy <~ (connect * proxylist).pairs {|c, p| [p.key, c.val, c.group_num]}

    num_acceptors <= nodelist.group([], count(nodelist.key))
    clientlist <= client_request {|c| [c.val[0]]}

    #A Proposer creates a message, which we call a "Prepare", identified with a number n. 
    #Note that n is not the value to be proposed and maybe agreed on, but just a number which uniquely identifies this initial message by the proposer (to be sent to the acceptors). 
    #The number n must be greater than any number used in any of the previous Prepare messages by this Proposer. Then, it sends the Prepare message containing n to a Quorum of Acceptors. 
    #Note that the Prepare message only contains the number n (that is, it does not have to contain e.g. the proposed value, often denoted by v). The Proposer decides who is in the Quorum.
    #A Proposer should not initiate Paxos if it cannot communicate with at least a Quorum of Acceptors.

    #Assumes only 1 channel per tick
    propose_num <- (propose_num * client_request).pairs {|p, c| [p.key]}
    propose_num <+ (propose_num * client_request).pairs {|p, c| [p.key + 1]}

    #accept_sent <= (client_request * slot_num).pairs {|c, s| [s.key, 0]}

    slot_num <- (slot_num * client_request).pairs {|p, c| [p.key]}
    slot_num <+ (slot_num * client_request).pairs {|p, c| [p.key + 1]}
    
    #Assuming 10 > num proposers, this ensures that all IDs are unique
    client_request_temp <= (client_request * propose_num * slot_num).combos {|c, p, s| [p.key*10 + $proposer_id, s.key, c.val[3]]} 

    #Send prepare message (after all the preparation)
    prepare_to_proxy <~ (client_request_temp * proxylist).pairs {|c, n| [n.key, [c.key, c.val, c.goalval]] if c.val % 3 == n.val}

    accepted_to_learner <~ (accepted_to_proposer * learnerlist).pairs {|a, l| [l.key, a.val]}
  end
end