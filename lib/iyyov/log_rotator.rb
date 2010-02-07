require 'logrotate'

module Iyyov
  include RJack

  class LogRotator
    attr_accessor :max_size
    attr_accessor :count
    attr_accessor :gzip
    attr_accessor :signal
    attr_accessor :check_period

    # Set max_size in megabytes
    def max_size_mb=( mb )
      @max_size = mb * 1024 * 1024
    end

    def initialize
      @max_size = 512 * 1024 * 1024
      @count = 3
      @gzip = true
      @signal = "HUP"
      @check_period = 5 * 60.0
    end

    # Check if log is over size and rotate if needed. Yield log name
    # to block just before rotating
    def check_rotate( log, pid )
      if File.exist?( log ) && File.size( log ) > max_size
        yield log if block_given?
        opts  = { :count => count, :gzip => gzip }
        if signal && pid
          opts[ :post_rotate ] = lambda { Process.kill( signal, pid ) }
        end
        LogRotate.rotate_file( log, opts )
      end
    end

  end
end
