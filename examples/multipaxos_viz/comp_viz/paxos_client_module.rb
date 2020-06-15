module PaxosClientModule
    #state { table :nodelist }
  
    bloom do
      client_request <~ stdio do |s|
          ["127.0.0.1:12346", [ip_port, nil, Time.now.to_f.round(2), s.line]]
      end
      stdio <~ accepted_to_client.inspected 
    end
  end