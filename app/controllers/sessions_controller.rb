class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create ]
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email, :password))
    if user
      reset_session
      Current.session = user.sessions.create!
      cookies.signed[:session_id] = { value: Current.session.id, httponly: true,
        same_site: :lax, secure: Rails.env.production?, expires: 12.hours.from_now }
      redirect_to root_path
    else
      flash.now[:alert] = "Email or password is incorrect."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    Current.session&.destroy!
    Current.reset
    cookies.delete(:session_id)
    reset_session
    redirect_to new_session_path
  end
end
