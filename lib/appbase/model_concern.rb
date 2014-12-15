require 'active_support'

module AppBase
  module RestActionModel
    extend ActiveSupport::Concern
    
    included do
    end
    
    module ClassMethods
      
      @@appbase_methods = {}
      def expose_to_appbase(*method_names)
        appbase_methods = @@appbase_methods[self] || []
        method_names.each do |method_name|
          if appbase_methods.index(method_name).nil?
            appbase_methods << method_name
          end
        end
        @@appbase_methods[self] = appbase_methods
      end
      def appbase_methods
        @@appbase_methods[self] || []
      end
      
      @@appbase_methods_without_authentication = {}
      def before_authenticate(*method_names)
        appbase_methods = @@appbase_methods_without_authentication[self] || []
        method_names.each do |method_name|
          if appbase_methods.index(method_name).nil?
            appbase_methods << method_name
          end
        end
        @@appbase_methods_without_authentication[self] = appbase_methods
      end
      def appbase_methods_without_authentication
        @@appbase_methods_without_authentication[self] || []
      end
      
      @@crud = {}
      def crud(str)
        @@crud[self] = str
      end
      def model_crud
        @@crud.has_key?(self) ? @@crud[self] : 'crud'
      end
      
    end
  end
  
end
  
ActiveRecord::Base.include AppBase::RestActionModel