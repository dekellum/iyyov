# -*- ruby -*-

$LOAD_PATH << './lib'

require 'rubygems'
gem     'rjack-tarpit', '~> 1.3.0'
require 'rjack-tarpit'

require 'iyyov/base'

t = RJack::TarPit.new( 'iyyov', Iyyov::VERSION, :java_platform )

t.specify do |h|
  h.developer( 'David Kellum', 'dek-oss@gravitext.com' )
  h.testlib = :minitest
  h.extra_deps     += [ [ 'rjack-slf4j',         '~> 1.6.1' ],
                        [ 'rjack-logback',       '~> 1.1.1' ],
                        [ 'logrotate',           '=  1.2.1' ] ]
  h.extra_dev_deps += [ [ 'minitest',            '>= 1.5.0', '< 2.1' ],
                        [ 'hashdot-test-daemon', '~> 1.2'   ] ]
end

# Version/date consistency checks:

task :chk_init_v do
  t.test_line_match( 'init/iyyov',
                      /^gem.+#{t.name}/, /= #{t.version}/ )
end
task :chk_rcd_v do
  t.test_line_match( 'config/init.d/iyyov', /^version=".+"/, /"#{t.version}"/ )
end
task :chk_cron_v do
  t.test_line_match( 'config/crontab', /gems\/iyyov/,
                     /iyyov-#{t.version}-java/ )
end
task :chk_hist_v do
  t.test_line_match( 'History.rdoc', /^==/, / #{t.version} / )
end

gem_tests = [ :chk_init_v, :chk_rcd_v, :chk_cron_v, :chk_hist_v  ]

task :chk_hist_date do
  t.test_line_match( 'History.rdoc', /^==/, /\([0-9\-]+\)$/ )
end

task :gem  => gem_tests
task :tag  => gem_tests + [ :chk_hist_date ]
task :push => [ :chk_hist_date ]

t.define_tasks
