#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived
#--
# Copyright (c) 2010-2016 David Kellum
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

require 'iyyov/scheduler'
require 'iyyov/task'

class TestScheduler < MiniTest::Unit::TestCase
  include Iyyov

  def test_run
    counter = 0
    s = Scheduler.new
    tk = Task.new( :name => "test_run", :period => 0.001 ) do
      counter += 1
      assert( counter <= 2 )
      :stop unless counter < 2
    end
    s.add( tk )
    s.event_loop
  end

  def test_fixed_times
    tk = Task.new( :fixed_times => %w[ 6:00 8:00 10:00 12:00 ] )

    assert_next_time_from( tk, '2010-02-08T08:00', '2010-02-08T10:00' )

    assert_next_time_from( tk, '2010-02-08T12:00', '2010-02-09T06:00' )

    tk.fixed_days = 3..6
    assert_next_time_from( tk, '2010-02-08T08:00', '2010-02-10T06:00' )
  end

  def assert_next_time_from( tk, now, expected )
    2.times do
      assert_equal( tp( expected ), tk.next_fixed_time( tp( now ) ) )
      tk.fixed_times = tk.fixed_times.reverse
    end
  end

  def test_shutdown
    s = Scheduler.new
    s.on_exit { flunk "Shouldn't make it here" }
    counter = 0
    tk = Task.new( :name => "test_shutdown", :period => 0.001 ) do |t|
      counter += 1
      assert( counter <= 2 )
      unless counter < 2
        t.log.info "Shutting it down now"
        :shutdown
      end
    end
    s.add( tk )
    s.add( Task.new( :period => 5.0 ) { flunk "nor here" } )
    assert_equal( :shutdown, s.event_loop )
  end

  def tp( t )
    Time.parse( t )
  end

end
