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

      #now transferring ruby functionality to Bloom
      lset :acceptors
      lmax :num_acceptors
    end
  
    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
  end