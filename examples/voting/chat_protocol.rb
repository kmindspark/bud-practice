module ChatProtocol
    state do
      channel :connect, [:@addr, :client] => [:nick]
      channel :connect_backup, [:@addr, :client] => [:nick]
      channel :mcast
    end
  
    DEFAULT_ADDR = "127.0.0.1:12345"
    DEFAULT_BACKUP_ADDR = "127.0.0.1:12346"
  end
  