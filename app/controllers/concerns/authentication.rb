module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :current_user
  end

  private

  def current_user
    Current.session ||= Session.find_by(id: cookies.signed[:session_id])
    Current.user
  end

  def require_authentication
    redirect_to new_session_path unless current_user
  end
end
