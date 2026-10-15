require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  self.use_transactional_tests = false
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 1100 ] do |options|
    options.add_argument("no-sandbox") if ENV["CI"]
  end
  Capybara.default_max_wait_time = 15

  setup do
    ActionCable.server.instance_variable_set(:@pubsub, @real_cable_adapter) if @real_cable_adapter
  end

  # Turbo lazily includes ActionCable::TestHelper, which swaps Redis for its test adapter.
  # Preserve the real adapter for this separate-worker campaign; unit/channel tests keep mocks.
  def before_setup
    return super unless ENV["MW_REAL_WORKER"] == "1"
    @real_cable_adapter = ActionCable.server.pubsub
    super
  end
end
