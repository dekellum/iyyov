
require 'rjack-slf4j'
require 'fileutils'

module Iyyov
  include RJack

  # FIXME: GemDaemon has all the gem based specifics?
  class Daemon

    attr_accessor :name

    attr_writer   :instance
    attr_writer   :base_dir
    attr_writer   :run_dir
    attr_accessor :make_run_dir

    attr_writer   :pid_file
    attr_writer   :logs

    attr_writer   :gem_name
    attr_writer   :version
    attr_writer   :init_name

    LVARS = [ :@instance, :@base_dir, :@run_dir, :@pid_file, :@logs,
              :@gem_name, :@version, :@init_name ]

    def initialize( context = Iyyov.context )

      @context      = context
      @name         = nil

      @instance     = nil
      @base_dir     = method :default_base_dir
      @run_dir      = method :default_run_dir
      @make_run_dir = @context.make_run_dir

      @pid_file     = method :default_pid_file
      @logs         = method :default_logs

      @gem_name     = method :name
      @version      = '>= 0'
      @init_name    = method :name

      yield self

      raise "name not specified" unless name

      @log = SLF4J[ [ SLF4J[ self.class ].name, name ].join( '.' ) ]

      validate
      nil
    end

    def validate

      unless File.directory?( run_dir )
        if make_run_dir
          @log.info { "Creating run_dir [#{run_dir}]." }
          FileUtils.mkdir_p( run_dir, :mode => 0755 )
        else
          raise "run_dir [#{run_dir}] not found"
        end
      end
    end

    def default_base_dir
      @context.base_dir
    end

    def default_run_dir
      File.join( base_dir, [ name, instance ].compact.join('-') )
    end

    def default_pid_file
      in_dir( name + '.pid' )
    end

    def default_logs
      [ in_dir( name + '.log' ) ]
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
      if id
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

    # Return process ID from pid_file if exists or nil otherwise
    def pid
      id = IO.read( pid_file ).strip.to_i
      ( id > 0 ) ? id : nil
    rescue Errno::ENOENT # Pid file doesn't exist
      nil
    end

    LVARS.each do |sym|
      define_method( sym.to_s[1..-1] ) do
        exp = instance_variable_get( sym )
        exp.respond_to?( :call ) ? exp.call : exp
      end
    end

  end

  # FIXME: Add configuration/collection watch poll mechanism, which would allow
  # additions,upgrades,etc. to be gracefully handled. Do some use cases.

  # GC monitoring could be done from here as well.
end
