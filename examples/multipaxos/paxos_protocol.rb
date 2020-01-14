module PaxosProtocol
    state do
      channel :connect
      channel :client_request
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
      table :agreeing_acceptors
      table :accept_sent
      table :highest_id_responded

      table :max_promise_id
      table :max_accept_val
      scratch :existing_id
      scratch :existing_val
      scratch :cur_prep

      table :test_t

      #now transferring ruby functionality to Bloom
      #lset :acceptors
      #lmax :num_acceptors
    end
  
    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
  end