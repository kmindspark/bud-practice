module PaxosProtocol
    state do
      channel :connect
      channel :client_request #destination
      channel :prepare
      channel :promise
      channel :accept
      channel :accepted
      scratch :majority
      channel :accepted_to_client
      scratch :client_request_temp
      channel :connect_learner
      channel :accepted_to_learner

      table :nodelist
      table :clientlist
      table :learnerlist
      scratch :num_acceptors
      table :all_acceptors

      table :propose_num
      table :slot_num
      table :advocate_val
      table :agreeing_acceptors, [:key, :val] => [:idk]
      table :accept_sent
      table :highest_id_responded

      table :all_promise_id
      scratch :max_promise_id
      table :all_accept_val, [:slot, :id] => [:val]
      scratch :max_accept_val, [:key, :val] => [:id]
      scratch :existing_id
      scratch :existing_val
      scratch :cur_prep
      scratch :agreeing_acceptors_for_slot
      scratch :agreeing_acceptor_size
      
      #now transferring ruby functionality to Bloom
      #lset :acceptors
      #lmax :num_acceptors
    end
  
    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
  end