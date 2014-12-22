module AppBase
  
  refine String do
    def underscore
      AppBase.underscore self
    end
  end
  
  class << AppBase
    
    def underscore(str)
      str.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
    end
    
  end
  
end