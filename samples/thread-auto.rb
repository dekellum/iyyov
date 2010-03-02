require 'thread'

Iyyov.context do |c|
  count = 0
  log = SLF4J["hello-auto"]
  c.schedule_at( :name => "hello-auto", :mode => :async, :period => 1.5 ) do
    count += 1
    sleep count
    log.debug "Hello after #{count}s"
    :stop unless count <= 10 # Avoid killing ourselves.
  end
end
