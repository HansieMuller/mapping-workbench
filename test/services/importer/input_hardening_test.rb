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
      { "xl/workbook.xml" => ->(s) { s.sub('r:id="rId1"', 'r:id="rId999"') } },
      { "xl/_rels/workbook.xml.rels" => ->(s) { s.sub("worksheets/sheet1.xml", "worksheets/missing.xml") } },
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
  test "linked worksheet paths cannot bypass formula and dimension guards" do
    source = Rails.root.join("test/fixtures/files/success.xlsx")
    [ "xl/worksheets/nested/sheet1.xml", "xl/custom.xml" ].each do |path|
      file = Tempfile.new([ "linked-sheet", ".xlsx" ])
      Zip::File.open(file.path, create: true) do |target|
        Zip::File.open(source) do |original|
          original.each do |entry|
            data = entry.get_input_stream.read
            if entry.name == "xl/_rels/workbook.xml.rels"
              data = data.sub("worksheets/sheet1.xml", path.delete_prefix("xl/"))
            end
            if entry.name == "xl/worksheets/sheet1.xml"
              data = data.sub("</sheetData>", '<row r="10001"><c r="A10001"><f>1+1</f><v>2</v></c></row></sheetData>')
            end
            name = entry.name == "xl/worksheets/sheet1.xml" ? path : entry.name
            target.get_output_stream(name) { |io| io.write(data) }
          end
        end
      end
      assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }
      file.close!
    end
  end

  test "worksheet filenames cannot become Roo regular expressions" do
    source = Rails.root.join("test/fixtures/files/success.xlsx")
    file = Tempfile.new([ "regex-sheet", ".xlsx" ])
    Zip::File.open(file.path, create: true) do |target|
      Zip::File.open(source) do |original|
        original.each do |entry|
          data = entry.get_input_stream.read
          data = data.sub("worksheets/sheet1.xml", "worksheets/sheet(.xml") if entry.name == "xl/_rels/workbook.xml.rels"
          name = entry.name == "xl/worksheets/sheet1.xml" ? "xl/worksheets/sheet(.xml" : entry.name
          target.get_output_stream(name) { |io| io.write(data) }
        end
      end
    end
    error = assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }
    assert_match(/Nonstandard worksheet targets/, error.message)
  ensure
    file&.close!
  end

  test "each configured workbook resource limit is enforced on real archives" do
    source = Rails.root.join("test/fixtures/files/success.xlsx")
    file = Tempfile.new([ "byte-limit", ".xlsx" ])
    file.truncate(Importer::WorkbookGuard::MAX_BYTES + 1)
    assert_match(/5 MiB/, assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }.message)
    file.close!
    cases = [
      [ /10000 rows/, { "xl/worksheets/sheet1.xml" => ->(xml) { xml.sub('r="A1"', 'r="A10001"') } } ],
      [ /128 columns/, { "xl/worksheets/sheet1.xml" => ->(xml) { xml.sub('r="A1"', 'r="DY1"') } } ],
      [ /200000 cells/, { "xl/worksheets/sheet1.xml" => ->(xml) { xml.sub(/<sheetData>.*?<\/sheetData>/m, '<sheetData><row r="1">' + '<c r="A1"><v>1</v></c>' * 200_001 + "</row></sheetData>") } } ],
      [ /30 MiB/, { "xl/workbook.xml" => ->(_xml) { "x" * (Importer::WorkbookGuard::MAX_EXPANDED_BYTES + 1) } } ],
      [ /1 to 8 worksheets/, { "xl/workbook.xml" => ->(xml) { xml.sub("</sheets>", (4..9).map { |n| '<sheet name="Fiction' + n.to_s + '" sheetId="' + n.to_s + '" r:id="rId' + n.to_s + '"/>' }.join + "</sheets>") } } ]
    ]
    cases.each do |message, replacement|
      file = rewrite_zip(source, replacement)
      assert_match message, assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }.message
      file.close!
    end
    replacements = (1..3).to_h do |n|
      [ "xl/worksheets/sheet#{n}.xml", ->(xml) { xml.sub(/<sheetData>.*?<\/sheetData>/m, '<sheetData><row r="10000"><c r="A10000"><v>1</v></c></row></sheetData>') } ]
    end
    file = rewrite_zip(source, replacements)
    assert_match(/20000 rows/, assert_raises(Importer::WorkbookGuard::Error) { Importer::WorkbookGuard.validate!(file.path) }.message)
    file.close!
  end
end
