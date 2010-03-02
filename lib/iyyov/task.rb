require 'date'
require 'time'
require 'thread'

module Iyyov

  # A task to be scheduled and run.
  class Task

    # Regular interval between subsequent executions in seconds.
    #
    # Numeric (default: nil, use fixed_times)
    attr_accessor :period

    # One or more fixed time values in 24hour format, local
    # timezone, i.e: [ "11:30", "23:30" ]
    #
    # ~to_a[String] (default: nil, use period)
    attr_accessor :fixed_times

    # Array or range for days of week in which fixed_times apply. Days
    # are 0 (Sunday) .. 6 (Saturday). Example: M-F == (1..5)
    #
    # ~include?( day_of_week ) (default: (0..6))
    attr_accessor :fixed_days

    # Name the task for log reporting.
    #
    # String (default: nil)
    attr_accessor :name

    # Execution mode. If :async, run in separate thread, but only
    # allow one thread for this task to run at any time.
    #
    # Symbol :sync|:async (default: :sync)
    attr_accessor :mode

    # Once schedule succeeds, the absolute next time to execute.
    attr_reader :next_time

    # New task given options matching accessors and block containing
    # work.
    def initialize( opts = {}, &block )
      @name        = nil
      @next_time   = nil
      @period      = nil
      @fixed_times = nil
      @fixed_days  = (0..6) #all

      opts.each { |k,v| send( k.to_s + '=', v ) }

      @block = block

      #FIXME: Validation?

      @log = SLF4J[ [ SLF4J[ self.class ].name, name ].compact.join( '.' ) ]

      @lock = ( Mutex.new if mode == :async )
      @async_rc = nil

      @log.info { "Task created : #{ opts.inspect }" }
    end

    # Execute the task, after which the task will be scheduled again
    # in period time or for the next of fixed_times, unless :stop is
    # returned.
    def run
      rc = :continue
      if mode == :async
        rc = test_async_return_code
        run_thread if rc == :continue
      else
        rc = run_direct
      end
      rc
    end

    def test_async_return_code
      rc = :continue
      # Note: Currently only the main event loop thread goes here and
      # so the only case for contention is this task already running
      # in run_thread. In this case we can warn + :skip early.
      if @lock.try_lock
        begin
          rc = @async_rc if ( @async_rc == :stop ) || ( @async_rc == :shutdown )
        ensure
          @lock.unlock
        end
      else
        @log.warn "Already running, (pre) skipping this run."
        rc = :skip
      end
      rc
    end

    def run_thread
      Thread.new do
        if @lock.try_lock
          begin
            @async_rc = run_direct
          ensure
            @lock.unlock
          end
        else
          @log.warn "Already running, skipping this run."
        end
      end
    end

    def run_direct
      @log.debug "Running."
      rc = ( @block.call if @block )
      #FIXME: Errors to handle?
      filter( rc )
    end

    def filter( rc )
      rc.is_a?( Symbol ) ? rc : :continue
    end

    # Determine next_time from now based on period or fixed_times
    def schedule( now )
      @next_time = nil

      if fixed_times
        @next_time = next_fixed_time( now )
      elsif period
        @next_time = ( now + period )
      end

      if @next_time && ( @next_time - now ) > 60.0
        @log.debug { "Next run scheduled @ #{ next_time_to_s }" }
      end

      @next_time
    end

    def next_time_to_s
      @next_time.strftime( '%Y-%m-%dT%H:%M:%S' ) if @next_time
    end

    def next_fixed_time( now )
      day = Date.civil( now.year, now.month, now.day )
      last = day + 7
      ntime = nil
      while ntime.nil? && day <= last
        if fixed_days.include?( day.wday )
          fixed_times.to_a.each do |ft|
            ft = time_on_date( day, Time.parse( ft, now ) )
            ntime = ft if ( ( ft > now ) && ( ntime.nil? || ft < ntime ) )
          end
        end
        day += 1
      end
      ntime
    end

    def time_on_date( d, t )
      Time.local( d.year, d.month, d.day, t.hour, t.min, t.sec, t.usec )
    end

  end
end
