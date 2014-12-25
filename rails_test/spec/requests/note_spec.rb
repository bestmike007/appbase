require 'rails_helper'

RSpec.describe "Note", :type => :request do
  
  describe "/_app/note" do
    
    before :all do
      if !@user
        @user = User.find_by(email: 'i@bestmike007.com')
        @user.session_token = SecureRandom.hex
        @user.save!
      end
      cookies[:u] = @user.email
      cookies[:s] = @user.session_token
    end
    
    it "gets my recent notes" do
      post "/_app/note/recent_notes"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq(2)
    end
    
    it "gets all my notes" do
      get "/_app/note"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq(2)
    end
    
    it "gets all my notes uses `user_note` alias" do
      get "/_app/user_note"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq(2)
    end
    
    it "has no notes in the future" do
      get "/_app/note?created_at.gt=#{Time.now.to_s.gsub(/\s/, '%20')}"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq(0)
    end
    
    it "does not apply title query" do
      get "/_app/note?title=Test2"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq(2)
    end
    
    it "does apply title query on user_note" do
      get "/_app/user_note?title=Test2"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq(1)
    end
    
    it "does not allow compare query on title" do
      get "/_app/user_note?title.gt=Test"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq 2
    end
    
    it "does allow `in` query on title" do
      get "/_app/user_note?title.in=[%22Test%22]"
      rs = JSON.parse @response.body
      puts @response.body if rs["status"] != 'ok'
      expect(rs["status"]).to eq('ok')
      expect(rs["data"].class).to equal(Array)
      expect(rs["data"].count).to eq 1
    end
    
    it "can create & update & delete note" do
      post '/_app/note', user_id: @user.id, title: "Test3", content: "Hello Appbase!"
      rs = JSON.parse @response.body
      expect(rs["status"]).to eq('ok')
      expect(rs["id"]).to be > 0
      created_id = rs["id"]
      expect(Note.find(created_id).nil?).to be false
      expect(Note.all.count).to eq 3
      put "/_app/note/#{created_id}", title: "Appbase Test"
      rs = JSON.parse @response.body
      expect(rs["status"]).to eq('ok')
      expect(Note.find(created_id).title).to eq "Appbase Test"
      delete "/_app/note/#{created_id}"
      rs = JSON.parse @response.body
      expect(rs["status"]).to eq('ok')
      expect{ Note.find(created_id) }.to raise_error ActiveRecord::RecordNotFound
    end
    
    it "get latest note" do
      post '/_app/user_note/latest_note'
      rs = JSON.parse @response.body
      expect(rs["status"]).to eq('ok')
      expect(rs["data"]["title"]).to eq "Test2"
      
    end
  end
end
