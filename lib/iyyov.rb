
require 'iyyov/base'
require 'iyyov/context'
require 'iyyov/errors'

module Iyyov

  @context = nil

  def self.context
    #FIXME: @context ||= Context.new
    raise "FIXME: Bad state!!!" unless @context
    yield @context if block_given?
    @context
  end

  def self.load_root_files( files )
    old_context = @context
    @context = Context.new
    yield @context if block_given?
    all_success = true
    files.each { |cfile| all_success &&= @context.load_file( cfile, true ) }

    if old_context
      if all_success
        old_context.daemons.each do |name,odaemon|
          ndaemon = @context.daemons[name]
          odaemon.stop unless ndaemon && ndaemon.exec_key == odaemon.exec_key
        end
      else
        @context = old_context
      end
    end

    #FIXME: @context.@state?

    all_success
  end

  def self.run
    continue = true
    while( continue && @context )
      rc = @context.event_loop
      continue = ( rc == :shutdown )
    end
  end

end
