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

    def initialize
      @base_dir  = "/opt/var"
      @make_run_dir = true

      @scheduler = Scheduler.new

      #FIXME: Support alt gem home then ours?
      @daemons = []

      @log = SLF4J[ self.class ]
    end

    def define_daemon( &block )
      d = Daemon.new( self, &block )
      @scheduler.add( WatchTask.new( d ) )
      @daemons << d
      nil
    end

    def load_file( file )
      @log.info { "Loading #{file}" }
      load file
    end

    def event_loop
      @scheduler.run
    end
  end

  class WatchTask < Scheduler::Task
    def initialize( daemon )
      super( 5.0 )
      @daemon = daemon
      @log = SLF4J[ self.class ]
    end
    def call
      pid = @daemon.pid
      alive = pid && check_pid( pid )
      if alive
        @log.info { "#{@daemon.name} is alive" }
      else
        @log.info { "#{@daemon.name} starting" }
        @daemon.start
      end
    end
    def check_pid( pid )
      File.directory?( '/proc/' + pid.to_s )
    end
  end

  @context = Context.new

  def self.context
    yield @context if block_given?
    @context
  end
end
