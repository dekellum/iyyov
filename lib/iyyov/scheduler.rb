require 'java'

require 'thread'
require 'iyyov/shutdown_handler'

module Iyyov

  # Maintains a queue of Task to be executed at fixed or periodic
  # times.
  class Scheduler

    def initialize
      # min heap
      @queue = Java::java.util.PriorityQueue.new( 67, TimeComp.new )
      @lock = Mutex.new
      @shutdown_handler = nil
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

    # Execute the specified block on exit (in a shutdown thread.) The
    # Scheduler queue is drained such that the on_exit block is
    # guaranteed to be the last to run.
    def on_exit( &block )
      off_exit
      @shutdown_handler = ShutdownHandler.new do

        # Need to lock out the event loop since exit handler is called
        # from a different thread.
        @lock.synchronize do
          @queue.clear
          block.call
        end
      end
    end

    # Deregister any previously added on_exit block
    def off_exit
      @shutdown_handler.deregister if @shutdown_handler
      @shutdown_handler = nil
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
                t = poll
                ret = t.run
                add( t, now ) unless ( ret.is_a?( Symbol ) && ret == :stop )
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
