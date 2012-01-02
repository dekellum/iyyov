# -*- ruby -*- encoding: utf-8 -*-

gem 'rjack-tarpit', '~> 2.0.a'
require 'rjack-tarpit/spec'

$LOAD_PATH.unshift( File.join( File.dirname( __FILE__ ), 'lib' ) )

require 'iyyov/base'

RJack::TarPit.specify do |s|

  s.version  = Iyyov::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'rjack-slf4j',           '~> 1.6.1'
  s.depend 'rjack-logback',         '~> 1.1'
  s.depend 'logrotate',             '=  1.2.1'

  s.depend 'minitest',              '~> 2.2',       :dev
  s.depend 'hashdot-test-daemon',   '~> 1.2',       :dev

  s.platform = :java

end
