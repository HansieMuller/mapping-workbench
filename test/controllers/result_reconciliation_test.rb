require "test_helper"

class ResultReconciliationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup { create_context; sign_in }

  RESULT_FIELDS = %w[race_number full_name id_number finish_time finish_status overall_position category category_position gender_position gender club date_of_birth].freeze
  COMPLETE_ROW = [ "501", "Hazel Aurora", "0000000000051", "00:51:23", "finished", "12", "Senior", "3", "5", "female", "Moonpetal Club", "1992-04-12" ].freeze

  test "a time-only mapping preserves numbered result fields and audits the correction once" do
    first = import_workbook(RESULT_FIELDS, [ COMPLETE_ROW ])
    result = RaceResult.find_by!(race_number: "501")
    before = result.attributes.except("finish_time_display", "finish_time_seconds", "updated_at")
    # Optional columns are present and populated, but the operator marks them Unused.
    replacement = COMPLETE_ROW.dup
    replacement[3] = "00:49:01"
    replacement[6] = "Ignored category"
    correction = import_workbook(RESULT_FIELDS, [ replacement ], mapped: %w[race_number full_name id_number finish_time])
    assert_equal before, result.reload.attributes.except("finish_time_display", "finish_time_seconds", "updated_at")
    assert_equal "00:49:01", result.finish_time_display
    assert_equal 2941, result.finish_time_seconds
    assert_equal first.id, result.import_batch_id
    row = correction.import_rows.sole
    assert_equal result.id, row.race_result_id
    assert_equal "Synthetic", row.source_sheet
    assert_equal 2, row.source_row_number
    assert_equal "Ignored category", row.raw_data[6]["value"]
    assert_not row.normalized_data.key?("category")
    assert_equal "update", result.versions.last.event
    assert_equal "User:#{@user.id}", result.versions.last.whodunnit
    snapshot = [ result.attributes, correction.attributes, PaperTrail::Version.count ]
    ImportWorkbookJob.perform_now(correction.id)
    assert_equal snapshot, [ result.reload.attributes, correction.reload.attributes, PaperTrail::Version.count ]
  end

  test "mapped blank cells preserve numbered values and retain mapping presence" do
    import_workbook(RESULT_FIELDS, [ COMPLETE_ROW ])
    result = RaceResult.find_by!(race_number: "501")
    before = result.attributes.except("finish_time_display", "finish_time_seconds", "updated_at")
    blanks = COMPLETE_ROW.first(3) + [ "00:48:00", " ", nil, "", nil, " ", nil, "", nil ]
    correction = import_workbook(RESULT_FIELDS, [ blanks ])
    assert_equal before, result.reload.attributes.except("finish_time_display", "finish_time_seconds", "updated_at")
    assert_equal 2880, result.finish_time_seconds
    row = correction.import_rows.sole
    RESULT_FIELDS.drop(4).each do |field|
      assert row.normalized_data.key?(field), "Mapped blank #{field} must remain distinguishable from Unused"
      assert_nil row.normalized_data[field]
    end
    assert_equal " ", row.raw_data[4]["value"]
  end

  test "replacement optional values and a numeric zero update while absent columns preserve data" do
    first = import_workbook(RESULT_FIELDS.first(4), [ COMPLETE_ROW.first(4) ])
    result = RaceResult.find_by!(race_number: "501")
    assert_nil result.category
    assert_nil result.finish_status
    replacement = COMPLETE_ROW.dup
    replacement[3] = 0
    import_workbook(RESULT_FIELDS, [ replacement ])
    assert_equal 0, result.reload.finish_time_seconds
    assert_equal "0.0", result.finish_time_display
    assert_equal "Senior", result.category
    assert_equal 12, result.overall_position
    assert_equal "female", result.gender
    assert_equal "Moonpetal Club", result.club
    assert_equal 34, result.age_at_race
    assert_equal first.id, result.import_batch_id
    import_workbook(RESULT_FIELDS.first(4), [ COMPLETE_ROW.first(4) ])
    assert_equal "Senior", result.reload.category
    assert_equal 12, result.overall_position
    assert_equal "finished", result.finish_status
  end

  test "unnumbered rows retain same-batch replacement and separate cross-batch results" do
    fields = %w[full_name id_number finish_time category]
    rows = [ [ "Hazel Aurora", "0000000000051", "00:51:23", "Senior" ], [ "Hazel Aurora", "0000000000051", "00:49:01", nil ] ]
    first = import_workbook(fields, rows)
    assert_equal 1, RaceResult.count
    assert_nil RaceResult.sole.category
    assert_equal 2941, RaceResult.sole.finish_time_seconds
    second = import_workbook(fields, [ rows.first ])
    assert_equal 2, RaceResult.count
    assert_equal [ first.id, second.id ], RaceResult.order(:id).pluck(:import_batch_id)
    assert_equal 1, Athlete.count
  end

  test "canonical statuses and aliases are stored canonically with untouched source text" do
    fields = %w[race_number full_name id_number finish_time finish_status]
    statuses = [ [ "finished", "finished" ], [ "  Did Not Start  ", "dns" ], [ "WITHDRAWN", "dnf" ], [ "  DQ  ", "disqualified" ], [ "query", "query" ] ]
    rows = statuses.each_with_index.map do |(supplied, _canonical), index|
      [ (601 + index).to_s, "Fictional Comet #{index}", format("%013d", 61 + index), "00:30:00", supplied ]
    end
    batch = import_workbook(fields, rows)
    statuses.each_with_index do |(supplied, canonical), index|
      result = RaceResult.find_by!(race_number: (601 + index).to_s)
      assert_equal canonical, result.finish_status
      row = batch.import_rows.find_by!(source_row_number: index + 2)
      assert_equal supplied, row.raw_data[4]["value"]
      assert_equal supplied.strip, row.normalized_data["finish_status"]
    end
  end

  test "a status-only numbered correction preserves both time values when mapped time is blank" do
    import_workbook(RESULT_FIELDS, [ COMPLETE_ROW ])
    result = RaceResult.find_by!(race_number: "501")
    before = result.attributes.except("finish_status", "updated_at")
    correction = import_workbook(RESULT_FIELDS.first(5), [ COMPLETE_ROW.first(3) + [ nil, "DQ" ] ])
    assert_equal before, result.reload.attributes.except("finish_status", "updated_at")
    assert_equal "disqualified", result.finish_status
    row = correction.import_rows.sole
    assert row.normalized_data.key?("finish_time")
    assert_nil row.normalized_data["finish_time"]
    assert_equal "finish_result", row.row_type
    assert_equal "DQ", row.raw_data[4]["value"]
  end

  test "invalid status rolls back a new graph and later valid workbook rows succeed" do
    fields = %w[race_number full_name id_number finish_time finish_status club email]
    rows = [ [ "701", "Rejected Willow", "0000000000071", "00:30:00", "INVALID_STATUS", "Rejected Club", "rejected@example.test" ],
      [ "702", "Accepted Willow", "0000000000072", "00:31:00", "Did Not Finish", "Accepted Club", "accepted@example.test" ] ]
    batch = import_workbook(fields, rows, expected_status: "completed_with_errors")
    assert_equal [ 2, 1, 1, 0 ], [ batch.total_rows, batch.imported_rows, batch.failed_rows, batch.skipped_rows ]
    failed = batch.import_rows.find_by!(source_row_number: 2)
    assert_equal "failed", failed.status
    assert_equal "finish_result", failed.row_type
    assert_match(/Finish status is not a supported result status/, failed.error_message)
    assert_equal "INVALID_STATUS", failed.raw_data[4]["value"]
    assert_equal "INVALID_STATUS", failed.normalized_data["finish_status"]
    assert_nil failed.athlete_id
    assert_nil failed.race_result_id
    assert_nil Athlete.find_by(id_number: "0000000000071")
    assert_nil Club.find_by(name: "Rejected Club")
    assert_equal 1, Athlete.count
    assert_equal 1, Club.count
    assert_equal 1, Membership.count
    assert_equal 1, RaceResult.count
    assert_equal "dnf", RaceResult.sole.finish_status
    assert_equal "imported", batch.import_rows.find_by!(source_row_number: 3).status
    assert_equal [ RaceResult.sole.id ], PaperTrail::Version.where(item_type: "RaceResult").pluck(:item_id)
    assert_equal [ Athlete.sole.id ], PaperTrail::Version.where(item_type: "Athlete").pluck(:item_id)
  end

  test "invalid numbered correction leaves result athlete membership and audit untouched" do
    first = import_workbook(RESULT_FIELDS, [ COMPLETE_ROW ])
    result = RaceResult.find_by!(race_number: "501")
    athlete = result.athlete
    before = [ result.attributes, athlete.attributes, result.versions.count, athlete.versions.count ]
    invalid = COMPLETE_ROW.dup
    invalid[3] = "00:40:00"
    invalid[4] = "UNRECOGNIZED"
    invalid[10] = "Rollback Club"
    fields = RESULT_FIELDS + [ "email" ]
    later = [ "502", "Later Aurora", "0000000000052", "00:41:00", "finished", nil, nil, nil, nil, nil, nil, nil, nil ]
    batch = import_workbook(fields, [ invalid + [ "rollback@example.test" ], later ], expected_status: "completed_with_errors")
    assert_equal before, [ result.reload.attributes, athlete.reload.attributes, result.versions.count, athlete.versions.count ]
    assert_equal first.id, result.import_batch_id
    assert_nil athlete.email
    assert_nil Club.find_by(name: "Rollback Club")
    assert_equal 1, Membership.count
    assert_equal 2, Athlete.count
    assert_equal 2, RaceResult.count
    failed = batch.import_rows.find_by!(source_row_number: 2)
    assert_equal "failed", failed.status
    assert_match(/Finish status/, failed.error_message)
    assert_equal "UNRECOGNIZED", failed.raw_data[4]["value"]
    assert_equal "imported", batch.import_rows.find_by!(source_row_number: 3).status
  end

  test "blank or missing statuses remain optional and non-result classifications stay intact" do
    fields = %w[race_number full_name id_number finish_time finish_status]
    batch = import_workbook(fields, [ [ "801", "Blank Comet", "0000000000081", "00:30:00", " " ],
      [ "802", "Registration Comet", "0000000000082", nil, "Unknown" ],
      [ nil, "Profile Comet", "0000000000083", nil, "PROFILE_NOTE" ] ])
    assert_nil RaceResult.sole.finish_status
    assert_equal %w[finish_result registration athlete_profile], batch.import_rows.order(:source_row_number).pluck(:row_type)
    assert_equal 3, Athlete.count
    missing = import_workbook(fields.first(4), [ [ "804", "Missing Comet", "0000000000084", "00:32:00" ] ])
    assert_nil missing.import_rows.sole.race_result.finish_status
    assert_equal 2, RaceResult.count
  end

  private

  # Every scenario uses generated XLSX bytes through authenticated upload, preview and mapping.
  def import_workbook(fields, rows, mapped: fields, expected_status: "completed")
    file = Tempfile.new([ "reconciliation", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Synthetic") do |sheet|
      [ fields, *rows ].each do |row|
        sheet.add_row(row, types: row.map { |value| value.is_a?(Numeric) ? :float : :string })
      end
    end
    package.serialize(file.path)
    upload = Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    post import_batches_path, params: { race_id: @race.id, import_batch: { source_file: upload } }
    batch = ImportBatch.order(:id).last
    assert_redirected_to import_batch_path(batch)
    get import_batch_path(batch)
    assert_response :success
    assert_equal 1, batch.preview_data.fetch("sheets").sole.fetch("header_row")
    mapping = { "sheets" => { "0" => fields.each_with_index.to_h { |field, index| [ index.to_s, mapped.include?(field) ? field : "unused" ] } } }
    assert_enqueued_with(job: ImportWorkbookJob, args: [ batch.id ]) do
      patch confirm_mapping_import_batch_path(batch), params: { mapping_config: mapping }
    end
    assert_equal "queued", batch.reload.status
    ImportWorkbookJob.perform_now(batch.id)
    assert_equal expected_status, batch.reload.status
    batch
  ensure
    file&.close!
  end
end
