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

  private

  # Every scenario uses generated XLSX bytes through authenticated upload, preview and mapping.
  def import_workbook(fields, rows, mapped: fields)
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
    assert_equal "completed", batch.reload.status
    batch
  ensure
    file&.close!
  end
end
