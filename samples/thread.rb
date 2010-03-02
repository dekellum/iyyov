require 'thread'

Iyyov.context do |c|
  counter = 0
  log = SLF4J["hello-1"]
  c.schedule_at( :name => "hello-1", :period => 1.5 ) do
    counter += 1
    log.debug "Spawning sleeper for #{counter}s"
    Thread.new( counter ) do |n|
      sleep n
      log.debug "Hello after #{n}s"
    end
    :stop unless counter < 20 # Avoid killing ourselves.
  end
end
