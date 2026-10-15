require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection
  setup { create_context }

  test "anonymous connections are rejected" do
    assert_reject_connection { connect }
  end

  test "signed active sessions connect and expired sessions are rejected" do
    session = @user.sessions.create!
    cookies.signed[:session_id] = session.id
    connect
    assert_equal @user, connection.current_user
    session.update!(created_at: 13.hours.ago)
    assert_reject_connection { connect }
  end
end
