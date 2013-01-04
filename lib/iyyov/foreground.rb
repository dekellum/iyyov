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
  class ForegroundDaemon

    def initialize( daemon, exe_path, exe_args )
      @daemon = daemon
      @exe_path = exe_path
      @exe_args = exe_args
    end

    # Start the daemon process
    def start
      process_args = ([ @exe_path ] + @exe_args).flatten.map(&:to_s)

      @process = ChildProcess.build(*process_args)
      @process.detach
      @process.start

      # Write pid file
      File.open(@daemon.pid_file, 'w') {|f| f.write(@process.pid) }

      @daemon.instance_variable_set(:@process, @process)
      def @daemon.stop
        @process.stop
        File.delete( pid_file )
      end
    end

  end
end
