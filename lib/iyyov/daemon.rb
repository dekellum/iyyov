
require 'rjack-slf4j'
require 'fileutils'

require 'iyyov/log_rotator'

module Iyyov
  include RJack

  # FIXME: GemDaemon has all the gem based specifics?
  class Daemon

    attr_accessor :name

    attr_writer   :instance
    attr_writer   :exe_path
    attr_writer   :base_dir
    attr_writer   :run_dir
    attr_accessor :make_run_dir
    attr_accessor :stop_on_exit
    attr_accessor :stop_delay

    attr_writer   :pid_file

    attr_writer   :gem_name
    attr_writer   :version
    attr_writer   :init_name
    attr_reader   :state

    # States tracked
    STATES = [ :begin, :up, :failed, :stopped ]

    # Instance variables which may be set as Procs
    LVARS = [ :@instance, :@exe_path, :@base_dir, :@run_dir, :@pid_file,
              :@gem_name, :@version, :@init_name ]

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

      yield self

      raise "name not specified" unless name

      @log = SLF4J[ [ SLF4J[ self.class ].name,
                      name, instance ].compact.join( '.' ) ]

      validate
      nil
    end

    # Create a new LogRotator and yields it to block for
    # configuration.
    # The default log path is name + ".log" in run_dir
    def log_rotate( &block )
      lr = LogRotator.new( default_log, &block )
      @rotators[ lr.log ] = lr
      nil
    end

    def tasks
      t = [ Scheduler::Task.new( :period => 5.0 ) { start_check } ]
      t += @rotators.values.map do |lr|
        Scheduler::Task.new( :period => lr.check_period ) do
          lr.check_rotate( pid ) do |rlog|
            @log.info { "Rotating log #{rlog}" }
          end
          true
        end
      end
      t
    end

    def do_first
      start_check
    end

    def do_exit
      stop if stop_on_exit
    end

    def validate

      unless File.directory?( run_dir )
        if make_run_dir
          @log.info { "Creating run_dir [#{run_dir}]." }
          FileUtils.mkdir_p( run_dir, :mode => 0755 )
        else
          raise "run_dir [#{run_dir}] not found"
          #FIXME: Log instead?
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
      epath = exe_path
      aversion = @gem_spec && @gem_spec.version
      @log.info "starting #{aversion}"

      Dir.chdir( run_dir ) do
        system( exe_path ) or raise( "Start failed with " + $? )
      end
    rescue Gem::GemNotFoundException => e
      @log.error( e.to_s )
      @state = :failed
      # FIXME: Pull tasks out of scheduler?
    end

    def start_check
      p = pid
      if alive?( p )
        @log.debug { "checked: alive (pid:#{p})" }
      else
        start
      end
      true #FIXME: Error handled -> failed, false
    end

    def alive?( p = pid )
      ( Process.getpgid( p ) != -1 ) if p
    rescue Errno::ESRCH
      false
    end

    def stop
      p = pid
      if p
        @log.info "Sending TERM signal"
        Process.kill( "TERM", p )
        unless wait_pid( p )
          @log.info "Sending KILL signal"
          Process.kill( "KILL", p )
        end
        true
      end
      false
    rescue Errno::ESRCH
      # No such process: only raised by MRI ruby currently
      # FIXME: EPERM: not permitted? Also MRI ruby only.
      false
    end

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

  # FIXME: Add configuration/collection watch poll mechanism, which would allow
  # additions,upgrades,etc. to be gracefully handled. Do some use cases.

  # GC monitoring could be done from here as well.
end
