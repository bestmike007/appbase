class AppBaseController < ActionController::Base
  def version
    render json: AppBase::VERSION
  end
end
