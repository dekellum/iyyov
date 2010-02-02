require 'iyyov/base'

module Iyyov

  class Defaults
    attr_accessor :base_dir
    def initialize
      @base_dir  = "/opt/var"
      #FIXME: Support alt gem home then ours?
    end
  end

  # FIXME: avoid this somehow? Pass Defualts (or Context) on Daemon construction
  @@defaults = Defaults.new

  def self.defaults
    yield @@defaults if block_given?
    @@defaults
  end

  # FIXME: GemDaemon has all the gem based specifics?
  class Daemon
    attr_reader :name

    attr_writer :instance
    attr_writer :base_dir
    attr_writer :run_dir
    attr_writer :pid_file
    attr_writer :logs

    attr_writer :gem_name
    attr_writer :version
    attr_writer :init_name

    [ :instance, :base_dir, :run_dir, :pid_file, :logs,
      :gem_name, :version, :init_name ].each do |sym|
      define_method( sym.to_s ) { un( instance_variable_get( "@#{sym}" ) ) }
    end

    def initialize( name )
      @name      = name
      @gem_name  = name
      @init_name = name
      @version   = '>= 0'
      @instance  = nil
      @base_dir  = "/opt/var"
      @run_dir   = lambda do
        File.join( base_dir, [ name, instance ].compact.join('-') )
      end
      @pid_file = lambda {   in_dir( name + '.pid' )   }
      @logs     = lambda { [ in_dir( name + '.log' ) ] }

      yield self if block_given?
      nil
    end

    # Return primative value or result of proc.call
    def un( value )
      value.respond_to?( :call ) ? value.call : value
    end

    # Return full path to file_name within run_dir
    def in_dir( file_name )
      File.join( run_dir, file_name )
    end

    def init_path
      spec = Gem.source_index.find_name( name, version ).last or
        raise( Gem::GemNotFoundException,
               "can't find gem #{name} (#{version})" )
      File.join( spec.full_gem_path, 'init', init_name )
    end

    def start
      Dir.chdir( run_dir ) do
        system( init_path ) or raise( "Start failed with " + $? )
      end
      # FIXME: Wait for pid. If doesn't happen log error?
    end

    def stop
      id = pid
      if id > 0
        Process.kill( "TERM", id )
        # FIXME: Wait for pid?
        true
      else
        false
      end
    rescue Errno::ESRCH
      # No such process: only raised by MRI ruby currently
      # FIXME: EPERM: not permitted? Also MRI ruby only.
      false
    end

    def pid
      id = IO.read( pid_file ).strip.to_i
      id > 0 ? id : -1
    rescue Errno::ENOENT
      -1
    end
  end

  # FIXME: Add configuration/collection watch poll mechenism, which would allow
  # additions,upgrades,etc. to be gracefully handled. Do some use cases.

  # GC monitoring could be done from here as well.
end
