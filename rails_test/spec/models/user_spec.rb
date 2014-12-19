require 'rails_helper'

RSpec.describe User, :type => :model do
  
  it "include AppBase::ModelConcern" do
    expect(User.ancestors.index(AppBase::ModelConcern).nil?).to be false
  end
  
end
