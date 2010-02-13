require 'java'

require 'thread'
require 'date'
require 'time'
require 'iyyov/shutdown_handler'

module Iyyov

  # Maintains a queue of Tasks to be executed at regular or periodic
  # times.
  class Scheduler

    # A task to be executed by the Scheduler
    class Task
      attr_accessor :next_time

      # Regular interval between subsequent executions in seconds.
      # The Period will be ignored if fixed_times is set.
      # <numeric>
      attr_accessor :period

      # One or more fixed time values in 24hour format, local
      # timezone, i.e: [ "11:30", "23:30" ]
      # ~to_a[String]
      attr_accessor :fixed_times

      # Array or range for days of week in which fixed_times
      # apply. Days are 0 (Sunday) .. 6 (Saturday). Example: M-F == (1..5)
      # ~include?( day_of_week ) (default: (0..6))
      attr_accessor :fixed_days

      # Name the task for log reporting.
      attr_accessor :name

      # New task given options matching accessors and block containing
      # work.
      def initialize( opts = {}, &block )
        @name        = nil
        @next_time   = nil
        @period      = nil
        @fixed_times = nil
        @fixed_days  = (0..6) #all

        opts.each { |k,v| send( k.to_s + '=', v ) }

        #FIXME: Validation.

        @block = block
      end

      # Execute the task
      def run
        @block.call if @block
      end

      # Determine next_time from now based on period or fixed_times
      def schedule( now )
        @next_time = nil

        if fixed_times
          @next_time = next_fixed_time( now )
        elsif period
          @next_time = ( now + period )
        end

        @next_time
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

    def initialize
      # min heap
      @queue = Java::java.util.PriorityQueue.new( 67, TimeComp.new )
      @lock = Mutex.new
    end

    def add( t, now = Time.now )
      @queue.add( t ) if t.schedule( now )
    end

    def peek
      @queue.peek
    end

    def poll
      @queue.poll
    end

    # Execute the specified block on exit. The Scheduler queue is
    # drained such that the on_exit block is guaranteed to be the last
    # to run.
    def on_exit( &block )
      ShutdownHandler.on_exit do

        # Need to lock out the event loop since exit handler is called
        # from a different thread.
        @lock.synchronize do
          @queue.clear
          block.call
        end
      end
    end

    # Loop forever executing tasks or waiting for the next to be ready
    # Will return when the queue is empty (which may be arranged by
    # on_exit)
    def event_loop
      delta = nil

      # While there is some task remaining and therefore some time to
      # wait...
      loop do
        now = Time.now

        @lock.synchronize do

          # While the top task is ready..
          loop do
            if ( top = peek )
              delta = top.next_time - now
              if delta <= 0.0
                t = @queue.poll
                add( t, now ) if t.run
                next
              end
            else
              delta = nil
            end
            break
          end

        end
        break unless delta && delta > 0.0
        sleep delta
      end
    end

    # Implement java.util.Comparator on task.next_time values
    class TimeComp
      include Java::java.util.Comparator
      def compare( p, n )
        p.next_time <=> n.next_time
      end
    end

  end
end
