require "test_helper"

class Importer::InputHardeningTest < ActiveSupport::TestCase
  setup { create_context }

  test "mapping tampering duplicate destinations and prerequisites are rejected" do
    batch = attach_workbook(create_batch)
    preview = batch.preview_data
    valid = batch.mapping_config
    assert_equal valid, Importer::MappingValidator.validate!(preview, valid)
    bad = valid.deep_dup
    bad["sheets"]["0"]["99999"] = "id_number"
    assert_raises(Importer::MappingValidator::Error) { Importer::MappingValidator.validate!(preview, bad) }
    [ "passport_number", "admin", "race_id" ].each do |field|
      bad = valid.deep_dup
      bad["sheets"]["0"]["0"] = field
      assert_raises(Importer::MappingValidator::Error) { Importer::MappingValidator.validate!(preview, bad) }
    end
    bad = valid.deep_dup
    bad["sheets"]["0"]["0"] = "full_name"
    assert_raises(Importer::MappingValidator::Error) { Importer::MappingValidator.validate!(preview, bad) }
    bad = valid.deep_dup
    bad["sheets"]["0"]["5"] = "unused"
    assert_raises(Importer::MappingValidator::Error) { Importer::MappingValidator.validate!(preview, bad) }
    bad = valid.deep_dup
    bad["sheets"]["0"]["1"] = bad["sheets"]["0"]["2"] = "unused"
    assert_raises(Importer::MappingValidator::Error) { Importer::MappingValidator.validate!(preview, bad) }
  end

  test "invalid dates and time components fail explicitly" do
    [ "1992-02-30", "not-a-date", -1, 0, 10.2 ].each do |value|
      assert_raises(Importer::InvalidValue) { Importer::DateParser.date(value) }
    end
    [ "00:61:00", "00:00:60", "banana", -1, 200_000, Float::INFINITY ].each do |value|
      assert_raises(Importer::InvalidValue) { Importer::TimeParser.seconds(value) }
    end
  end

  test "formula external reference malformed XML and excessive dimensions fail before Roo" do
    source = Rails.root.join("test/fixtures/files/success.xlsx")
    mutations = [
      { "xl/worksheets/sheet1.xml" => ->(s) { s.sub("<sheetData>", '<sheetData><row r="9999"><c r="A9999"><f>1+1</f><v>2</v></c></row>') } },
      { "xl/_rels/workbook.xml.rels" => ->(s) { s.sub("<Relationships ", '<Relationships broken="') } },
      { "xl/_rels/workbook.xml.rels" => ->(s) { s.sub('Target="worksheets/sheet1.xml"', 'Target="https://example.test/private" TargetMode="External"') } },
      { "xl/worksheets/sheet1.xml" => ->(s) { s.sub('r="A1"', 'r="XFD1048576"') } },
      { "xl/worksheets/sheet1.xml" => ->(s) { s.sub("Moonfern", "x" * 5000) } }
    ]
    mutations.each do |replacement|
      file = rewrite_zip(source, replacement)
      assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }
      file.close!
    end
    file = Tempfile.new([ "malformed", ".xlsx" ])
    file.write("not a zip"); file.flush
    assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }
    file.close!
  end

  test "archive limits path traversal and decompression abuse are enforced" do
    file = Tempfile.new([ "unsafe", ".xlsx" ])
    Zip::File.open(file.path, create: true) do |zip|
      zip.get_output_stream("[Content_Types].xml") { |s| s.write("<Types/>") }
      zip.get_output_stream("xl/workbook.xml") { |s| s.write('<workbook><sheet name="Fiction"/></workbook>') }
      zip.get_output_stream("../outside.xml") { |s| s.write("<unsafe/>") }
    end
    assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }
    file.close!
    file = Tempfile.new([ "expanded", ".xlsx" ])
    Zip::File.open(file.path, create: true) do |zip|
      zip.get_output_stream("[Content_Types].xml") { |s| s.write("<Types/>") }
      zip.get_output_stream("xl/workbook.xml") { |s| s.write("x" * (Importer::WorkbookGuard::MAX_EXPANDED_BYTES + 1)) }
    end
    assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }
    file.close!
  end
end
