
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

  # Load root configuration files.
  def self.load_root_files( files )
    old_context = @context
    @context = Context.new

    @extra_config_block.call( @context ) if @extra_config_block

    all_success = true
    files.each { |cfile| all_success &&= @context.load_file( cfile, true ) }

    if old_context
      if all_success
        # Stop old daemons that are no longer in the newly configured
        # context, or who's exec_key has changed
        old_context.daemons.each do |name,odaemon|
          ndaemon = @context.daemons[name]
          odaemon.stop unless ndaemon && ndaemon.exec_key == odaemon.exec_key
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
