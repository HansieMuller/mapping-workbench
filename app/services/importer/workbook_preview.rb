module Importer
  class WorkbookPreview
    def self.open(batch)
      batch.source_file.open do |file|
        WorkbookGuard.validate!(file.path)
        workbook = Roo::Excelx.new(file.path)
        yield workbook
      ensure
        workbook&.close
      end
    end

    def self.call(batch, header_rows: {})
      open(batch) do |workbook|
        { "sheets" => workbook.sheets.each_with_index.map do |name, index|
          sheet = workbook.sheet(name)
          candidates = (1..[ sheet.last_row.to_i, 8 ].min).map do |row|
            values = sheet.row(row)
            { "row" => row, "matches" => values.count { |v| HeaderMapper.suggest(v) != "unused" },
              "values" => values.map { |v| display(v) } }
          end
          suggested = candidates.max_by { |c| [ c["matches"], -c["row"] ] }
          header = Integer(header_rows.fetch(index.to_s, suggested&.fetch("row", 1) || 1))
          raise WorkbookGuard::Error, "Header row must exist in #{name}" unless header.between?(1, [ sheet.last_row.to_i, 1 ].max)
          used = []
          headers = Array.new(sheet.last_column.to_i) do |column|
            value = display(sheet.cell(header, column + 1))
            mapping = HeaderMapper.suggest(value)
            mapping = "unused" if used.include?(mapping)
            used << mapping unless mapping == "unused"
            { "index" => column, "letter" => HeaderMapper.letter(column), "name" => value, "suggested_mapping" => mapping }
          end
          { "key" => index.to_s, "name" => name, "header_row" => header,
            "uncertain" => !suggested || suggested["matches"] < 2,
            "candidates" => candidates, "headers" => headers,
            "total_rows" => [ sheet.last_row.to_i - header, 0 ].max,
            "rows" => ((header + 1)..[ sheet.last_row.to_i, header + 5 ].min).map { |r| sheet.row(r).map { |v| display(v) } } }
        end }
      end
    rescue NoMethodError, KeyError, TypeError
      raise WorkbookGuard::Error, "Malformed workbook structure; re-save as a plain values-only XLSX"
    end

    def self.display(value)
      case value
      when Time, DateTime then value.strftime("%H:%M:%S")
      when Date then value.iso8601
      else value.to_s.strip
      end
    end
  end
end
