module ChatClientModule
  bootstrap do
    connect <~ [["127.0.0.1:12345", ip_port, @nick]]
  end

  bloom do
    mcast <~ stdio do |s|
      ["127.0.0.1:12345", [ip_port, @nick, Time.new.strftime("%I:%M.%S"), s.line]]
    end

    stdio <~ mcast { |m| [pretty_print(m.val)] }
  end
end