class Note < ActiveRecord::Base
  allow_create
  allow_update
  allow_delete
  allow_query
  restrict_query_columns only: [:created_at, :updated_at]
  restrict_query_operators :created_at, only: [:equal, :compare]
  
  expose_to_appbase :recent_notes
  
  class << self
    def recent_notes(user)
      Note.where("created_at > ?", Time.now - 86400)
    end
  end
end
