require "test_helper"

class DomainTest < ActiveSupport::TestCase
  setup { create_context }

  test "batch context is protected by validation and PostgreSQL" do
    other = Event.create!(name: "Starling Parade", event_date: @event.event_date)
    batch = create_batch
    batch.event = other
    assert_not batch.valid?
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ImportBatch.transaction(requires_new: true) { batch.update_columns(event_id: other.id) }
    end
    assert_equal @event, batch.reload.event
  end

  test "strong identities and normalized clubs have database uniqueness" do
    Athlete.create!(full_name: "Luma Quill", id_number: "0000000000001")
    assert_raises(ActiveRecord::RecordNotUnique) do
      Athlete.transaction(requires_new: true) do
        Athlete.insert_all!([ { full_name: "Other Fiction", id_number: "0000000000001", created_at: Time.current, updated_at: Time.current } ])
      end
    end
    club = Club.create!(name: "Moonfern Striders")
    assert_not Club.new(name: " MOONFERN  STRIDERS ").valid?
    athlete = Athlete.first
    Membership.create!(athlete: athlete, club: club)
    assert_not Membership.new(athlete: athlete, club: club).valid?
  end
end
