require "test_helper"

class Importer::ParityTest < ActiveSupport::TestCase
  setup { create_context }

  test "original 17 fields, explicit normalized aliases and conservative unknowns" do
    assert_equal 17, Importer::HeaderMapper::FIELDS.length
    { "RaceNo" => "race_number", "ID_NUMBER" => "id_number", "DOB" => "date_of_birth", "RaceTime" => "finish_time", "OverallFinishPosition" => "overall_position" }.each do |header, field|
      assert_equal field, Importer::HeaderMapper.suggest(header)
    end
    %w[ID Name Time Passport AthleteId Age EventId].each { |h| assert_equal "unused", Importer::HeaderMapper.suggest(h) }
    assert_equal "AB", Importer::HeaderMapper.letter(27)
  end

  test "all sheets, corrected headers, unnamed columns and samples survive preview" do
    batch = attach_workbook(create_batch)
    results, profiles, entries = batch.preview_data.fetch("sheets")
    assert_equal "Results", results["name"]
    assert_equal 3, results["header_row"]
    assert_equal "", results["headers"][3]["name"]
    assert_equal "AB", profiles["headers"][27]["letter"]
    assert_equal "Entries", entries["name"]
    assert_equal "Luma Quill", results["rows"][0][1]
    corrected = Importer::WorkbookPreview.call(batch, header_rows: { "0" => "1" })
    assert_equal 1, corrected["sheets"][0]["header_row"]
  end

  test "dates times and status aliases retain the source contract" do
    assert_equal Date.new(1991, 4, 12), Importer::DateParser.date(Date.new(1991, 4, 12))
    assert_equal Date.new(1975, 6, 27), Importer::DateParser.date("750627", reference_year: 2026)
    assert_equal Date.new(2024, 1, 9), Importer::DateParser.date(45_300)
    assert_equal 43_200, Importer::TimeParser.seconds(0.5)
    assert_equal 43_200, Importer::TimeParser.seconds("43200")
    assert_equal 36_611, Importer::TimeParser.seconds("10:10:10.6")
    assert_equal 17_181, Importer::TimeParser.seconds(Time.utc(2000, 1, 1, 4, 46, 21))
    assert_equal "dns", Importer::FinishStatus.canonical("Not yet started")
    assert_equal "dnf", Importer::FinishStatus.canonical("Started and running")
    assert_nil Importer::FinishStatus.canonical("Unknown")
  end

  test "classification preserves profile registration result unsupported and blank" do
    assert_equal "athlete_profile", Importer::RowClassifier.classify("full_name" => "Cloud Fern")
    assert_equal "registration", Importer::RowClassifier.classify("full_name" => "Cloud Fern", "race_number" => "1")
    assert_equal "finish_result", Importer::RowClassifier.classify("finish_status" => "DNS")
    assert_equal "finish_result", Importer::RowClassifier.classify("finish_time" => 0.5)
    assert_equal "unsupported", Importer::RowClassifier.classify("club" => "Lantern Harriers")
    assert_equal "blank", Importer::RowClassifier.classify({})
  end
  test "typed Excel durations keep elapsed days beyond 24 hours" do
    file = Tempfile.new([ "elapsed", ".xlsx" ])
    package = Axlsx::Package.new
    style = package.workbook.styles.add_style(format_code: "[h]:mm:ss")
    package.workbook.add_worksheet(name: "Synthetic") do |sheet|
      sheet.add_row [ "Full name", "Finish time" ]
      sheet.add_row [ "Echo Lantern", 1.25 ], style: [ nil, style ]
    end
    package.serialize(file.path)
    Importer::WorkbookGuard.validate!(file.path)
    workbook = Roo::Excelx.new(file.path)
    sheet = workbook.sheet(0)
    config = { "headers" => [ { "index" => 0, "letter" => "A", "name" => "Full name" }, { "index" => 1, "letter" => "B", "name" => "Finish time" } ] }
    raw, mapped = Importer::RowData.read(sheet, config, 2, "0" => "full_name", "1" => "finish_time")
    assert_equal 1.25, raw[1]["value"]
    assert_equal "30:00:00", mapped["finish_time"]
    assert_equal 108_000, Importer::TimeParser.seconds(mapped["finish_time"])
  ensure
    workbook&.close
    file&.close!
  end
  test "empty worksheets remain previewed and need no phantom mapping input" do
    preview = { "sheets" => [
      { "key" => "0", "name" => "Results", "headers" => [ { "index" => 0 }, { "index" => 1 } ] },
      { "key" => "1", "name" => "Empty", "headers" => [] }
    ] }
    config = { "sheets" => { "0" => { "0" => "full_name", "1" => "finish_time" } } }
    assert_equal({}, Importer::MappingValidator.validate!(preview, config)["sheets"]["1"])
    config["sheets"]["1"] = { "999" => "finish_time" }
    assert_raises(Importer::MappingValidator::Error) { Importer::MappingValidator.validate!(preview, config) }
  end
end
