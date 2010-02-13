#### General test setup: LOAD_PATH, logging, console output ####

ldir = File.join( File.dirname( __FILE__ ), "..", "lib" )
$LOAD_PATH.unshift( ldir ) unless $LOAD_PATH.include?( ldir )

def time_it( name )
  start = Time.now
  output = ARGV.include?( '-v' )
  $stdout.write( "Loading %10s..." % name ) if output
  yield
  puts "%6.3fs" % (Time.now - start) if output
end

time_it( "rubygems" ) do
  require 'rubygems'
end

time_it( "logback?" ) do
  begin
    require 'rjack-logback'
    RJack::Logback.config_console( :level => Logback::INFO, :stderr => true )
  rescue LoadError
    require 'slf4j/simple'
  end
end

time_it( "test/unit" ) do
  require 'minitest/unit'
  require 'minitest/autorun'

  # Make test output logging compatible: no partial lines.
  class TestOut
    def print( *a ); $stdout.puts( *a ); end
    def puts( *a );  $stdout.puts( *a ); end
  end
  MiniTest::Unit.output = TestOut.new

end
