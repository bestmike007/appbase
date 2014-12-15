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
            if self.respond_to? method_name
              appbase_methods << method_name
            else
              Rails.logger.warn "#{self} does not have method #{method_name}"
            end
          end
        end
        @@appbase_methods[self] = appbase_methods
      end
      def appbase_methods
        @@appbase_methods[self] || []
      end
      
      @@crud = {}
      def crud=(str)
        @@crud[self] = str
      end
      def crud
        @@crud.has_key?(self) ? @@crud[self] : 'crud'
      end
      
    end
  end
  
end
  
ActiveRecord::Base.include AppBase::RestActionModel