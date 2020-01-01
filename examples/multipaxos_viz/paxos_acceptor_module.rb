module PaxosAcceptorModule
  bootstrap do
    connect <~ [["127.0.0.1:12346", ip_port]]
  end

  bloom do
    promise <~ prepare {|p| ["127.0.0.1:12346", check_nums(p.val)]}
    accepted <~ accept {|a| ["127.0.0.1:12346", check_accept(a.val)]}
  end
end