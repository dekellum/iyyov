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

class TestForegroundProcess < MiniTest::Unit::TestCase
  include Iyyov

  MockProcessBuilder = Struct.new( :called )

  def setup
    @tdir = File.dirname( __FILE__ )
    @context = Context.new do |c|
      c.base_dir = @tdir
    end
    @process = ForegroundProcess.new( @context ) do |d|
      d.name = 'test name'
    end
    @mock = MockProcessBuilder.new( false )
    def @mock.inheritIO
      self.called = true
    end
  end

  def teardown
    @context.event_loop #Confirm return
    @context.shutdown
  end

  def test_attempt_io_redirect__nil_args
    assert( !@process.attempt_io_redirect( nil ),
            "Missing process builder should return false" )
    assert( !@process.attempt_io_redirect( @mock, nil ),
            "Missing jvm version should return false" )
  end

  def test_attempt_io_redirect_old_jvm
    [ 1.0, 1.1, 1.4, 1.5, 1.6 ].each do |version|
      assert( !@process.attempt_io_redirect( @mock, version ),
              "#{version} should return false" )
      assert( !@mock.called, "Should not have called inheritIO" )
    end
  end

  def test_attempt_io_redirect_new_jvm
    [ 1.7, 1.8 ].each do |version|
      assert( @process.attempt_io_redirect( @mock, version ),
              "#{version} should return true" )
      assert( @mock.called, "Should have called inheritIO" )
    end
  end
end
