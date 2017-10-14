#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived
#--
# Copyright (c) 2010-2017 David Kellum
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

TESTDIR = File.dirname( __FILE__ )

require File.join( TESTDIR, "setup" )

require 'iyyov'

class TestContext < MiniTest::Unit::TestCase
  def setup
    Iyyov.set_test_context
  end

  def teardown
    Iyyov.context.shutdown
  end

  def test_load_ruby_error
    Iyyov.context do |c|
      c.load_file( File.join( TESTDIR, "jobs-bad.rb" ) )
      pass
    end
    pass
  end

  def test_load_dupe_error
    Iyyov.context do |c|
      c.load_file( File.join( TESTDIR, "jobs-dupe.rb" ) )
      pass
    end
    pass
  end

  def test_load_samples
    Dir[ File.join( TESTDIR, '..', 'config', '*.rb' ) ].each do |conf|
      Iyyov.context { |c| c.load_file( conf ) }
      Iyyov.context.shutdown
      Iyyov.set_test_context
      pass
    end
  end

end
