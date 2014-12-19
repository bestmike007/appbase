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
    
    def add_create_stub(model)
      m = model.name
      permits = model.columns.map { |item| item.name }.to_json
      self.class_eval %-
        def create_#{AppBase.underscore m}
          obj = #{m}.new(params.except(:action, :controller, :id).permit(#{permits}))
          if !#{m}.allow_create?(current_user, obj)
            render json: { status: "error", msg: "unauthorized" }
          else
            obj.save!
            render json: { status: 'ok', id: obj.id }
          end
        rescue Exception => e
          render json: { status: 'error', msg: e.to_s }
        end
      -
    end
    
    def add_update_stub(model)
      m = model.name
      permits = model.columns.map { |item| item.name }.to_json
      self.class_eval %-
        def update_#{AppBase.underscore m}
          obj = #{m}.find(params[:id])
          if obj.nil?
            return render json: { status: 'error', msg: 'not_found' }
          end
          obj.update_attributes(params.except(:action, :controller, :id).permit(#{permits}))
          if !#{m}.allow_update?(current_user, obj)
            render json: { status: "error", msg: "unauthorized" }
          else
            obj.save!
            render json: { status: 'ok' }
          end
        rescue Exception => e
          render json: { status: 'error', msg: e.to_s }
        end
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
      columns = model.columns.map{|c|c.name}
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
      m = bound_method.receiver.name
      mn = bound_method.name
      parameters = bound_method.parameters
      if auth && (parameters.count == 0 || parameters[0][0] != :req)
        raise "#{m}.#{mn} does not accept current user identity as the first parameter. Using `expose_to_appbase :method_name, auth: false` to expose #{m}.#{mn} to appbase without user authentication."
      end
      need_params = false
      if parameters.count > 0 && parameters.last[0] == :opt
        need_params = true
        parameters = parameters[(auth ? 1 : 0)..-2]
      else
        parameters = parameters[(auth ? 1 : 0)..-1]
      end
      if parameters.find{|p|p[0]!=:req}
        raise "Error exposing #{m}.#{mn} to appbase engine, appbase does not support rest/optional parameters, use options instead!"
      end
      requires = parameters.map{|p|":#{p[1]}"}
      parameters = auth ? ['current_user'] : []
      requires.each { |p| parameters << "params[#{p}]" }
      if need_params
        parameters.push "params.except(:action, :controller#{requires.count > 0 ? ", #{requires.join(', ')}" : ""})"
      end
      self.class_eval %-
        def rpc_#{AppBase.underscore m}_#{mn}
          #{requires.map{|p|"params.require #{p}"}.join(';')}
          render json: { status: 'ok', data: #{m}.#{mn}(#{parameters.join(', ')}) }
        rescue Exception => e
          render json: { status: 'error', msg: e.to_s }
        end
      -
    end
    
  end
  
end
