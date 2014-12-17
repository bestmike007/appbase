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
        self.appbase_allow(:create, criteria, &block)
      end
      
      def allow_update(criteria=:mine, &block)
        self.appbase_allow(:update, criteria, &block)
      end
      
      def allow_delete(criteria=:mine, &block)
        self.appbase_allow(:delete, criteria, &block)
      end
      
      def allow_query(criteria=:mine, &block)
        self.appbase_allow(:query, criteria, &block)
      end
      
    end
    
  end
  
end

ActiveRecord::Base.include AppBase::ModelConcern