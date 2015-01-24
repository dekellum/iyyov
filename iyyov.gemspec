# -*- ruby -*- encoding: utf-8 -*-

gem 'rjack-tarpit', '~> 2.1'
require 'rjack-tarpit/spec'

RJack::TarPit.specify do |s|
  require 'iyyov/base'

  s.version = Iyyov::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'rjack-slf4j',           '>= 1.6.5', '< 1.8'
  s.depend 'rjack-logback',         '~> 1.2'
  s.depend 'logrotate',             '=  1.2.1'

  s.depend 'minitest',              '~> 4.7.4',     :dev
  s.depend 'rdoc',                  '~> 4.0.1',     :dev
  s.depend 'hashdot-test-daemon',   '~> 1.2',       :dev

  s.platform = :java

end
