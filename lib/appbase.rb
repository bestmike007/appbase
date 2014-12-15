$:.unshift(File.dirname(__FILE__))

require_relative 'appbase/railtie' if defined?(Rails::Railtie)