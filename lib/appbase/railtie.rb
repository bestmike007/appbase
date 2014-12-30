require 'rails'
require_relative "registry"
require_relative "model_concern"
require_relative "controllers/app_base_controller"

module AppBase
  
  class Engine < Rails::Engine
    
    paths["app/controllers"] = "lib/appbase/controllers"
    
    class << self
      
      class RpcMethodInitializer
        
        def initialize(config)
          @model = config[:model]
          @method = config[:method]
          @auth = config[:auth]
        end
        
        def init
          pre_init
          add_controller_stub
          add_route
        end
        
        private
        def pre_init
          model_name = @model.name
          if !@model.respond_to?(@method)
            raise "#{model_name} does not respond to #{@method}."
          end
        end
        
        def add_controller_stub
          bound_method = @model.method @method
          AppBaseController.add_rpc_method_stub(bound_method, @auth)
        end
        
        def add_route
          model_name_underscore = AppBase.underscore @model.name
          method_name = @method
          AppBase::Engine.routes.append do
            post "/#{model_name_underscore}/#{method_name}" => "app_base#rpc_#{model_name_underscore}_#{method_name}"
          end
        end
      end
      
      class CrudInitializer
        
        def initialize(model, op)
          @model = model
          @op = op
          @http_methods = { create: :post, update: :put, delete: :delete, query: :get }
        end
        
        def init
          pre_init
          add_controller_stub
          add_route
        end
        
        private
        def pre_init
          raise "Unexpected crud operation: #{@op}" if !@http_methods.has_key?(@op)
        end
        
        def add_controller_stub
          AppBaseController.send "add_#{@op}_stub".to_sym, @model
        end
        
        def add_route
          model_name_underscore = AppBase.underscore @model.name
          url_path = "/#{model_name_underscore}"
          url_path += "/:id" if @op == :update || @op == :delete
          http_method = @http_methods[@op]
          op = @op
          AppBase::Engine.routes.append do
            match url_path, to: "app_base##{op}_#{model_name_underscore}", via: http_method
          end
        end
        
      end
      
      class AppBaseEngineInitializer
        
        def initialize
          @initialized = false
          @hooks = []
        end
        
        def bootstrap(app_config)
          return if @initialized
          @config = app_config.appbase
          initialize_user_identity
          initialize_crud_stubs
          initialize_rpc_stubs
          finilize_routes
          post_initialize
          @initialized = true
        end
        
        def after_initialized(&block)
          if @initialized
            block.call
          else
            @hooks << block
          end
        end
        
        private
        
        def pre_init_user_identity
          if @config.user_identity.nil?
            raise "AppBase configuration error: please use `config.appbase.user_identity = :UserIdentity` to specify the user identity model; and implement UserIdentity.authenticate_by_token(user, token):UserIdentity method."
          end
          user_identity = Object.const_get @config.user_identity.to_sym
          if !user_identity.respond_to?(:authenticate_by_token) || user_identity.method(:authenticate_by_token).parameters.count != 2
            raise "It's required to implement UserIdentity.authenticate_by_token(user, token):UserIdentity method."
          end
        end
        
        def initialize_user_identity
          pre_init_user_identity
          AppBase::Engine.const_set :UserIdentity, @config.user_identity.to_s.extend(AppBase::StringExtension)
          AppBaseController.define_useridentity @config.user_identity, @config.token_store, @config.token_key_user, @config.token_key_session
        end
        
        def initialize_crud_stubs
          AppBase::Registry.each_crud @config.models do |model, op|
            CrudInitializer.new(model, op).init
          end
        end
        
        def initialize_rpc_stubs
          AppBase::Registry.each_rpc do |r|
            RpcMethodInitializer.new(r).init
          end
        end
        
        def finilize_routes
          AppBase::Engine.routes.draw do
            get "/appbase_version" => "app_base#version"
          end
        end
        
        def post_initialize
          blocks, @hooks = @hooks, []
          blocks.each do |block|
            block.call
          end
        end
      end
      
      def bootstrap(config)
        @initializer = AppBaseEngineInitializer.new if !@initializer
        @initializer.bootstrap(config)
      end
      
      def after_initialized(&block)
        @initializer = AppBaseEngineInitializer.new if !@initializer
        @initializer.after_initialized(&block)
      end
      
    end
    
  end

  class Railtie < Rails::Railtie
    
    class << self
      private
      def setup_default(config)
        return if config.respond_to? :appbase
        # default values for appbase configuration
        config.appbase = ActiveSupport::OrderedOptions.new
        config.appbase.enabled = false
        config.appbase.mount = "/appbase"
        config.appbase.user_identity = nil
        config.appbase.token_store = :cookies # :cookies, :headers, :params
        config.appbase.token_key_user = :u
        config.appbase.token_key_session = :s
        config.appbase.models = []
      end
    end

    def enabled
      basename = ENV['_'].nil? ? nil : File.basename(ENV['_'])
      if basename == 'rake'
        puts "Running with `rake #{$*.join(' ')}`"
      end
      config.appbase.enabled && (basename != 'rake' || $*[0] == 'routes')
    end
    
    setup_default config
    
    initializer "appbase.configure_route", :after => :add_routing_paths do |app|
      if enabled
        AppBase::Engine.bootstrap app.config
        app.routes.append do
          mount AppBase::Engine => Rails.application.config.appbase.mount
        end
      end
      
    end
    
  end

end
