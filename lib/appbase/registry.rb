module AppBase
  
  def self.underscore(str)
    str.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
  
  module StringExtension
    
    def underscore
      AppBase.underscore self
    end
    self
    
  end
  
  module Registry
    
    # rpc & crud methods registration
    # used once upon rails startup, cannot be reloaded by spring.
    class << Registry
      
      class RegistryTable
        
        def initialize
          @rpc_methods = []
          @crud_permissions = []
        end
        
        def contains_rpc_registry(item)
          !@rpc_methods.find{ |r| r[:model] == item[:model] && r[:method] == item[:method] }.nil?
        end
        
        def register_rpc(model, method_name, options={})
          rpc_registry_item = {
            model: (model.instance_of?(String) || model.instance_of?(Symbol)) ? Object.const_get(model.to_sym) : model,
            method: method_name.to_sym,
            auth: options.has_key?(:auth) ? options[:auth] : true
          }
          raise "#{model}.#{method_name} has already been registered" if contains_rpc_registry(rpc_registry_item)
          @rpc_methods << rpc_registry_item
        end
        
        def register_crud(model, crud)
          if @crud_permissions.find{ |r| r[:model] == model && r[:crud] == crud }.nil?
            @crud_permissions << { model: model, crud: crud }
          end
        end
      
        def each_rpc(&block)
          @rpc_methods.each(&block)
        end
        
        def each_crud(*models, &block)
          models = models.flatten.map { |model| (model.instance_of?(Symbol) || model.instance_of?(String)) ? Object.const_get(model) : model }
          @crud_permissions.each do |r|
            block.call r[:model], r[:crud] if models.index(r[:model])
          end
        end
      end
      
      def register_rpc(model, method_name, options={})
        instance.register_rpc(model, method_name, options)
      end
      
      def register_crud(model, crud)
        instance.register_crud(model, crud)
      end
      
      def each_rpc(&block)
        instance.each_rpc(&block)
      end
      
      def each_crud(*models, &block)
        instance.each_crud(*models, &block)
      end
      
      private 
      def instance
        @instance ||= RegistryTable.new
      end
      
    end
    
  end
  
end