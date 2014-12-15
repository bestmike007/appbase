require 'rails'
require_relative "model_concern"
require_relative "controllers/app_base_controller"

class String
  
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
  
end

module AppBase
  
  class Engine < Rails::Engine
    
    paths["app/controllers"] = "lib/appbase/controllers"
    
  end

  class Railtie < Rails::Railtie

    # default values for appbase configuration
    config.appbase = ActiveSupport::OrderedOptions.new
    config.appbase.mount = "/appbase"
    config.appbase.user_identity = nil
    config.appbase.token_store = :cookies # :cookies, :headers, :params
    config.appbase.token_key_user = :u
    config.appbase.token_key_session = :s
    config.appbase.models = []
    
    initializer "appbase.configure_route", :after => :add_routing_paths do |app|
      # set up user identity model
      if app.config.appbase.user_identity.nil?
        raise "AppBase configuration error: please use `config.appbase.user_identity = :UserIdentity` to specify the user identity model; and implement UserIdentity.authenticate_by_token(user, token):UserIdentity method."
      end
      user_identity = Object.const_get app.config.appbase.user_identity.to_sym
      if !user_identity.respond_to?(:authenticate_by_token) || user_identity.method(:authenticate_by_token).parameters.count != 2
        raise "It's required to implement UserIdentity.authenticate_by_token(user, token):UserIdentity method."
      end
      user_identity.crud = ''
      # common methods
      ab_extend = %-
        def current_user(options={})
          if #{app.config.appbase.token_store}[:#{app.config.appbase.token_key_user}].nil? || #{app.config.appbase.token_store}[:#{app.config.appbase.token_key_session}].nil?
            return options[:default] if options.has_key? :default
            raise "unauthenticated"
          end
          #{app.config.appbase.user_identity}.authenticate_by_token(#{app.config.appbase.token_store}[:#{app.config.appbase.token_key_user}], #{app.config.appbase.token_store}[:#{app.config.appbase.token_key_session}])
        end
      -
      # per model method stubs
      app.config.appbase.models.each { |m|
        model = Object.const_get m.to_sym
        # add crud methods
        crud = model.crud || ''
        if !crud.index('c').nil?
          if model.respond_to?(:can_create?)
            if model.method(:can_create?).parameters.count != 2
              raise "#{m}.can_create?(user, obj) method is not properly defined."
            end
          else
            if model.columns.find{|c|c.name == "#{app.config.appbase.user_identity.to_s.underscore}_id"}.nil?
              raise "#{m}.can_create?(user, obj) method is not defined and #{m} does not belong to #{app.config.appbase.user_identity} either."
            end
            model.module_eval %-
              def self.can_create?(user, obj)
                user.id == obj.#{m.to_s.underscore}_id
              end
            -
          end
          ab_extend += %-
            def create_#{m.to_s.underscore}
              permits = #{m}.columns.map { |item| item.name }
              obj = #{m}.new(params.except(:action, :controller, :id).permit(permits))
              if !#{m}.can_create?(current_user, obj)
                render json: { status: "error", msg: "unauthorized" }
              else
                obj.save
                render json: { status: 'ok' }
              end
            rescue Exception => e
              render json: { status: 'error', msg: e.to_s }
            end
          -
          AppBase::Engine.routes.append do
            put "/#{m.to_s.underscore}" => "app_base#create_#{m.to_s.underscore}"
          end
        end # create stub
        
        if !crud.index('u').nil?
          if model.respond_to?(:can_update?)
            if model.method(:can_update?).parameters.count != 2
              raise "#{m}.can_update?(user, obj) method is not properly defined."
            end
          else
            if model.columns.find{|c|c.name == "#{app.config.appbase.user_identity.to_s.underscore}_id"}.nil?
              raise "#{m}.can_update?(user, obj) method is not defined and #{m} does not belong to #{app.config.appbase.user_identity} either."
            end
            model.module_eval %-
              def self.can_update?(user, obj)
                user.id == obj.#{m.to_s.underscore}_id && !obj.#{m.to_s.underscore}_id_changed?
              end
            -
          end
          ab_extend += %-
            def update_#{m.to_s.underscore}
              permits = #{m}.columns.map { |item| item.name }
              obj = #{m}.find(params[:id])
              if obj.nil?
                return render json: { status: 'error', msg: 'not_found' }
              end
              obj.update_attributes(params.except(:action, :controller, :id).permit(permits))
              if !#{m}.can_update?(current_user, obj)
                render json: { status: "error", msg: "unauthorized" }
              else
                obj.save
                render json: { status: 'ok' }
              end
            rescue Exception => e
              render json: { status: 'error', msg: e.to_s }
            end
          -
          AppBase::Engine.routes.append do
            put "/#{m.to_s.underscore}/:id" => "app_base#update_#{m.to_s.underscore}"
          end
        end # update stub
        
        if !crud.index('d').nil?
          if model.respond_to?(:can_delete?)
            if model.method(:can_delete?).parameters.count != 2
              raise "#{m}.can_delete?(user, obj) method is not properly defined."
            end
          else
            if model.columns.find{|c|c.name == "#{app.config.appbase.user_identity.to_s.underscore}_id"}.nil?
              raise "#{m}.can_delete?(user, obj) method is not defined and #{m} does not belong to #{app.config.appbase.user_identity} either."
            end
            model.module_eval %-
              def self.can_delete?(user, obj)
                user.id == obj.#{m.to_s.underscore}_id && !obj.#{m.to_s.underscore}_id_changed?
              end
            -
          end
          ab_extend += %-
            def delete_#{m.to_s.underscore}
              obj = #{m}.find(params[:id])
              if obj.nil?
                return render json: { status: 'error', msg: 'not_found' }
              end
              if !#{m}.can_delete?(current_user, obj)
                render json: { status: "error", msg: "unauthorized" }
              else
                obj.delete
                render json: { status: 'ok' }
              end
            rescue Exception => e
              render json: { status: 'error', msg: e.to_s }
            end
          -
          AppBase::Engine.routes.append do
            delete "/#{m.to_s.underscore}/:id" => "app_base#delete_#{m.to_s.underscore}"
          end
        end # delete stub
        
        if !crud.index('r').nil?
          if model.respond_to?(:access_by)
            if model.method(:access_by).parameters.count != 1
              raise "#{m}.access_by(user) method is not properly defined."
            end
          else
            if model.columns.find{|c|c.name == "#{app.config.appbase.user_identity.to_s.underscore}_id"}.nil?
              raise "#{m}.access_by(user) method is not defined and #{m} does not belong to #{app.config.appbase.user_identity} either."
            end
            model.module_eval %-
              def self.access_by(user)
                #{m}.where("#{app.config.appbase.user_identity.to_s.underscore}_id = ?", user.id)
              end
            -
          end
          columns = model.columns.map{|c|c.name}
          ab_extend += %-
            def query_#{m.to_s.underscore}
              query = #{m}.access_by(current_user)
              columns = #{columns.to_json}
              params.except(:action, :controller, :p, :ps).each { |k, v|
                op = 'eq'
                if k.index('.') && k.split('.').count == 2
                  k, op = k.split('.')
                end
                return if columns.index(k).nil?
                case op
                when 'eq'
                  query = query.where "\#{k} = ?", v
                when 'lt'
                  query = query.where "\#{k} < ?", v
                when 'le'
                  query = query.where "\#{k} <= ?", v
                when 'gt'
                  query = query.where "\#{k} > ?", v
                when 'ge'
                  query = query.where "\#{k} >= ?", v
                when 'n'
                  query = query.where "\#{k} IS NULL"
                when 'nn'
                  query = query.where "\#{k} IS NOT NULL"
                when 'in'
                  values = JSON.parse v
                  query = query.where "\#{k} IN (?)", values
                when 'nin'
                  values = JSON.parse v
                  query = query.where "\#{k} NOT IN (?)", values
                else
                end
              }
              page_size = [1, (params[:ps]||20).to_i].max
              start = [0, (params[:p]||1).to_i.pred].max * page_size
              render json: { status: 'ok', data: query.offset(start).limit(page_size) }
            rescue Exception => e
              render json: { status: 'error', msg: e.to_s }
            end
          -
          AppBase::Engine.routes.append do
            get "/#{m.to_s.underscore}" => "app_base#query_#{m.to_s.underscore}"
          end
        end # query stub
        
        # add appbase model methods stubs
        model.appbase_methods.each do |mn|
          if !model.respond_to? mn.to_sym
            raise "#{m} does not respond to #{mn}."
          end
          ab_method = model.method mn.to_sym
          parameters = ab_method.parameters
          if parameters.count == 0 || parameters[0][0] != :req
            raise "#{m}.#{mn} does not accept current user identity as the first parameter. Using `before_authenticate :method_name` to expose #{m}#{mn} to appbase without user authentication."
          end
          need_params = false
          if parameters.last[0] == :opt
            need_params = true
            parameters = parameters[1..-2]
          else
            parameters = parameters[1..-1]
          end
          if parameters.find{|p|p[0]!=:req}
            raise "Error exposing #{m}.#{mn} to appbase engine, appbase does not support rest/optional parameters, use options instead!"
          end
          requires = parameters.map{|p|":#{p[1]}"}
          parameters = ['current_user']
          requires.each { |p| parameters << "params[#{p}]" }
          if need_params
            parameters.push "params.except(:action, :controller#{requires.count > 0 ? ", #{requires.join(', ')}" : ""})"
          end
          ab_extend += %-
            def rpc_#{m.to_s.underscore}_#{mn}
              #{requires.map{|p|"params.require #{p}"}.join(';')}
              render json: { status: 'ok', data: #{m}.#{mn}(#{parameters.join(', ')}) }
            rescue Exception => e
              render json: { status: 'error', msg: e.to_s }
            end
          -
          AppBase::Engine.routes.append do
            post "/#{m.to_s.underscore}/#{mn}" => "app_base#rpc_#{m.to_s.underscore}_#{mn}"
          end
        end
        # add appbase model methods stubs before authentication
        model.appbase_methods_without_authentication.each do |mn|
          if !model.respond_to? mn.to_sym
            raise "#{m} does not respond to #{mn}."
          end
          ab_method = model.method mn.to_sym
          parameters = ab_method.parameters
          need_params = false
          if parameters.last[0] == :opt
            need_params = true
            parameters = parameters[0..-2]
          else
            parameters = parameters[0..-1]
          end
          if parameters.find{|p|p[0]!=:req}
            raise "Error exposing #{m}.#{mn} to appbase engine, appbase does not support rest/optional parameters. To expose method with optional parameters, use options parameter (e.g def m1(p1, p2, options={}) ) instead."
          end
          requires = parameters.map{|p|":#{p[1]}"}
          parameters = []
          requires.each { |p| parameters << "params[#{p}]" }
          if need_params
            parameters.push "params.except(:action, :controller#{requires.count > 0 ? ", #{requires.join(', ')}" : ""})"
          end
          ab_extend += %-
            def rpc_#{m.to_s.underscore}_#{mn}
              #{requires.map{|p|"params.require #{p}"}.join(';')}
              render json: { status: 'ok', data: #{m}.#{mn}(#{parameters.join(', ')}) }
            rescue Exception => e
              render json: { status: 'error', msg: e.to_s }
            end
          -
          AppBase::Engine.routes.append do
            post "/#{m.to_s.underscore}/#{mn}" => "app_base#rpc_#{m.to_s.underscore}_#{mn}"
          end
        end
        
      }
      AppBaseController.module_eval ab_extend
      
      AppBase::Engine.routes.draw do
        get "/appbase_version" => "app_base#version"
      end
      
      app.routes.append do
        mount AppBase::Engine => Rails.application.config.appbase.mount
      end
    end
    
  end

end
