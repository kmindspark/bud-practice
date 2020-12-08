module Protocol
  state do
    table :data
    table :received
    channel :message_func, [:@addr, :key] => [:val]
  end
end
