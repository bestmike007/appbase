class AppBaseController < ActionController::Base
  
  def version
    render json: AppBase::VERSION
  end
  
  def current_user
    nil
  end
  
  class << self
    
    def define_useridentity(user_identity, token_store, token_key_user, token_key_session)
      self.class_eval %-
        def current_user(options={})
          if #{token_store}[:#{token_key_user}].nil? || #{token_store}[:#{token_key_session}].nil?
            return options[:default] if options.has_key? :default
            raise "unauthenticated"
          end
          user = #{user_identity}.authenticate_by_token(#{token_store}[:#{token_key_user}], #{token_store}[:#{token_key_session}])
          if user.nil?
            return options[:default] if options.has_key? :default
            raise "unauthenticated"
          end
          user
        end
      -
    end
    
    def permits(model, arg_str=false)
      if arg_str
        "[#{model.columns.map { |item| ":" + item.name }.join(", ")}]"
      else
        model.columns.map { |item| item.name.to_sym }
      end
    end
    
    def add_create_or_update_stub(op, model, prepare)
      m = model.name
      self.class_eval %-
        def #{op}_#{AppBase.underscore m}
          #{prepare}
          raise "unauthorized" if !#{m}.allow_#{op}?(current_user, obj)
          obj.save!
          rs = { status: 'ok' }
          #{ 'rs[:id] = obj.id' if op == :create }
          render json: rs
        rescue Exception => e
          render json: { status: 'error', msg: e.to_s }
        end
      -
    end
    private :add_create_or_update_stub
    
    def add_create_stub(model)
      add_create_or_update_stub :create, model, %-
          obj = #{model.name}.new(params.except(:action, :controller, :id).permit(#{permits(model, true)}))
      -
    end
    
    def add_update_stub(model)
      add_create_or_update_stub :update, model, %-
          obj = #{model.name}.find(params[:id])
          raise 'not_found' if obj.nil?
          obj.update_attributes(params.except(:action, :controller, :id).permit(#{permits(model, true)}))
      -
    end
    
    def add_delete_stub(model)
      m = model.name
      self.class_eval %-
        def delete_#{AppBase.underscore m}
          obj = #{m}.find(params[:id])
          if obj.nil?
            return render json: { status: 'error', msg: 'not_found' }
          end
          if !#{m}.allow_delete?(current_user, obj)
            render json: { status: "error", msg: "unauthorized" }
          else
            obj.delete
            render json: { status: 'ok' }
          end
        rescue Exception => e
          render json: { status: 'error', msg: e.to_s }
        end
      -
    end
    
    def add_query_stub(model)
      m = model.name
      self.class_eval %-
        def query_#{AppBase.underscore m}
          query = #{m}.accessible_by(current_user)
          params.except(:action, :controller, :p, :ps).each { |k, v|
            op = 'eq'
            k = k.to_s
            if k.index('.') && k.split('.').count == 2
              k, op = k.split('.')
            end
            k = k.to_sym
            operators = #{m}.appbase_queryable_operators[k]
            unless #{m}.appbase_queryable_columns.index(k).nil?
              case op
              when 'eq'
                query = query.where "\#{k} = ?", v if operators.nil? || !operators.index(:equal).nil?
              when 'lt'
                query = query.where "\#{k} < ?", v if operators.nil? || !operators.index(:compare).nil?
              when 'le'
                query = query.where "\#{k} <= ?", v if operators.nil? || !operators.index(:compare).nil?
              when 'gt'
                query = query.where "\#{k} > ?", v if operators.nil? || !operators.index(:compare).nil?
              when 'ge'
                query = query.where "\#{k} >= ?", v if operators.nil? || !operators.index(:compare).nil?
              when 'n'
                query = query.where "\#{k} IS NULL" if operators.nil? || !operators.index(:equal).nil?
              when 'nn'
                query = query.where "\#{k} IS NOT NULL" if operators.nil? || !operators.index(:equal).nil?
              when 'in'
                if operators.nil? || !operators.index(:in).nil?
                  values = JSON.parse v
                  query = query.where "\#{k} IN (?)", values
                end
              when 'nin'
                if operators.nil? || !operators.index(:in).nil?
                  values = JSON.parse v
                  query = query.where "\#{k} NOT IN (?)", values
                end
              else
              end
            end
          }
          page_size = [1, (params[:ps]||20).to_i].max
          start = [0, (params[:p]||1).to_i.pred].max * page_size
          render json: { status: 'ok', data: query.offset(start).limit(page_size) }
        rescue Exception => e
          render json: { status: 'error', msg: e.to_s }
        end
      -
    end
    
    def add_rpc_method_stub(bound_method, auth=false)
      RpcMethodStubHelper.new(bound_method, auth).add_stub(self)
    end
    
    class RpcMethodStubHelper
      
      def initialize(bound_method, auth=false)
        @bound_method = bound_method
        @auth = auth
        @method_name = bound_method.name
        @model_name = bound_method.receiver.name.to_s.extend(AppBase::StringExtension)
        init
      end
      
      def add_stub(controller)
        controller.class_eval %-
          def rpc_#{@model_name.underscore}_#{@method_name}
            #{@requires.map{|p|"params.require #{p}"}.join(';')}
            render json: { status: 'ok', data: #{@model_name}.#{@method_name}(#{@parameters.join(', ')}) }
          rescue Exception => e
            render json: { status: 'error', msg: e.to_s }
          end
        -
      end
      
      private
      def init
        init_parameters do |parameters, need_params|
          @requires = parameters.map{|p|":#{p[1]}"}
          @parameters = @auth ? ['current_user'] : []
          @requires.each { |p| @parameters << "params[#{p}]" }
          if need_params
            @parameters.push "params.except(:action, :controller#{@requires.count > 0 ? ", #{@requires.join(', ')}" : ""})"
          end
        end
      end
      
      def pre_init_parameters(parameters)
        if @auth && (parameters.count == 0 || parameters[0][0] != :req)
          raise "#{@model_name}.#{@method_name} does not accept current user identity as the first parameter. Using `expose_to_appbase :method_name, auth: false` to expose #{@model_name}.#{@method_name} to appbase without user authentication."
        end
      end
      
      def post_init_parameters(parameters)
        if parameters.find{|p|p[0]!=:req}
          raise "Error exposing #{@model_name}.#{@method_name} to appbase engine, appbase does not support rest/optional parameters, use options instead!"
        end
      end
      
      def init_parameters
        parameters = @bound_method.parameters
        pre_init_parameters(parameters)
        
        need_params = false
        if parameters.count > 0 && parameters.last[0] == :opt
          need_params = true
          parameters = parameters[(@auth ? 1 : 0)..-2]
        else
          parameters = parameters[(@auth ? 1 : 0)..-1]
        end
        
        post_init_parameters(parameters)
        yield parameters, need_params
      end
    end
    
  end
  
end
