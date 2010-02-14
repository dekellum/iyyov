require 'logrotate'

module Iyyov
  include RJack

  # Support check for size and rotation of a log file.
  class LogRotator

    # Full path to log file to check and rotate
    # <String>:: path (required)
    attr_accessor :log

    # Maximum log size triggering rotation
    # <Fixnum>:: bytes (default: 256M bytes)
    attr_accessor :max_size

    # Number of rotated logs in addition to active log.
    # <Fixnum>:: rotations (default: 3)
    attr_accessor :count

    # GZIP compress rotated logs?
    # <Boolean>:: (default: true)
    attr_accessor :gzip

    # The signal to use post rotation (but before gzip) requesting
    # that the daemon reopen its logs.
    # <String>:: (default: "HUP")
    attr_accessor :signal

    # Period between subsequent checks for rotation (default: 300.0)
    # <Float>:: seconds
    attr_accessor :check_period

    # Process ID to signal (if known in advance/constant, i.e. 0 for
    # this process)
    attr_writer :pid

    # mb<Fixnum>:: Set max_size in megabytes
    def max_size_mb=( mb )
      @max_size = mb * 1024 * 1024
    end

    def initialize( log = nil )
      @log = log
      max_size_mb = 256
      @count = 3
      @gzip = true
      @signal = "HUP"
      @check_period = 5 * 60.0
      @pid = nil

      yield self if block_given?

      #FIXME: Validate log directory?
      nil
    end

    # Check if log is over size and rotate if needed. Yield log name
    # to block just before rotating
    def check_rotate( pid = @pid )
      if File.exist?( log ) && File.size( log ) > max_size
        yield log if block_given?
        opts  = { :count => count, :gzip => gzip }
        if signal && pid
          opts[ :post_rotate ] = lambda { Process.kill( signal, pid ) }
        end
        LogRotate.rotate_file( log, opts )
      end
      nil
    end

  end
end
