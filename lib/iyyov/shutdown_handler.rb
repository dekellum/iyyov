require 'java'

module Iyyov

  class ShutdownHandler
    Thread  = Java::java.lang.Thread
    Runtime = Java::java.lang.Runtime

    include Java::java.lang.Runnable

    attr_reader :handler

    def initialize( &block )
      @block = block
      @handler = Thread.new( self )
      Runtime::runtime.add_shutdown_hook( @handler )
    end

    def unregister
      Runtime::runtime.remove_shutdown_hook( @handler )
      @handler = nil
      @block = nil
    end

    def run
      @block.call
    end

  end
end
