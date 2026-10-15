require "test_helper"

class RaceResultTest < ActiveSupport::TestCase
  setup do
    create_context
    @result = RaceResult.new(race: @race, import_batch: create_batch,
      athlete: Athlete.create!(full_name: "Model Comet"), finish_time_seconds: 0)
  end

  test "every supported status alias normalizes using the shared vocabulary" do
    Importer::FinishStatus::ALIASES.each do |canonical, aliases|
      aliases.each do |value|
        @result.finish_status = "  #{value.upcase}  "
        @result.save!
        assert_equal canonical, @result.reload.finish_status
      end
    end
  end

  test "optional blanks save and unsupported statuses cannot create or update a result" do
    [ nil, "", " " ].each do |blank|
      @result.finish_status = blank
      @result.save!
      assert_nil @result.reload.finish_status
    end
    @result.update!(finish_status: "finished")
    assert_raises(ActiveRecord::RecordInvalid) { @result.update!(finish_status: "INVALID_STATUS") }
    assert_equal "finished", @result.reload.finish_status
    @result = @result.dup
    @result.finish_status = "INVALID_STATUS"
    assert_no_difference "RaceResult.count" do
      assert_raises(ActiveRecord::RecordInvalid) { @result.save! }
    end
    assert_includes @result.errors.full_messages, "Finish status is not a supported result status"
  end
end
