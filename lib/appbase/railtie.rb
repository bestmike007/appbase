require 'rails'

module AppBase

  class Railtie < Rails::Railtie

    config.appbase = ActiveSupport::OrderedOptions.new

  end

end
