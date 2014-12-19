class User < ActiveRecord::Base
  
  expose_to_appbase :authenticate, auth: false
  
  class << User
    def authenticate_by_token(email, token)
      User.find_by(email: email, session_token: token)
    end
    
    def authenticate(email, password)
      user = User.find_by(email: email, password: password)
      return nil if user.nil?
      user.session_token = SecureRandom.hex
      user.last_usage = Time.now
      user.save!
      user.session_token
    end
  end
end
