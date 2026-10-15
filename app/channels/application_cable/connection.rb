module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      session = Session.where("created_at > ?", 12.hours.ago).find_by(id: cookies.signed[:session_id])
      self.current_user = session&.user || reject_unauthorized_connection
    end
  end
end
