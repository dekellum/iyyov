
Iyyov.context do |c|
  count = 0
  log = RJack::SLF4J["hello"]
  c.schedule_at( :name => "hello", :mode => :async, :period => 1.5 ) do
    count += 1
    sleep count
    log.info "Hello after #{count}s"
    :stop unless count <= 10 # Avoid killing ourselves.
  end
end
