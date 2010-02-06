require 'java'

module Iyyov

  class Scheduler

    class Task
      attr_accessor :next_time
      attr_accessor :period
      # attr_accessor :fixed_times
      # require 'time'
      # Time.parse("16:30")
      # Fixed time every day

      def initialize( period = nil, &block )
        # puts period.inspect
        @next_time = nil
        @period = period
        # @fixed_times = nil
        @block = block
      end

      def call
        @block.call if @block
      end

      def schedule( now )
        @next_time = nil
        # puts [ now, period ].inspect
        @next_time = ( now + period ) if period
        @next_time
      end

    end

    class TimeComp
      include Java::java.util.Comparator
      def compare( p, n )
        p.next_time <=> n.next_time
      end
    end

    def initialize
      # min heap
      @queue = Java::java.util.PriorityQueue.new( 67, TimeComp.new )
    end

    def add( t, now = Time.now )
      @queue.add( t ) if t.schedule( now )
    end

    def peek
      @queue.peek
    end

    def

    def poll
      @queue.poll
    end

    def event_loop
      delta = nil
      loop do
        now = Time.now
        loop do
          if ( top = peek )
            delta = top.next_time - now
            if delta <= 0.0
              t = @queue.poll
              t.call
              add( t, now )
              next
            end
          end
          break
        end
        break if delta < 0.0
        sleep delta
      end
      false
    end

  end
end
