require 'iyyov/base'

require 'iyyov/scheduler'
require 'iyyov/daemon'

require 'rjack-slf4j'
require 'fileutils'

module Iyyov

  class Context
    attr_accessor :base_dir
    attr_accessor :make_run_dir
    attr_accessor :stop_on_exit
    attr_accessor :stop_delay

    # Private?
    attr_reader   :scheduler

    def initialize
      @base_dir     = "/opt/var"
      @make_run_dir = true
      @stop_on_exit = false
      @stop_delay   = 30.0

      #FIXME: Support other gem home than ours?
      @rotators  = {}
      @daemons   = []
      @log = RJack::SLF4J[ self.class ]
      @scheduler = Scheduler.new
      @scheduler.on_exit do
        @log.info "Shutting down"
        @daemons.each { |d| d.do_exit }
      end

      # By default with potential for override
      iyyov_log_rotate

      yield self if block_given?
    end

    # Setup log rotation not associated with a daemon
    def log_rotate( &block )
      lr = LogRotator.new( nil, &block )
      @rotators[ lr.log ] = lr
    end

    # Setup log rotation for the iyyov daemon itself
    def iyyov_log_rotate( &block )
      rf = Java::java.lang.System.get_property( "hashdot.io_redirect.file" )
      if rf && File.exist?( rf )
        lr = LogRotator.new( rf, &block )
        lr.pid = 0
        @rotators[ lr.log ] = lr
      end
    end

    def schedule_at( opts = {}, &block )
      t = Scheduler::Task.new( opts ) do
        @log.info { "scheduled at : #{ opts.inspect }" }
        block.call
      end
      @scheduler.add( t )
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

    def register_tasks
      @rotators.values.each do |lr|
        t = Scheduler::Task.new( :period => lr.check_period ) do
          lr.check_rotate do |rlog|
            @log.info { "Rotating log #{rlog}" }
          end
        end
        @scheduler.add( t )
      end
    end

    def event_loop
      register_tasks #FIXME: Better place for this?

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
