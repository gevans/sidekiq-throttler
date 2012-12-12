# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq/throttler/version'

Gem::Specification.new do |gem|
  gem.name          = 'sidekiq-throttler'
  gem.version       = Sidekiq::Throttler::VERSION
  gem.authors       = ['Gabriel Evans']
  gem.email         = ['gabriel@codeconcoction.com']
  gem.description   = %q{Sidekiq middleware that adds the ability to rate limit job execution.}
  gem.summary       = %q{Sidekiq::Throttler is a middleware for Sidekiq that adds the ability to rate limit job execution on a per-worker basis.}
  gem.homepage      = 'https://github.com/gevans/sidekiq-throttler'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'sidekiq', '>= 2.5', '< 3.0'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'redcarpet'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'simplecov'

  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-bundler'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'guard-yard'
  gem.add_development_dependency 'rb-fsevent'
  gem.add_development_dependency 'rb-inotify'
  gem.add_development_dependency 'growl'
end