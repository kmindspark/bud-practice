module VotingProtocol
    state do
      channel :connect, [:@addr, :client] => [:nick]
      channel :connect_backup, [:@addr, :client] => [:nick]
      channel :mcast
      lset    :votesA
      lset    :votesB
      lmax    :vote_cnt_A
      lmax    :vote_cnt_B
      table   :users_voted
      table   :both_votes, [:votesA, :votesB]
      channel :resp

      channel :recoveryRequest
      channel :recoveryA
      channel :recoveryB

      table   :tempA, [:k]
      table   :tempB, [:k]
    end
  
    DEFAULT_ADDR = "127.0.0.1:12345"
    DEFAULT_BACKUP_ADDR = "127.0.0.1:12346"
  end