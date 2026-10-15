module Importer
  class RowData
    def self.read(sheet, config, number, mapping)
      raw, mapped = [], {}
      config.fetch("headers").each do |header|
        index = header.fetch("index")
        value = sheet.cell(number, index + 1)
        type = sheet.celltype(number, index + 1)
        original = sheet.excelx_value(number, index + 1)
        raw << { "index" => index, "column" => header.fetch("letter"), "header" => header.fetch("name"),
          "type" => type.to_s, "value" => original, "interpreted_value" => WorkbookPreview.display(value) }
        field = mapping.fetch(index.to_s)
        next if field == "unused" || value.nil? || value.to_s.strip.empty?
        # Roo time-formatted cells return seconds; the XML retains the original Excel day fraction.
        mapped[field] = if field == "finish_time" && %i[time datetime].include?(type)
          # Typed Excel time/duration cells are day units, including elapsed days over 24h.
          seconds = (Float(original) * 86_400).round
          format("%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
        elsif %w[finish_time date_of_birth].include?(field) && value.is_a?(Numeric)
          value
        else
          WorkbookPreview.display(value)
        end
      end
      [ raw, mapped ]
    end
  end
end
