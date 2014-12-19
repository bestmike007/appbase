require "rails_helper"

RSpec.describe AppBaseController, :type => :routing do
    
  routes { AppBase::Engine.routes }
  
  it "has current_user method" do
    expect(AppBaseController.instance_methods(false).index(:current_user).nil?).to be false
  end

  it "contains routes to user model" do
    expect(AppBaseController.instance_methods(false).index(:rpc_user_authenticate).nil?).to be false
    expect(:post => "/user/authenticate").to route_to("app_base#rpc_user_authenticate")
  end
  
  it "contains routes to note model" do
    expect(AppBaseController.instance_methods(false).index(:create_note).nil?).to be false
    expect(:put => "/note").to route_to("app_base#create_note")
    expect(AppBaseController.instance_methods(false).index(:update_note).nil?).to be false
    expect(:put => "/note/1").to route_to("app_base#update_note", :id => '1')
    expect(AppBaseController.instance_methods(false).index(:delete_note).nil?).to be false
    expect(:delete => "/note/1").to route_to("app_base#delete_note", :id => '1')
    expect(AppBaseController.instance_methods(false).index(:query_note).nil?).to be false
    expect(:get => "/note").to route_to("app_base#query_note")
    expect(AppBaseController.instance_methods(false).index(:rpc_note_recent_notes).nil?).to be false
    expect(:post => "/note/recent_notes").to route_to("app_base#rpc_note_recent_notes")
  end

end
