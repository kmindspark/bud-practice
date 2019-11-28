module VotingProtocol
    state do
      channel :connect, [:@addr, :client] => [:nick]
      channel :connect_backup, [:@addr, :client] => [:nick]
      channel :mcast
      table   :mcast_mod
      lset    :votesA
      lset    :votesB
      lmax    :vote_cnt_A
      lmax    :vote_cnt_B
      table   :users_voted
      table   :both_votes, [:votesA, :votesB]
      table   :voter_log
      scratch :cur_matches
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