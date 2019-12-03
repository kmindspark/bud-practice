module PaxosProtocol
    state do
      channel :connect
      channel :client_request
      channel :prepare
      channel :promise
      channel :accept
      channel :accepted
    end
  
    DEFAULT_CLIENT_ADDR = "127.0.0.1:12345"
    DEFAULT_PROPOSER_ADDR = "127.0.0.1:12346"
    DEFAULT_ACCEPTOR_ADDR = "127.0.0.1:12347"
  end