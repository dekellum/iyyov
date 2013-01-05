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

require 'childprocess'

module Iyyov
  include RJack

  # Support external processes that run in the foreground as daemons (daemonized
  # with help from Iyyov).
  class ForegroundProcess < Daemon

    # Start the daemon process
    def exec_command( command, args )
      @process = ChildProcess.build( command, *args )

      # Stdout/Stderr redirection to the log file
      stream = File.open( default_log, 'a' )
      @process.io.stdout = @process.io.stderr = stream

      @process.detach
      @process.start

      # Write pid file
      File.open( pid_file, 'w' ) {|f| f.write( @process.pid ) }
    end

    def alive?( pid = pid )
      if @process && @process.pid == pid
        @process.alive?
      else
        super( pid )
      end
    end

    def stop
      @process.stop
      File.delete( pid_file )
      @status = :stopped
      true
    end

  end
end
