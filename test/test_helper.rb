ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module WorkbenchTestData
  def create_context
    @user = User.create!(email: "operator@example.test", password: "synthetic-test-password")
    @event = Event.create!(name: "Moonfern Festival", event_date: Date.new(2026, 9, 19))
    @race = @event.races.create!(name: "Copper Loop", distance: "10km")
  end

  def create_batch
    ImportBatch.create!(user: @user, event: @event, race: @race, file_name: "fictional.xlsx")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: "synthetic-test-password" }
    assert_redirected_to root_path
  end
end

class ActiveSupport::TestCase
  include WorkbenchTestData
end

require_relative "support/workbook_helpers"
