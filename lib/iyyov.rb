#--
# Copyright (c) 2010-2015 David Kellum
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

require 'iyyov/base'
require 'iyyov/context'

module Iyyov

  # Load configuration root_files and run the event loop, not
  # returning. Yields new Context to optional block for extra
  # configuration to be applied before any root_files are loaded.
  def self.run( root_files, &block )
    @extra_config_block = block
    load_root_files( root_files )

    continue = true
    while( continue && @context )
      rc = @context.event_loop
      continue = ( rc == :shutdown )
    end
  end

  # Yields current context to block. Called from configuration
  # scripts.
  def self.context
    raise "Iyyov.context called before run" unless @context
    yield @context if block_given?
    @context
  end

  def self.set_test_context
    @context = Context.new
  end

  # Load root configuration files.
  def self.load_root_files( files )
    old_context = @context
    @context = Context.new

    @extra_config_block.call( @context ) if @extra_config_block

    all_success = true
    files.each { |cfile| all_success &&= @context.load_file( cfile, true ) }

    if old_context
      if all_success
        # Stop old daemons that are either:
        # - no longer in the newly configured context, OR:
        # - with exec_key changed AND a passing pre_check
        old_context.daemons.each do |name,odaemon|
          ndaemon = @context.daemons[name]
          if ( ndaemon.nil? ||
               ( ndaemon.pre_check &&
                 ( ndaemon.exec_key != odaemon.exec_key ) ) )
            odaemon.stop
          end
        end
      else
        @context = old_context
      end
    end

    all_success
  end

  #Class Instance Variables

  #Presently active context
  @context = nil

  #Optional extra configuration block
  @extra_config_block = nil

end
