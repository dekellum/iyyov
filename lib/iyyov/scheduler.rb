#--
# Copyright (c) 2010-2014 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

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
      @log = RJack::SLF4J[ self.class ]
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
      @log.debug { "Registered exit: #{ @shutdown_handler.handler }" }
    end

    # Deregister any previously added on_exit block
    def off_exit
      if @shutdown_handler
        @log.debug { "Unregistered exit: #{ @shutdown_handler.handler }" }
        @shutdown_handler.unregister
        @shutdown_handler = nil
      end
    end

    # Loop forever executing tasks or waiting for the next to be
    # ready. Return only when the queue is empty (which may be arranged by
    # on_exit) or if a Task returns :shutdown.
    def event_loop
      rc = nil

      # While not shutdown
      while ( rc != :shutdown )
        now = Time.now
        delta = 0.0

        @lock.synchronize do
          # While we don't need to wait, and a task is available
          while ( delta <= 0.0 && ( task = peek ) && rc != :shutdown )
            delta = task.next_time - now

            if delta <= 0.0
              task = poll

              rc = task.run
              add( task, now ) unless ( rc == :shutdown || rc == :stop )
            end
          end
        end #lock

        break unless delta > 0.0
        sleep delta
      end

      if rc == :shutdown
        @log.debug "Begin scheduler shutdown sequence."
        @queue.clear
        off_exit
      end
      rc
    end

    # Implements java.util.Comparator over task.next_time values
    class TimeComp
      include Java::java.util.Comparator
      def compare( p, n )
        p.next_time <=> n.next_time
      end
    end

  end
end
