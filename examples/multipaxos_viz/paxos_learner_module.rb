module PaxosLearnerModule
  bootstrap do
    connect_learner <~ [["127.0.0.1:12346", ip_port]]
  end

  bloom do
    promise <~ prepare {|p| ["127.0.0.1:12346", check_nums(p.val)]}
    accepted <~ accept {|a| ["127.0.0.1:12346", check_accept(a.val)]}    
    stdio <~ accepted_to_learner{|a| [process_print(a.val)]}
  end
end