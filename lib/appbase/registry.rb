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
    
    class << Registry
      
      rpc_methods = []
      crud_permissions = []
      
      define_method :register_rpc do |model, method_name, options={}|
        model = Object.const_get(model.to_sym) if model.instance_of?(String) || model.instance_of?(Symbol)
        method_name = method_name.to_sym
        auth = options.has_key?(:auth) ? options[:auth] : true
        if rpc_methods.find{ |r| r[:model] == model && r[:method] == method_name }.nil?
          rpc_methods << { model: model, method: method_name, auth: auth }
        else
          raise "#{model}.#{method_name} has already been registered"
        end
      end
      
      define_method :each_rpc do |&block|
        rpc_methods.each &block
      end
      
      define_method :register_crud do |model, crud|
        if crud_permissions.find{ |r| r[:model] == model && r[:crud] == crud }.nil?
          crud_permissions << { model: model, crud: crud }
        end
      end
      
      define_method :each_crud do |*models, &block|
        models = models[0] if models.count == 1 && models.instance_of?(Array)
        models = models.map { |model| (model.instance_of?(Symbol) || model.instance_of?(String)) ? Object.const_get(model) : model }
        crud_permissions.each do |r|
          block.call r[:model], r[:crud] if models.index(r[:model])
        end
      end
      
    end
    
  end
  
end