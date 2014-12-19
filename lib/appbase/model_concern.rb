require 'active_support'

module AppBase
  
  module ModelConcern
  
    extend ActiveSupport::Concern
    
    module ClassMethods
      
      def expose_to_appbase(*method_names)
        return if method_names.count == 0
        options = {}
        if method_names.last.instance_of? Hash
          *method_names, options = method_names
        end
        method_names.each do |method_name|
          AppBase::Registry.register_rpc self, method_name, options
        end
      end
      
      def appbase_allow(crud, criteria=:mine, &block)
        if [:create, :update, :delete, :query].index(crud).nil?
          raise "Unsupported crud operation: #{crud}, available options: create, update, delete, query"
        end
        model = self
        if criteria == :mine
          # allow_xxx :mine or simply allow_xxx
          AppBase::Engine.after_initialized do
            user_identity_attr = "#{AppBase::Engine::UserIdentity.underscore}_id"
            model.class_eval crud == :query ? %-
              def self.accessible_by(user)
                #{model.name}.where(:#{user_identity_attr} => user.id)
              end
            - : %-
              def self.allow_#{crud}?(user, obj)
                user.id == obj.#{user_identity_attr}
              end
            -
          end
        elsif crud != :query && criteria == :if && block_given? && block.parameters.count == 2
          # allow_xxx :if do; end
          AppBase::Engine.after_initialized do
            user_identity_attr = "#{AppBase::Engine::UserIdentity.underscore}_id"
            model.define_singleton_method "allow_#{crud}".to_sym, &block
          end
        elsif crud == :query && criteria == :within && block_given? && block.parameters.count == 1
          # allow_query :within {|current_user| Model.where(...)}
          AppBase::Engine.after_initialized do
            user_identity_attr = "#{AppBase::Engine::UserIdentity.underscore}_id"
            model.define_singleton_method :accessible_by, &block
          end
        elsif crud != :query && riteria.instance_of?(Hash) && criteria.has_key?(:if) && criteria[:if].instance_of?(Symbol)
          # :if => :a_singleton_method
          AppBase::Engine.after_initialized do
            user_identity_attr = "#{AppBase::Engine::UserIdentity.underscore}_id"
            model.class_eval %-
              def self.allow_#{crud}?(user, obj)
                #{model.name}.#{criteria[:if]} user
              end
            -
          end
        elsif crud == :query && criteria.instance_of?(Hash) && criteria.has_key?(:within) && criteria[:within].instance_of?(Symbol)
          # allow_query :within => :a_singleton_query_method
          AppBase::Engine.after_initialized do
            user_identity_attr = "#{AppBase::Engine::UserIdentity.underscore}_id"
            model.class_eval %-
              def self.accessible_by(user)
                #{model.name}.#{criteria[:within]} user
              end
            -
          end
        else
          raise %-
            allow_#{crud} usage:
              allow_#{crud} :mine
              allow_#{crud} :#{ crud == :query ? 'within' : 'if' } => :a_singleton_method
              allow_#{crud} :#{ crud == :query ? 'within' : 'if' } do |current_user_identity#{ crud == :query ? '' : ', model_instance' }|
                # #{ crud == :query ? 'return fitlered query, e.g. Note.where(:user_id => current_user_identity.id)' : 'return true if allowed' }
              end
          -
        end
        AppBase::Registry.register_crud self, crud
      end
      
      def allow_create(criteria=:mine, &block)
        appbase_allow(:create, criteria, &block)
      end
      
      def allow_update(criteria=:mine, &block)
        appbase_allow(:update, criteria, &block)
      end
      
      def allow_delete(criteria=:mine, &block)
        appbase_allow(:delete, criteria, &block)
      end
      
      def allow_query(criteria=:mine, &block)
        appbase_allow(:query, criteria, &block)
      end
      
      def restrict_query_columns(options={})
        show_usage = proc {
          raise %-
            restrict_query_columns usage:
              restrict_query_columns <only | except>: <single_column | column_list>
            examples:
              restrict_query_columns only: [:user_id, :created_at, :updated_at]
              restrict_query_columns only: :updated_at
              restrict_query_columns except: [:content]
          -
        }
        show_usage.call if !options || !options.instance_of?(Hash)
        columns = self.columns.map{|c|c.name.to_sym}
        # on columns
        if options.has_key? :only
          on_columns = options[:only]
          on_columns = [on_columns] if on_columns.instance_of?(String) || on_columns.instance_of?(Symbol)
          show_usage.call unless on_columns.instance_of?(Array)
          on_columns = on_columns.map {|c|c.to_sym}
          columns &= on_columns
        end
        # except columns
        if options.has_key? :except
          except_columns = options[:except]
          except_columns = [except_columns] if except_columns.instance_of?(String) || except_columns.instance_of?(Symbol)
          show_usage.call unless except_columns.instance_of?(Array)
          except_columns = except_columns.map {|c|c.to_sym}
          columns -= except_columns
        end
        
        self.define_singleton_method :appbase_queryable_columns do
          columns
        end
        
      end
      
      def appbase_queryable_operators
        return {}
      end
        
      def restrict_query_operators(*columns)
        show_usage = proc {
          raise %-
            restrict_query_operators usage:
              restrict_query_operators :column1, :column2, <only | except>: <:equal | :compare | :in>
            examples:
              restrict_query_operators :user_id, :created_at, :updated_at, only: [:equal, :compare]
              restrict_query_operators :user_id, :created_at, :updated_at, except: :in
              restrict_query_operators :title, only: :equal
          -
        }
        show_usage.call if columns.count < 2 || !columns.last.instance_of?(Hash)
        *columns, options = columns
        show_usage.call unless options.has_key?(:only) || options.has_key?(:except)
        operators = appbase_queryable_operators
        
        set = [:equal, :compare, :in]
        # on columns
        if options.has_key? :only
          allows = options[:only]
          allows = [allows] if allows.instance_of?(String) || allows.instance_of?(Symbol)
          show_usage.call unless allows.instance_of?(Array)
          allows = allows.map {|c|c.to_sym}
          set &= allows
        end
        # except columns
        if options.has_key? :except
          excepts = options[:except]
          excepts = [excepts] if excepts.instance_of?(String) || excepts.instance_of?(Symbol)
          show_usage.call unless excepts.instance_of?(Array)
          excepts = excepts.map {|c|c.to_sym}
          set -= excepts
        end
        
        columns.each do |c|
          operators[c.to_sym] = set
        end
        
        self.define_singleton_method :appbase_queryable_operators do
          operators
        end
        
      end
      
      
    end
    
  end
  
end

ActiveRecord::Base.include AppBase::ModelConcern