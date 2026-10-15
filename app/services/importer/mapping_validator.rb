module Importer
  class MappingValidator
    class Error < StandardError; end

    def self.validate!(preview, config)
      raise Error, "Mappings must be an object" unless config.is_a?(Hash) && config["sheets"].is_a?(Hash)
      sheets = preview.fetch("sheets")
      raise Error, "Map every previewed worksheet and no unknown worksheets" unless config["sheets"].keys.sort == sheets.map { |s| s.fetch("key") }.sort
      results = 0
      sheets.each do |sheet|
        columns = config["sheets"][sheet["key"]]
        indexes = sheet.fetch("headers").map { |h| h.fetch("index").to_s }
        raise Error, "#{sheet['name']}: invalid column indexes" unless columns.is_a?(Hash) && columns.keys.sort == indexes.sort
        raise Error, "#{sheet['name']}: unknown destination" unless columns.values.all? { |v| (HeaderMapper::FIELDS + [ "unused" ]).include?(v) }
        fields = columns.values.reject { |v| v == "unused" }
        raise Error, "#{sheet['name']}: destination mapped more than once" unless fields.uniq.size == fields.size
        if fields.include?("finish_time") || fields.include?("finish_status")
          identity = fields.include?("id_number") || fields.include?("full_name") || (fields.include?("first_name") && fields.include?("last_name"))
          raise Error, "#{sheet['name']}: map ID number, full name, or first and last name for results" unless identity
        end
        results += 1 if fields.include?("finish_time")
      end
      raise Error, "Map finish time on at least one results sheet" if results.zero?
      config
    end

    def self.suggest(preview)
      { "sheets" => preview.fetch("sheets").to_h { |s| [ s.fetch("key"), s.fetch("headers").to_h { |h| [ h.fetch("index").to_s, h.fetch("suggested_mapping") ] } ] } }
    end
  end
end
