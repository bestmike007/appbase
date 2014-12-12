require File.expand_path('../lib/appbase/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'appbase'
  s.version     = AppBase::VERSION
  s.summary     = "Lightweight appbase"
  s.description = "A lightweight backend for Web/iOS/Android apps."
  s.authors     = ["bestmike007"]
  s.email       = 'i@bestmike007.com'
  s.homepage    = 'http://bestmike007.com/appbase'
  s.license       = 'MIT'
  s.files = Dir['lib/**/*']
  s.test_files = Dir.glob("spec/**/*")
  
  s.add_runtime_dependency 'activesupport', '~> 4.0'
  s.add_development_dependency "rake", "~> 0.8.7"
  s.add_development_dependency "rspec", '~> 0'
  s.add_development_dependency "rack-test", '~> 0'
  s.add_development_dependency "rails", "~> 4.0"
end