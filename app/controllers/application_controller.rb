class ApplicationController < ActionController::Base
  include Authentication
  before_action :set_paper_trail_whodunnit

  private

  def user_for_paper_trail
    "User:#{current_user.id}" if current_user
  end
end
