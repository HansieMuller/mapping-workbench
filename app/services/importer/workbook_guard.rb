require "zip"
require "nokogiri"

module Importer
  class WorkbookGuard
    MAX_BYTES = 5.megabytes
    MAX_EXPANDED_BYTES = 30.megabytes
    MAX_ENTRIES = 100
    MAX_SHEETS = 8
    MAX_ROWS = 10_000
    MAX_TOTAL_ROWS = 20_000
    MAX_COLUMNS = 128
    MAX_CELLS = 200_000
    MAX_CELL_BYTES = 4096
    class Error < StandardError; end

    # Inspect bounded XML before Roo can allocate rows or unpack any archive members.
    def self.validate!(path)
      raise Error, "Workbook exceeds 5 MiB" if File.size(path) > MAX_BYTES
      new(path).validate!
    end

    def initialize(path)
      @path = path
      @expanded = @cells = @total_rows = 0
    end

    def validate!
      Zip::File.open(@path) do |zip|
        raise Error, "Archive has too many entries" if zip.entries.size > MAX_ENTRIES
        names = zip.entries.map(&:name)
        raise Error, "Duplicate archive paths" if names.map(&:downcase).uniq.size != names.size
        raise Error, "Missing workbook XML" unless names.include?("xl/workbook.xml") && names.include?("[Content_Types].xml")
        zip.each do |entry|
          validate_path!(entry)
          next if entry.directory?
          raise Error, "Expanded archive exceeds 30 MiB" if entry.size > MAX_EXPANDED_BYTES || @expanded + entry.size > MAX_EXPANDED_BYTES
          content = +""
          entry.get_input_stream do |stream|
            while (chunk = stream.read(16_384)) && !chunk.empty?
              @expanded += chunk.bytesize
              raise Error, "Expanded archive exceeds 30 MiB" if @expanded > MAX_EXPANDED_BYTES
              content << chunk
            end
          end
          doc = parse_xml(content)
          validate_relationships!(doc) if entry.name.end_with?(".rels")
          validate_workbook!(doc) if entry.name == "xl/workbook.xml"
          validate_sheet!(doc) if entry.name.match?(%r{\Axl/worksheets/[^/]+\.xml\z})
          if entry.name == "xl/sharedStrings.xml"
            doc.xpath("//*[local-name()='si']").each { |cell| validate_cell!(cell) }
          end
        end
      end
      true
    rescue Zip::Error, Nokogiri::XML::SyntaxError, ArgumentError, EOFError, Zlib::Error
      raise Error, "Malformed XLSX archive or XML"
    end

    private

    def validate_path!(entry)
      name = entry.name
      raise Error, "Unsafe archive path" if name.start_with?("/", "\\") || name.include?("\\") || name.split("/").include?("..") || name.bytesize > 200 || entry.symlink?
      raise Error, "Only plain XLSX XML is supported" unless entry.directory? || name.end_with?(".xml", ".rels")
      raise Error, "External workbook references are unsupported" if name.downcase.include?("externallink")
    end

    def parse_xml(content)
      raise Error, "XML declarations with entities are unsupported" if content.match?(/<!DOCTYPE|<!ENTITY/i)
      doc = Nokogiri::XML(content) { |config| config.strict.nonet }
      raise Error, "XML entities are unsupported" if doc.internal_subset || doc.external_subset
      doc
    end

    def validate_relationships!(doc)
      doc.xpath("//*[local-name()='Relationship']").each do |rel|
        raise Error, "External relationships are unsupported" if rel["TargetMode"].to_s.casecmp?("External") || rel["Target"].to_s.match?(%r{\A(?:[a-z]+:|//)}i)
      end
    end

    def validate_workbook!(doc)
      sheets = doc.xpath("//*[local-name()='sheet']")
      raise Error, "Workbook must contain 1 to 8 worksheets" unless sheets.size.between?(1, MAX_SHEETS)
      raise Error, "Duplicate worksheet names" unless sheets.map { |s| s["name"] }.uniq.size == sheets.size
      raise Error, "1904 date workbooks are unsupported; save using the 1900 date system" if doc.at_xpath("//*[local-name()='workbookPr']")&.[]("date1904").in?([ "1", "true" ])
    end

    def validate_sheet!(doc)
      raise Error, "Formulas are unsupported; upload values only" if doc.at_xpath("//*[local-name()='f']")
      rows = doc.xpath("//*[local-name()='sheetData']/*[local-name()='row']")
      last_row = rows.map { |row| Integer(row["r"], 10) }.max.to_i
      raise Error, "Worksheet exceeds 10000 rows" if last_row > MAX_ROWS || rows.size > MAX_ROWS
      @total_rows += last_row
      raise Error, "Workbook exceeds 20000 rows" if @total_rows > MAX_TOTAL_ROWS
      refs = doc.xpath("//*[local-name()='c']/@r").map(&:value)
      refs.concat(doc.xpath("//*[local-name()='dimension']/@ref").flat_map { |attr| attr.value.split(":") })
      refs.each { |ref| validate_coordinate!(ref) }
      doc.xpath("//*[local-name()='c']").each do |cell|
        @cells += 1
        raise Error, "Workbook exceeds 200000 cells" if @cells > MAX_CELLS
        validate_cell!(cell)
      end
    end

    def validate_coordinate!(ref)
      match = /\A([A-Z]+)([1-9]\d*)\z/.match(ref)
      raise Error, "Invalid worksheet coordinate" unless match
      column = match[1].each_byte.reduce(0) { |n, c| n * 26 + c - 64 }
      raise Error, "Worksheet exceeds 128 columns or 10000 rows" if column > MAX_COLUMNS || match[2].to_i > MAX_ROWS
    end

    def validate_cell!(cell)
      raise Error, "Cell exceeds 4096 bytes" if cell.text.bytesize > MAX_CELL_BYTES
    end
  end
end
