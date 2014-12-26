require 'active_support'

module AppBase
  
  module ModelConcern
      
    class InvalidUsage < Exception
    end
    
    class ModelConcernHelper
      
      private
      
      def validate_crud(crud)
        if [:create, :update, :delete, :query].index(crud).nil?
          raise "Unsupported crud operation: #{crud}, available options: create, update, delete, query"
        end
      end
      
      def model_inject(method_name=nil, &block)
        AppBase::Engine.after_initialized do
          user_identity_attr = "#{AppBase::Engine::UserIdentity.underscore}_id"
          if method_name.nil?
            method_body = block.call(user_identity_attr)
            @model.class_eval method_body
          else
            @model.define_singleton_method method_name.to_sym, &block
          end
        end
      end
      
      def show_usage(crud)
        raise %-
          allow_#{crud} usage:
            allow_#{crud} :mine
            allow_#{crud} :#{ crud == :query ? 'within' : 'if' } => :a_singleton_method
            allow_#{crud} :#{ crud == :query ? 'within' : 'if' } do |current_user_identity#{ crud == :query ? '' : ', model_instance' }|
              # #{ crud == :query ? 'return fitlered query, e.g. Note.where(:user_id => current_user_identity.id)' : 'return true if allowed' }
            end
        -
      end
        
      def allow_mine(crud)
        model_inject do |user_identity_attr|
          crud == :query ? %-
            def self.accessible_by(user)
              #{@model.name}.where(:#{user_identity_attr} => user.id)
            end
          - : %-
            def self.allow_#{crud}?(user, obj)
              user.id == obj.#{user_identity_attr}
            end
          -
        end
      end
      
      def allow_criteria_with_block(crud, block)
        show_usage(crud) if crud == :query && block.parameters.count != 1
        show_usage(crud) if crud != :query && block.parameters.count != 2
        model_inject crud == :query ? :accessible_by : "allow_#{crud}", &block
      end
      
      def allow_criteria_with_method_alias(crud, method_name)
        show_usage(crud) if method_name.nil? || !method_name.instance_of?(Symbol)
        model_inject do |user_identity_attr|
          crud == :query ? %-
            def self.accessible_by(user)
              #{@model.name}.#{method_name} user
            end
          - : %-
            def self.allow_#{crud}?(user, obj)
              #{@model.name}.#{method_name} user, obj
            end
          -
        end
      end
      
      public
      
      def crud_allow(crud, criteria=:mine, &block)
        validate_crud crud
        
        if criteria == :mine
          allow_mine crud
        else
          key = crud == :query ? :within : :if
          if criteria.instance_of? Hash
            allow_criteria_with_method_alias(crud, criteria[key])
          else
            show_usage(crud) if criteria != key || !block_given?
            allow_criteria_with_block(crud, block)
          end
        end
        AppBase::Registry.register_crud @model, crud
      end
      
      def symbol_array_manipulate(op, source, options)
        raise InvalidUsage if op != :only && op != :except
        if options.has_key? op
          operands = options[op]
          operands = [operands] if operands.instance_of?(String) || operands.instance_of?(Symbol)
          raise InvalidUsage unless operands.instance_of?(Array)
          operands = operands.map {|c|c.to_sym}
          source.send({ only: '&', except: "-" }[op], operands)
        else
          source
        end
      end
      
      private
      def initialize(model)
        @model = model
      end
      
      class << self
        
        def [](model)
          raise "Invalid model" if model.class != Class
          helpers[model] ||= ModelConcernHelper.new(model)
        end
        
        private
        def helpers
          @helpers ||= {}
        end
      end
      
    end
  
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
      
      def allow_create(criteria=:mine, &block)
        appbase_helper.crud_allow(:create, criteria, &block)
      end
      
      def allow_update(criteria=:mine, &block)
        appbase_helper.crud_allow(:update, criteria, &block)
      end
      
      def allow_delete(criteria=:mine, &block)
        appbase_helper.crud_allow(:delete, criteria, &block)
      end
      
      def allow_query(criteria=:mine, &block)
        appbase_helper.crud_allow(:query, criteria, &block)
      end
      
      def restrict_query_columns(options={})
        raise InvalidUsage if !options || !options.instance_of?(Hash)
        columns = self.columns.map{|c|c.name.to_sym}
        
        columns = appbase_helper.symbol_array_manipulate :only, columns, options
        columns = appbase_helper.symbol_array_manipulate :except, columns, options
        
        self.define_singleton_method :appbase_queryable_columns do
          columns
        end
        
      rescue InvalidUsage
        raise %-
          restrict_query_columns usage:
            restrict_query_columns <only | except>: <single_column | column_list>
          examples:
            restrict_query_columns only: [:user_id, :created_at, :updated_at]
            restrict_query_columns only: :updated_at
            restrict_query_columns except: [:content]
        -
      end
      
      def appbase_queryable_operators
        return {}
      end
        
      def restrict_query_operators(*columns)
        check_before_restrict_query_operators columns
        *columns, options = columns
        operators = appbase_queryable_operators
        
        set = [:equal, :compare, :in]
        set = appbase_helper.symbol_array_manipulate :only, set, options
        set = appbase_helper.symbol_array_manipulate :except, set, options
        
        columns.each do |c|
          operators[c.to_sym] = set
        end
        
        self.define_singleton_method :appbase_queryable_operators do
          operators
        end
      rescue InvalidUsage
        raise %-
          restrict_query_operators usage:
            restrict_query_operators :column1, :column2, <only | except>: <:equal | :compare | :in>
          examples:
            restrict_query_operators :user_id, :created_at, :updated_at, only: [:equal, :compare]
            restrict_query_operators :user_id, :created_at, :updated_at, except: :in
            restrict_query_operators :title, only: :equal
        -
      end
      
      private
      
      def check_before_restrict_query_operators(columns)
        raise InvalidUsage if columns.count < 2 || !columns.last.instance_of?(Hash)
        options = columns.last
        raise InvalidUsage unless options.has_key?(:only) || options.has_key?(:except)
      end
      
      def appbase_helper
        ModelConcernHelper[self]
      end
    end
    
  end
  
end

class ActiveRecord::Base
  include AppBase::ModelConcern
end