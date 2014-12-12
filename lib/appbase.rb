$:.unshift(File.dirname(__FILE__))

if defined?(Rails::Railtie)
  module AppBase
    require_relative 'appbase/railtie'
  end
end
