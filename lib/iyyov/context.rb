#--
# Copyright (c) 2010-2012 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'rjack-slf4j'
require 'fileutils'

require 'iyyov/errors'
require 'iyyov/task'
require 'iyyov/scheduler'
require 'iyyov/daemon'
require 'iyyov/foreground_process'

module Iyyov

  class Context

    # Default base directory under which Daemon run directories are found
    #
    # ~to_s (default: /opt/var)
    attr_accessor :base_dir

    # Default whether to make Daemon run directories if not already present.
    #
    # Boolean (default: true)
    attr_accessor :make_run_dir

    # Default whether to stop Daemons on Iyyov exit.
    #
    # Boolean (default: false)
    attr_accessor :stop_on_exit

    # Default duration in seconds between SIGTERM and final SIGKILL when
    # stopping Daemons.
    #
    # Numeric (default: 30.0)
    attr_accessor :stop_delay

    # Watch loaded config files for changes?
    #
    # Boolean (default: true)
    attr_accessor :watch_files

    attr_reader   :scheduler
    attr_reader   :daemons

    def initialize
      super

      @base_dir     = "/opt/var"
      @make_run_dir = true
      @stop_on_exit = false
      @stop_delay   = 30.0
      @watch_files  = true

      #FIXME: Support other gem home than ours?

      @rotators  = {}
      @daemons   = {}
      @state     = :begin
      @log = RJack::SLF4J[ self.class ]
      @scheduler = Scheduler.new
      @scheduler.on_exit { do_shutdown }
      @files     = {}
      @root_files = []

      # By default with potential for override
      iyyov_log_rotate

      yield self if block_given?
    end

    def shutdown
      do_shutdown
      @scheduler.off_exit
    end

    def do_shutdown
      unless @state == :shutdown
        @log.info "Shutting down"
        @daemons.values.each { |d| d.do_exit }
        @state = :shutdown
      end
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
      t = Task.new( opts, &block )
      @scheduler.add( t )
    end

    def define_daemon( &block )
      d = Daemon.new( self, &block )
      if @daemons.has_key?( d.full_name )
        raise( SetupError,
               "Can't define daemon with duplicate full_name = #{d.full_name}" )
      end
      @daemons[ d.full_name ] = d
      nil
    end

    def define_foreground_process( &block )
      d = ForegroundProcess.new( self, &block )
      if @daemons.has_key?( d.full_name )
        raise( SetupError,
               "Can't define foreground process with duplicate full_name = #{d.full_name}" )
      end
      @daemons[ d.full_name ] = d
      nil
    end

    def load_file( file, is_root = false )
      @log.info { "Loading #{file}" }
      begin
        load file
        @files[ file ] = File.stat( file ).mtime
        @root_files << file if is_root
        true
      rescue SetupError, ScriptError, StandardError => e
        @log.error( "On load of #{file}", e )
        false
      end
    end

    def register_rotator_tasks
      @rotators.values.each do |lr|
        t = Task.new( :name => rotate_name( lr.log ),
                      :mode => :async,
                      :period => lr.check_period ) do
          lr.check_rotate do |rlog|
            @log.info { "Rotating log #{rlog}" }
          end
        end
        @scheduler.add( t )
      end
    end

    def register_files_watch_task
      return unless @watch_files && ! @files.empty?
      t = Task.new( :name => "watch-files", :period => 11.0 ) do
        reload = false
        @files.each do |fname, last_time|
          begin
            new_time = File.stat( fname ).mtime
            if new_time != last_time
              @log.info { "#{fname} has new modification time, reloading." }
              reload = true
              break
            end
          rescue Errno::ENOENT, Errno::EACCES => e
            @log.error( e.to_s )
          end
        end
        rc = :continue
        if reload
          @log.info { "Rescaning gems." }
          Gem.clear_paths
          if Iyyov.load_root_files( @root_files )
            @log.info "Load passed, shutdown"
            rc = :shutdown
          end
        end
        rc
      end
      @scheduler.add( t )
    end

    def start_and_register_daemons
      @daemons.values.each { |d| d.do_first( @scheduler ) }
    end

    def rotate_name( log_file )
      "#{ File.basename( log_file, ".log" ) }.rotate"
    end

    def event_loop
      @state = :starting
      start_and_register_daemons
      register_rotator_tasks
      register_files_watch_task

      @log.debug "Event loop starting"
      @state = :running
      rc = @scheduler.event_loop
      @state = :exit
      @log.debug { "Event loop exited: #{rc.inspect}" }
      rc
    end
  end

end
