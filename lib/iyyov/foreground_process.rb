#--
# Copyright (c) 2010-2013 David Kellum
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

module Iyyov
  include RJack

  # Support external processes that run in the foreground as daemons (daemonized
  # with help from Iyyov). All output from the process will be logged to the Iyyov
  # log. This is intended for processes that run on the foreground but manage
  # logging seperately.
  class ForegroundProcess < Daemon
    include Java
    import java.lang.System
    import java.lang.IllegalThreadStateException

    # Start the daemon process
    def exec_command( command, args )
      process_builder = java.lang.ProcessBuilder.new( command, *args )
      process_builder.directory( java.io.File.new( Dir.pwd ) )

      # Java 7 required
      redirected = attempt_io_redirect( process_builder )
      unless redirected
        log.warn( "I/O redirect of forground process #{name} disabled. Java 7 required." )
      end

      @process = process_builder.start

      # Write pid file
      File.open( pid_file, 'w' ) {|f| f.write( process_pid ) }
    end

    def alive?( pid = pid )
      if @process && process_pid == pid
        begin
          @process.exit_value
          return false
        rescue IllegalThreadStateException
          # Thrown if the process is still running
          return true
        end
      else
        super( pid )
      end
    end

    def process_pid
      if @process.getClass.getName != "java.lang.UNIXProcess"
        raise NotImplementedError, "pid is only supported by JRuby child processes on Unix"
      end

      # http://stackoverflow.com/questions/2950338/how-can-i-kill-a-linux-process-in-java-with-sigkill-process-destroy-does-sigter/2951193#2951193
      field = @process.getClass.getDeclaredField( "pid" )
      field.accessible = true
      field.get( @process )
    end

    def stop
      if @process
        @process.destroy()
      end
      File.delete( pid_file ) if File.exist?( pid_file )
      @status = :stopped
      true
    end

    # Java 7 is required for the inheritIO call
    def attempt_io_redirect( process_builder )
      return false unless process_builder

      jvm_version = System.getProperties[ "java.runtime.version" ]
      major, minor, _ = jvm_version.split( /\./ )
      if major.to_i >= 1 && minor.to_i >= 7
        process_builder.inheritIO()
        return true
      end
      return false
    end

  end
end
