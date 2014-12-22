class UserNote
  
  include AppBase::ModelConcern

  def self.columns
    Note.columns
  end
  
  allow_query within: :user_notes
  restrict_query_columns only: [:created_at, :updated_at, :title]
  restrict_query_operators :created_at, only: [:equal, :compare]
  restrict_query_operators :title, only: [:equal, :in]
  
  class << self
    
    def user_notes(current_user)
      Note.where(user_id: current_user.id)
    end
    
  end
end
