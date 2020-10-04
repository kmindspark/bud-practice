module PaxosProtocol
    #Use schemas
    state do
      channel :connect
      channel :client_get_request
      channel :client_put_request
      table :get_transactions
      table :put_transactions
      table :tx_id
      table :readset, [:tx_id, :key]
      table :writeset, [:tx_id, :key]
      channel :read_result
      table :main_storage, [:key, :version] => [:value]
      table :main_kvi, [:key, :version] => [:value]

      scratch :sink
      periodic :timer, 1

      #now transferring ruby functionality to Bloom
      #lset :acceptors
      #lmax :num_acceptors
    end

    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
  end