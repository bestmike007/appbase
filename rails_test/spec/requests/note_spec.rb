require 'rails_helper'

RSpec.describe "Note", :type => :request do
  describe "/_app/note" do
    it "gets my recent notes" do
      user = User.find_by(email: 'i@bestmike007.com')
      user.session_token = SecureRandom.hex
      user.save!
      cookies[:u] = user.email
      cookies[:s] = user.session_token
      post "/_app/note/recent_notes"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq(2)
    end
  end
end
