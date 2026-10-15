require "test_helper"

class Importer::RelationalImportTest < ActiveSupport::TestCase
  setup { create_context }

  def run_batch(name = "mixed.xlsx")
    batch = attach_workbook(create_batch, name: name)
    batch.update!(status: :queued, total_rows: batch.preview_data["sheets"].sum { |s| s["total_rows"] })
    ImportWorkbookJob.perform_now(batch.id)
    batch.reload
  end

  test "real XLSX mixed import commits valid profiles and results with failed row provenance" do
    batch = run_batch
    assert_equal "completed_with_errors", batch.status
    assert_equal 6, batch.imported_rows
    assert_equal 3, batch.failed_rows
    assert_equal 1, batch.skipped_rows
    assert_equal 10, batch.total_rows
    assert_equal 10, batch.import_rows.count
    assert_equal 4, RaceResult.count
    assert_equal 6, Athlete.count
    assert_equal 2, Club.count
    assert_equal 3, Membership.count
    assert_equal [ @race.id ], RaceResult.distinct.pluck(:race_id)
    assert_nil batch.import_rows.find_by(source_sheet: "Profiles").race_result
    assert_nil batch.import_rows.find_by(source_sheet: "Entries").race_result
    result = RaceResult.find_by(race_number: "101")
    assert_equal "00:51:23", result.finish_time_display
    assert_equal 3083, result.finish_time_seconds
    assert_equal 35, result.age_at_race
    assert_equal 1, result.overall_position
    raw = batch.import_rows.find_by(source_sheet: "Results", source_row_number: 4).raw_data
    assert_equal "unused original note", raw[3]["value"]
    assert_equal "D", raw[3]["column"]
    assert_equal "", raw[3]["header"]
    assert_equal "date", raw[4]["type"]
    assert_equal "33340.0", raw[4]["value"]
    assert_equal "1991-04-12", batch.import_rows.find_by(source_row_number: 4, source_sheet: "Results").normalized_data["date_of_birth"]
    assert_nil Athlete.find_by(id_number: "0000000000006")
    assert_match(/minutes and seconds/, batch.import_rows.find_by(source_row_number: 10, source_sheet: "Results").error_message)
    assert_equal "User:#{@user.id}", result.versions.last.whodunnit
  end

  test "cross batch numbered upsert preserves creating batch and per-batch no-number behavior" do
    first = run_batch("success.xlsx")
    result = RaceResult.find_by(race_number: "101")
    second = run_batch("updates.xlsx")
    assert_equal "completed", second.status
    assert_equal result.id, RaceResult.find_by(race_number: "101").id
    assert_equal first.id, result.reload.import_batch_id
    assert_equal 2941, result.finish_time_seconds
    assert_equal 4, RaceResult.count
    third = run_batch("success.xlsx")
    assert_equal "completed", third.status
    assert_equal 5, RaceResult.count
    assert_equal 2, RaceResult.where(race_number: nil).count
    assert_equal 6, Athlete.count
    assert_equal 2, Club.count
  end

  test "race number and strong identity conflicts roll back the row" do
    run_batch("success.xlsx")
    batch = run_batch("conflict.xlsx")
    assert_equal "completed_with_errors", batch.status
    assert_equal 2, batch.failed_rows
    assert_nil Athlete.find_by(full_name: "Bramble Finch")
    assert_nil Athlete.find_by(full_name: "Conflicting Person")
    assert_equal "Luma Quill", RaceResult.find_by(race_number: "101").athlete.full_name
  end

  test "duplicate job starts do not replay committed rows or reset counters" do
    batch = run_batch("success.xlsx")
    before = [ batch.attributes, RaceResult.count, Athlete.count, PaperTrail::Version.count ]
    ImportWorkbookJob.perform_now(batch.id)
    assert_equal before, [ batch.reload.attributes, RaceResult.count, Athlete.count, PaperTrail::Version.count ]
  end

  test "passport service precedence and conflicts are retained without a dropdown option" do
    batch = create_batch
    data = { "passport_number" => "DEMO-PASSPORT-001", "full_name" => "Glimmer Wren", "date_of_birth" => "1982-04-10" }
    athlete = Athlete.transaction { Importer::AthleteResolver.new(batch, data).resolve }
    same = Athlete.transaction { Importer::AthleteResolver.new(batch, data.merge("email" => "glimmer@example.test")).resolve }
    assert_equal athlete, same
    assert_equal "glimmer@example.test", same.email
    assert_raises(Importer::AthleteResolver::IdentityConflict) do
      Athlete.transaction(requires_new: true) { Importer::AthleteResolver.new(batch, data.merge("full_name" => "Other Person")).resolve }
    end
    assert_not_includes Importer::HeaderMapper::FIELDS, "passport_number"
  end

  test "fill missing only and ambiguity policies do not silently merge people" do
    batch = create_batch
    data = { "id_number" => "0000000000011", "full_name" => "Echo Bloom", "permanent_number" => "DEMO-11" }
    athlete = Athlete.transaction { Importer::AthleteResolver.new(batch, data).resolve }
    updated = Athlete.transaction { Importer::AthleteResolver.new(batch, data.merge("permanent_number" => "DEMO-99", "email" => "echo@example.test")).resolve }
    assert_equal "DEMO-11", updated.permanent_number
    assert_equal "echo@example.test", updated.email
    other = create_batch
    assert_raises(Importer::AthleteResolver::IdentityConflict) do
      Athlete.transaction(requires_new: true) { Importer::AthleteResolver.new(other, "full_name" => "Echo Bloom").resolve }
    end
    assert_equal athlete, updated
    Athlete.create!(full_name: "Twin Fern", date_of_birth: Date.new(1990, 1, 1), id_number: "0000000000012")
    Athlete.create!(full_name: "Twin Fern", date_of_birth: Date.new(1990, 1, 1), id_number: "0000000000013")
    assert_raises(Importer::AthleteResolver::IdentityConflict) do
      Athlete.transaction(requires_new: true) { Importer::AthleteResolver.new(batch, "full_name" => "Twin Fern", "date_of_birth" => "1990-01-01").resolve }
    end
  end
  test "oversized positions fail only their row and later rows still commit" do
    batch = attach_workbook(create_batch, name: "success.xlsx")
    # Keep the workbook real; map a synthetic malformed numeric cell in a replacement file.
    file = rewrite_zip(Rails.root.join("test/fixtures/files/success.xlsx"),
      "xl/worksheets/sheet1.xml" => ->(xml) { xml.sub('<c r="H4"', '<c r="H4"').sub(/(<c r="H4"[^>]*><v>)1(<\/v>)/, "\\12147483648\\2") })
    batch.source_file.attach(io: File.open(file.path), filename: "overflow.xlsx")
    batch.update!(status: :queued, total_rows: 8)
    ImportWorkbookJob.perform_now(batch.id)
    assert_equal "completed_with_errors", batch.reload.status
    assert_equal 1, batch.failed_rows
    assert_equal 5, batch.imported_rows
    assert_nil Athlete.find_by(id_number: "0000000000001")
    assert Athlete.find_by(id_number: "0000000000002")
    assert_match(/integer range/, batch.import_rows.find_by(source_sheet: "Results", source_row_number: 4).error_message)
  ensure
    file&.close!
  end

  test "numbered results preserve omitted fields and Feb 29 birthdays use March 1 in non-leap years" do
    batch = create_batch
    athlete = Athlete.create!(full_name: "Leap Fiction", date_of_birth: Date.new(1984, 2, 29))
    @event.update!(event_date: Date.new(2026, 2, 28))
    first = Importer::RaceResultWriter.new(batch, athlete, "race_number" => "401", "finish_time" => "01:00:00", "category" => "Open", "overall_position" => "1").write
    second = Importer::RaceResultWriter.new(batch, athlete, "race_number" => "401", "finish_time" => "00:59:00").write
    assert_equal first.id, second.id
    assert_equal "Open", second.category
    assert_equal 1, second.overall_position
    assert_equal 41, second.age_at_race
  end
end
