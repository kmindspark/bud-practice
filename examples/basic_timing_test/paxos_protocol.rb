module Protocol
    #Use schemas
    state do
      channel :test_channel
      scratch :sink
      periodic :timer, 0.3

      #now transferring ruby functionality to Bloom
      #lset :acceptors
      #lmax :num_acceptors
    end

    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
  end