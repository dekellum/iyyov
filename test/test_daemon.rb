#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived
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

require File.join( File.dirname( __FILE__ ), "setup" )

require 'iyyov'
require 'fileutils'

class TestDaemon < MiniTest::Unit::TestCase
  include Iyyov
  import java.lang.System

  def setup
    @log = RJack::SLF4J[ self.class ]
    @tdir = File.dirname( __FILE__ )
    @context = Context.new do |c|
      c.base_dir = @tdir
    end
  end

  def teardown
    @context.event_loop #Confirm return
    @context.shutdown
    %w[ hashdot-test-daemon hashdot-noexist ].each do |rdir|
      FileUtils.rm_rf( File.join( @tdir, rdir ) )
    end
  end

  def test_init
    d = Daemon.new( @context ) do |h|
      h.name     = "myname"
      h.instance = '33'
    end

    assert_equal( "myname",                            d.gem_name )
    assert_equal( "#{@tdir}/myname-33",                d.run_dir )
    assert_equal( "#{@tdir}/myname-33/myname.pid",     d.pid_file )
  end

  def test_exe_path
    d = Daemon.new( @context ) { |h| h.name = "hashdot-test-daemon" }
    assert File.executable?( d.exe_path )
    assert_match( /init\/hashdot-test-daemon$/, d.exe_path )
    @log.info d.exe_path
  end

  def test_invalid_init_name
    d = Daemon.new( @context ) do |h|
      h.name = "hashdot-test-daemon"
      h.init_name = "no-exist"
    end
    assert_equal( :stop, d.do_first( nil ) )
  end

  def test_invalid_run_dir
    d = Daemon.new( @context ) do |h|
      h.name = "hashdot-test-daemon"
      h.run_dir = "/no-permission"
    end
    assert_equal( :stop, d.do_first( nil ) )
  end

  def test_invalid_gem_name
    d = Daemon.new( @context ) { |h| h.name = "hashdot-noexist" }
    assert_equal( :stop, d.do_first( nil ) )
 end

  def test_invalid_gem_version
    d = Daemon.new( @context ) do |h|
      h.name = "hashdot-test-daemon"
      h.version = "= 6.6.6"
    end
    assert_equal( :stop, d.do_first( nil ) )
  end

  def test_exe_path_setter
    d = Daemon.new( @context ) do |h|
      h.name = 'foo'
      h.exe_path = "/tmp/foo"
    end
    assert_equal( '/tmp/foo', d.exe_path )
  end

  def test_foreground_process
    d = ForegroundProcess.new( @context ) do |h|
      h.name = 'sleep'
      h.run_dir = @tdir
      h.exe_path = '/bin/bash'
      h.args = [ '-c', 'sleep 600' ]
    end

    # If this hangs then +foreground+ is broken.
    d.start

    assert( d.alive? )
    assert( File.exist?( d.pid_file ),
            "Foreground process should create a pid file at #{d.pid_file}" )
    assert_equal( :up, d.start_check )

    d.stop

    assert( !d.alive? )
    assert( !File.exist?( d.pid_file ),
            "Stopped process should cleanup pid file" )
  ensure
    pid_file = File.join( @tdir, 'sleep.pid' )
    File.delete( pid_file ) if File.exist?( pid_file )
    File.delete( d.default_log ) if File.exist?( d.default_log )
  end

  def test_foreground_process_restart
    d = ForegroundProcess.new( @context ) do |h|
      h.name = 'echo'
      h.run_dir = @tdir
      h.exe_path = '/bin/bash'
      h.args = [ '-c', 'echo foo' ]
    end

    d.start_check
    assert_equal( :up, d.state )
    # Says alive, but dead until the next check.
    assert_equal( false, d.alive? )
  ensure
    pid_file = File.join( @tdir, 'echo.pid' )
    File.delete( pid_file ) if File.exist?( pid_file )
    File.delete( d.default_log ) if File.exist?( d.default_log )
  end

  def test_foreground_process_inherit_io
    jvm_version = System.getProperties["java.runtime.version"]
    major, minor, other = jvm_version.split(/\./)
    if major.to_i >= 1 && minor.to_i >= 7
      # Java 7, test IO redirect
      @daemon = ForegroundProcess.new( @context ) do |h|
        h.name = 'echo'
        h.run_dir = @tdir
        h.exe_path = '/bin/bash'
        h.args = [ '-c', 'echo foo' ]
      end

      $called = false
      def @daemon.attempt_io_redirect( builder )
        $called = true
      end

      @daemon.start
      assert( $called, "Should have called attempt_io_redirect on start" )
      @daemon.stop
    else
      skip("Java 7 required to test forground process redirect")
    end

  ensure
    @daemon.stop if @daemon
    pid_file = File.join( @tdir, 'echo.pid' )
    File.delete( pid_file ) if File.exist?( pid_file )
  end

end
