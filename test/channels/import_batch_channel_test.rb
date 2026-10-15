require "test_helper"

class ImportBatchChannelTest < ActionCable::Channel::TestCase
  setup { create_context; stub_connection current_user: @user }

  test "owner receives initial durable progress and authenticated stream" do
    batch = create_batch
    subscribe id: batch.id
    assert subscription.confirmed?
    assert_has_stream_for batch
    assert_equal batch.id, transmissions.last["id"]
    assert_equal "pending_mapping", transmissions.last["status"]
    batch.update!(status: :completed)
    perform :refresh
    assert_equal "completed", transmissions.last["status"]
  end

  test "foreign and missing batch subscriptions are rejected" do
    batch = create_batch
    other = User.create!(email: "other@example.test", password: "synthetic-test-password")
    stub_connection current_user: other
    subscribe id: batch.id
    assert subscription.rejected?
  end
end
