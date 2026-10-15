require "caxlsx"

module WorkbookHelpers
  def attach_workbook(batch, name: "mixed.xlsx")
    batch.source_file.attach(io: File.open(Rails.root.join("test/fixtures/files", name)), filename: name,
      content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    batch.update!(preview_data: Importer::WorkbookPreview.call(batch))
    batch.update!(mapping_config: Importer::MappingValidator.suggest(batch.preview_data))
    batch
  end

  def make_workbook(rows)
    file = Tempfile.new([ "synthetic", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Synthetic") { |sheet| rows.each { |row| sheet.add_row(row) } }
    package.serialize(file.path)
    file
  end

  def rewrite_zip(path, replacements)
    output = Tempfile.new([ "mutated", ".xlsx" ])
    Zip::File.open(output.path, create: true) do |target|
      Zip::File.open(path) do |source|
        source.each do |entry|
          data = entry.get_input_stream.read
          data = replacements.fetch(entry.name, ->(s) { s }).call(data)
          target.get_output_stream(entry.name) { |io| io.write(data) }
        end
      end
    end
    output
  end
end

ActiveSupport::TestCase.include WorkbookHelpers
