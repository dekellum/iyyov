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

    # Private?
    attr_reader   :scheduler

    def initialize
      @base_dir  = "/opt/var"
      @make_run_dir = true

      #FIXME: Support other gem home than ours?

      yield self if block_given?

      @scheduler = Scheduler.new

      @daemons = []
      @log = SLF4J[ self.class ]
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
    end
  end

  @context = Context.new

  def self.context
    yield @context if block_given?
    @context
  end
end
