require 'java'

module Iyyov

  class ShutdownHandler
    Thread  = Java::java.lang.Thread
    Runtime = Java::java.lang.Runtime
    include Java::java.lang.Runnable

    def initialize( &block )
      @block = block
      @handler = Thread.new( self )
      Runtime::runtime.add_shutdown_hook( @handler )
    end

    def deregister
      Runtime::runtime.remove_shutdown_hook( @handler )
    end

    def run
      @block.call
    end

  end
end
