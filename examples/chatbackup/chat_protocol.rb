module ChatProtocol
    state do
      channel :connect, [:@addr, :client] => [:nick]
      channel :connect_backup, [:@addr, :client] => [:nick]
      channel :mcast
      table :testtable
      periodic :timer, 1
      channel :ack, [:@addr, :timestamp]
      table :pending
      table :acktimestamps, [:timestamp] => [:message]
      table :servertwosent, [:timestamp]
      table :todelete
      table :intermediate
      table :curTimeCapture
    end
  
    DEFAULT_ADDR = "127.0.0.1:12345"
    DEFAULT_BACKUP_ADDR = "127.0.0.1:12346"
  end
  