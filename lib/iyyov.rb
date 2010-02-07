require 'iyyov/base'

require 'iyyov/scheduler'
require 'iyyov/daemon'

require 'rjack-slf4j'
require 'fileutils'

module Iyyov
  include RJack

  class Context
    attr_accessor :base_dir
    attr_accessor :make_run_dir
    attr_accessor :stop_on_exit
    attr_accessor :stop_delay

    # Private?
    attr_reader   :scheduler

    def initialize
      @base_dir  = "/opt/var"
      @make_run_dir = true
      @stop_on_exit = false
      @stop_delay = 30.0

      #FIXME: Support other gem home than ours?
      @daemons = []
      @log = SLF4J[ self.class ]
      @scheduler = Scheduler.new
      @scheduler.on_exit do
        @log.info "Shutting down"
        @daemons.each { |d| d.do_exit }
      end

      yield self if block_given?
    end

    def define_daemon( &block )
      d = Daemon.new( self, &block )
      @daemons << d
      d.tasks.each { |t| @scheduler.add( t ) }
      d.do_first
      nil
    end

    def load_file( file )
      @log.info { "Loading #{file}" }
      load file
    end

    def event_loop
      @scheduler.event_loop
      @log.info "Event loop exited"
    end

  end

  @context = Context.new

  def self.context
    yield @context if block_given?
    @context
  end
end
