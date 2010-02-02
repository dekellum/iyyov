#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived
#--
# Copyright (C) 2010 David Kellum
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

$LOAD_PATH.unshift File.join( File.dirname(__FILE__), "..", "lib" )

require 'rubygems'
require 'rjack-logback'

RJack::Logback.config_console( :level => Logback::INFO )

require 'iyyov'

require 'test/unit'

class TestDaemon < Test::Unit::TestCase
  include Iyyov

  def setup
    @log = RJack::SLF4J[ self.class ]
  end

  def test_init
    d = Daemon.new( "myname" ) do |h|
      h.base_dir = '/base/dir'
      h.instance = '33'
    end

    assert_equal( "/base/dir/myname-33", d.un( d.run_dir ) )
    assert_equal( "/base/dir/myname-33/myname.pid", d.pid_file )
    assert_equal( [ "/base/dir/myname-33/myname.log" ], d.logs )
  end

  def test_init_path
    d = Daemon.new( "hashdot-daemon" )
    assert File.executable?( d.init_path )
    @log.info d.init_path
  end

end
