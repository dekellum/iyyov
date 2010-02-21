
require 'rjack-slf4j'
require 'fileutils'

require 'iyyov/log_rotator'

module Iyyov
  include RJack

  # A daemon isntance to start and monitor
  class Daemon

    # Name of this daemon. Must be unique in combination with any
    # specified instance.
    # <String> (Required)
    attr_accessor :name

    # Optional specific instance identifier, distinguishing this
    # daemon from others of the same name. For example, a port number
    # could be used.
    # <Proc,~to_s> (Default: nil)
    attr_writer   :instance

    # Full path to executable to start.
    # <Proc,~to_s> (Default: compute from gem_name, init_name, and version)
    attr_writer   :exe_path

    # Base directory under which run directories are found
    # <Proc,~to_s> (Default: Context.base_dir)
    attr_writer   :base_dir

    # Directory to execute under
    # <Proc,~to_s> (Default: base_dir / full_name)
    attr_writer   :run_dir

    # Whether to make run_dir, if not already present
    # <Boolean> (Default: Context.make_run_dir )
    attr_accessor :make_run_dir

    # Whether to stop this daemon when Iyyov exits
    # <Boolean> (Default: Context.stop_on_exit)
    attr_accessor :stop_on_exit

    # Duration in seconds between SIGTERM and final SIGKILL when
    # stopping.
    # <Numeric> (Default: Context.stop_delay)
    attr_accessor :stop_delay

    # PID file written by the daemon process after start, containing
    # the running daemon Process ID
    # <Proc,~to_s> (Default: run_dir, init_name + '.pid')
    attr_writer   :pid_file

    # The gem name used, in conjunction with version for gem-based default exe_path
    # <Proc,~to_s> (Default: name)
    attr_writer   :gem_name

    # The gem version requirements, i.e '~> 1.1.3'
    # <Proc,~to_s,Array[~to_s]> (Default: '>= 0')
    attr_writer   :version

    # The init script name used for gem-based default exe_path.
    # <Proc,~to_s> (Default: name)
    attr_writer   :init_name

    # Last found state of this daemon.
    # <Symbol> (in STATES)
    attr_reader   :state

    # States tracked
    STATES = [ :begin, :up, :failed, :stopped ]

    # Instance variables which may be set as Procs
    LVARS = [ :@instance, :@exe_path, :@base_dir, :@run_dir, :@pid_file,
              :@gem_name, :@version, :@init_name ]

    # New daemon given specified or default global
    # Iyyov.context. Yields self to block for configuration.
    def initialize( context = Iyyov.context )

      @context      = context
      @name         = nil

      @instance     = nil
      @exe_path     = method :gem_exe_path
      @base_dir     = method :default_base_dir
      @run_dir      = method :default_run_dir
      @make_run_dir = @context.make_run_dir
      @stop_on_exit = @context.stop_on_exit
      @stop_delay   = @context.stop_delay

      @pid_file     = method :default_pid_file
      @gem_name     = method :name
      @version      = '>= 0'
      @init_name    = method :name

      @state        = :begin
      @gem_spec     = nil
      @rotators     = {}

      yield self if block_given?

      raise "name not specified" unless name

      @log = SLF4J[ [ SLF4J[ self.class ].name,
                      name, instance ].compact.join( '.' ) ]
    end

    # Given name + ( '-' + instance ) if provided.
    def full_name
      [ name, instance ].compact.join('-')
    end

    # Create a new LogRotator and yields it to block for
    # configuration.
    # The default log path is name + ".log" in run_dir
    def log_rotate( &block )
      lr = LogRotator.new( default_log, &block )
      @rotators[ lr.log ] = lr
      nil
    end

    # Post initialization validation, attempt immediate start if
    # needed, and add appropriate tasks to scheduler.
    def do_first( scheduler )
      unless File.directory?( run_dir )
        if make_run_dir
          @log.info { "Creating run_dir [#{run_dir}]." }
          FileUtils.mkdir_p( run_dir, :mode => 0755 )
        else
          raise( DaemonFailed, "run_dir [#{run_dir}] not found" )
        end
      end

      res = start_check
      unless res == :stop
        tasks.each { |t| scheduler.add( t ) }
      end
      res
    rescue DaemonFailed, SystemCallError => e
      #FIXME: Ruby 1.4.0 throws SystemCallError when mkdir fails from
      #permissions
      @log.error( e.to_s )
      @state = :failed
      :stop
    end

    def tasks
      t = [ Task.new( :name => full_name, :period => 5.0 ) { start_check } ]
      t += @rotators.values.map do |lr|
        Task.new( :name => "#{full_name}.rotate",
                  :period => lr.check_period ) do
          lr.check_rotate( pid ) do |rlog|
            @log.info { "Rotating log #{rlog}" }
          end
        end
      end
      t
    end

    def do_exit
      stop if stop_on_exit
    end

    def default_base_dir
      @context.base_dir
    end

    def default_run_dir
      File.join( base_dir, full_name )
    end

    def default_pid_file
      in_dir( init_name + '.pid' )
    end

    def default_log
      in_dir( init_name + '.log' )
    end

    # Return full path to file_name within run_dir
    def in_dir( file_name )
      File.join( run_dir, file_name )
    end

    def gem_exe_path
      File.join( find_gem_spec.full_gem_path, 'init', init_name )
    end

    def find_gem_spec
      #FIXME: Use Gem.clear_paths to rescan.
      @gem_spec ||= Gem.source_index.find_name( gem_name, version ).last
      unless @gem_spec
        raise( Gem::GemNotFoundException, "Missing gem #{gem_name} (#{version})" )
      end
      @gem_spec
    end

    def start
      epath = File.expand_path( exe_path )
      aversion = @gem_spec && @gem_spec.version
      @log.info { "starting #{aversion}" }

      unless File.executable?( epath )
        raise( DaemonFailed, "Exe path: #{epath} not found/executable." )
      end

      Dir.chdir( run_dir ) do
        system( epath ) or raise( DaemonFailed, "Start failed with #{$?}" )
      end

      @state = :up
      true
    rescue Gem::GemNotFoundException, DaemonFailed, Errno::ENOENT => e
      @log.error( e.to_s )
      @state = :failed
      false
    end

    def start_check
      p = pid
      if alive?( p )
        @log.debug { "checked: alive pid: #{p}" }
        @state = :up
      else
        unless start
          @log.info "start failed, done trying"
          :stop
        end
      end
    end

    # True if process is up
    def alive?( p = pid )
      ( Process.getpgid( p ) != -1 ) if p
    rescue Errno::ESRCH
      false
    end

    # Stop via SIGTERM, waiting for shutdown for up to stop_delay, then
    # SIGKILL as last resort. Return true if a process was stopped.
    def stop
      p = pid
      if p
        @log.info "Sending TERM signal"
        Process.kill( "TERM", p )
        unless wait_pid( p )
          @log.info "Sending KILL signal"
          Process.kill( "KILL", p )
        end
        @status = :stopped
        true
      end
      false
    rescue Errno::ESRCH
      # No such process: only raised by MRI ruby currently
      false
    rescue Errno::EPERM => e
      # Not permitted: only raised by MRI ruby currently
      @log.error( e )
      false
    end

    # Wait for process to go away
    def wait_pid( p = pid )
      delta = 1.0 / 16
      delay = 0.0
      check = false
      while delay < stop_delay do
        break if ( check = ! alive?( p ) )
        sleep delta
        delay += delta
        delta += ( 1.0 / 16 ) if delta < 0.50
      end
      check
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

  class DaemonFailed < StandardError; end

  # FIXME: Add configuration/collection watch poll mechanism, which would allow
  # additions,upgrades,etc. to be gracefully handled. Do some use cases.

  # GC monitoring could be done from here as well.
end
