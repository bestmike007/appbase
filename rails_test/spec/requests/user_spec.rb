require 'rails_helper'

RSpec.describe "User", :type => :request do
  describe "/_app/user" do
    it "authenticate by User.authenticate(email, password)" do
      post "/_app/user/authenticate", email: 'i@bestmike007.com', password: '3a83f7f1290c2e8a8ef5f28007e76a68a7734f7785a0f8a0e88426cee164c37767784c42e717f5950001fe3ea4510c5ccdb797300a53d4f4abff6147c6002f9f'
      puts @response.body if @response.body.match(/{.+status.+ok.+data.+[0-9a-f]{32}.+}/).nil?
      expect(@response.body.match(/{.+status.+ok.+data.+[0-9a-f]{32}.+}/).nil?).to be false
    end
  end
end
