#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived
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

require File.join( File.dirname( __FILE__ ), "setup" )

require 'iyyov'
require 'fileutils'

class TestDaemon < MiniTest::Unit::TestCase
  include Iyyov

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

end
