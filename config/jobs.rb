Iyyov.context do |c|

  c.define_daemon do |d|
    d.name     = "hashdot-test-daemon"
    d.version  = "~> 1.0"
    d.stop_on_exit = true
    d.stop_delay = 2.0
    d.log_rotate
    d.log_rotate do |l|
      l.max_size = 500
      l.check_period = 21.0
    end
  end

  c.define_foreground_process do |p|
    p.name       = "foreground-daemon"
    p.exe_path   = '/bin/bash'
    p.args       = [ '-c', 'cat /dev/urandom  > /dev/null' ]
  end

  c.schedule_at( :name => "hello", :period => 3.0 ) do
    puts "hello every 3.0 seconds"
  end

  c.schedule_at( :name => "fixed",
                 :fixed_times => %w[ 00:03 1:00 2:00 3:00 4:00 12:00 ] ) do
    puts "Fixed time task"
  end

  c.iyyov_log_rotate do |l|
    l.max_size = 50_000
    l.check_period = 17.0
  end

end
