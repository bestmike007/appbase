require 'rails'
require_relative "helpers"
require_relative "registry"
require_relative "model_concern"
require_relative "controllers/app_base_controller"

module AppBase
  
  class Engine < Rails::Engine
    
    paths["app/controllers"] = "lib/appbase/controllers"
    
    class << self
      
      initialized = false
      config = nil
      hooks = []
      
      initialize_user_identity = lambda {
        if config.user_identity.nil?
          raise "AppBase configuration error: please use `config.appbase.user_identity = :UserIdentity` to specify the user identity model; and implement UserIdentity.authenticate_by_token(user, token):UserIdentity method."
        end
        user_identity = Object.const_get config.user_identity.to_sym
        if !user_identity.respond_to?(:authenticate_by_token) || user_identity.method(:authenticate_by_token).parameters.count != 2
          raise "It's required to implement UserIdentity.authenticate_by_token(user, token):UserIdentity method."
        end
        AppBase::Engine::UserIdentity = config.user_identity.to_s
        AppBaseController.define_useridentity config.user_identity, config.token_store, config.token_key_user, config.token_key_session
      }
      
      initialize_crud_stubs = lambda {
        AppBase::Registry.each_crud config.models do |model, op|
          http_methods = { create: :put, update: :put, delete: :delete, query: :get}
          if !http_methods.has_key?(op)
            raise "Unexpected crud operation: #{op}"
          end
          
          model_name_underscore = model.name.underscore
          http_path = "/#{model_name_underscore}"
          http_path += "/:id" if op == :update || op == :delete
          
          AppBaseController.send "add_#{op}_stub", model
          AppBase::Engine.routes.append do
            match http_path, to: "app_base##{op}_#{model_name_underscore}", via: http_methods[op]
          end
        end
      }
      
      initialize_rpc_stubs = lambda {
        AppBase::Registry.each_rpc do |r|
          if !r[:model].respond_to? r[:method]
            raise "#{r[:model].name} does not respond to #{r[:method]}."
          end
          bound_method = r[:model].method r[:method]
          AppBaseController.add_rpc_method_stub(bound_method, r[:auth])
          AppBase::Engine.routes.append do
            post "/#{r[:model].name.underscore}/#{r[:method]}" => "app_base#rpc_#{r[:model].name.underscore}_#{r[:method]}"
          end
        end
      }
      
      define_method :bootstrap do |app_config|
        return if initialized
        config = app_config.appbase
        
        initialize_user_identity.call
        
        initialize_crud_stubs.call
        
        initialize_rpc_stubs.call
        
        # finalize appbase routes
        AppBase::Engine.routes.draw do
          get "/appbase_version" => "app_base#version"
        end
        
        # after initialized
        blocks, hooks = hooks, []
        blocks.each do |block|
          block.call
        end
        initialized = true
        
      end
      
      define_method :after_initialized do |&block|
        if initialized
          block.call
        else
          hooks << block
        end
      end
      
      define_method :config do
        config
      end
      
    end
    
  end

  class Railtie < Rails::Railtie

    # default values for appbase configuration
    config.appbase = ActiveSupport::OrderedOptions.new
    config.appbase.enabled = false
    config.appbase.mount = "/appbase"
    config.appbase.user_identity = nil
    config.appbase.token_store = :cookies # :cookies, :headers, :params
    config.appbase.token_key_user = :u
    config.appbase.token_key_session = :s
    config.appbase.models = []
    
    initializer "appbase.configure_route", :after => :add_routing_paths do |app|
      
      if File.basename(ENV['_']) == 'rake'
        puts "Running with `rake #{$*.join(' ')}`"
      end
      
      if config.appbase.enabled && (File.basename(ENV['_']) != 'rake' || $*[0] == 'routes')
        AppBase::Engine.bootstrap app.config
        
        app.routes.append do
          mount AppBase::Engine => Rails.application.config.appbase.mount
        end
      end
      
    end
    
  end

end
