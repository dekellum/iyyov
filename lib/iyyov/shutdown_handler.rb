require 'java'

module Iyyov

  class ShutdownHandler
    Thread  = Java::java.lang.Thread
    Runtime = Java::java.lang.Runtime
    include Java::java.lang.Runnable

    def initialize( block )
      @block = block
    end

    def run
      @block.call
    end

    def self.on_exit( &block )
      Runtime::runtime.add_shutdown_hook( Thread.new( new( block ) ) )
    end
  end
end
