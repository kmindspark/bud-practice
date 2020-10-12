module Protocol
    #Use schemas
    state do
      channel :test_channel, [:@addr, :slot, :id, :val, :ip]
      table :temp_table
      scratch :sink
      scratch :sink2
      periodic :timer, 0.001
      scratch :timer_buffer, [:slot, :id, :val, :ip]
      channel :response, [:@addr, :slot, :id, :val]
      table :slot_num

      #now transferring ruby functionality to Bloom
      #lset :acceptors
      #lmax :num_acceptors
    end

    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
  end