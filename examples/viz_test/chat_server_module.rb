module ChatServerModule
  state { table :nodelist }

  bloom do
    nodelist <= connect { |c| [c.client, c.nick] }
    mcast <~ (mcast * nodelist).pairs { |m,n| [n.key, m.val] }
  end
end