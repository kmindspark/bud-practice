module PaxosProtocol
    #Use schemas
    state do
      channel :connect, [:@addr, :val, :group_num]
      channel :client_request #destination
      channel :prepare
      channel :promise, [:@addr, :id, :valid, :have_prev_val, :max_prev_id, :max_prev_val, :slot, :ip]
      channel :accept
      channel :accepted
      scratch :majority
      channel :accepted_to_client
      scratch :client_request_temp, [:key, :val, :goalval]
      channel :connect_learner
      channel :accepted_to_learner

      table :nodelist
      table :clientlist
      table :learnerlist
      scratch :num_acceptors
      table :all_acceptors

      table :propose_num
      table :slot_num
      table :agreeing_acceptors, [:key, :val] => [:idk]
      
      table :accept_sent, [:idk] => [:key, :val]
      scratch :sent_for_slot

      table :all_advocate_val, [:slot, :val] => [:id]
      scratch :max_advocate_val, [:slot, :val] => [:id]

      table :all_promise_id
      scratch :max_promise_id
      table :all_accept_val, [:slot, :id] => [:val]
      scratch :max_accept_val, [:key, :val] => [:id]
    
      scratch :existing_id
      scratch :existing_val
      scratch :cur_prep
      scratch :agreeing_acceptors_for_slot
      scratch :agreeing_acceptor_size

      channel :connect_proxy, [:@addr, :val, :proxy_id]
      channel :acceptor_to_proxy, [:@addr, :val, :group_num]
      channel :prepare_to_proxy
      table   :proxylist
      scratch :acceptors_group_zero
      channel :accepted_to_proposer

      #now transferring ruby functionality to Bloom
      #lset :acceptors
      #lmax :num_acceptors
    end
  
    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
    DEFAULT_PROXY_ADDR = "127.0.0.1:12348"
  end