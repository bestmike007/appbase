require File.expand_path('../lib/appbase/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'appbase'
  s.version     = AppBase::VERSION
  s.summary     = "Lightweight appbase"
  s.description = "A lightweight backend for Web/iOS/Android apps."
  s.authors     = ["bestmike007"]
  s.email       = 'i@bestmike007.com'
  s.homepage    = 'http://bestmike007.com/appbase'
  s.license     = 'MIT'
  s.files       = Dir['lib/**/*'] + ['LICENSE', 'README.md', 'appbase.gemspec']
  
  s.required_ruby_version = '>= 1.9.0'
  s.add_runtime_dependency 'rails', '>= 4.0', '< 4.2'
  s.add_development_dependency "rspec-rails", "~> 3.1", '>= 3.1.0'
end