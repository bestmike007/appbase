require 'rails_helper'

RSpec.describe Note, :type => :model do
  
  it "include AppBase::ModelConcern" do
    expect(Note.ancestors.index(AppBase::ModelConcern).nil?).to be false
  end
  
  it "have query restrictions" do
    expect(Note.appbase_queryable_columns.count).to equal(2)
    expect(Note.appbase_queryable_operators[:created_at]).to contain_exactly(:equal, :compare)
    expect(Note.appbase_queryable_operators[:updated_at]).to equal(nil)
  end
  
end
