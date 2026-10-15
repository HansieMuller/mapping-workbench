module Importer
  class DateParser
    def self.date(value, reference_year: Date.current.year)
      return if value.blank?
      return value.to_date if value.is_a?(Date) || value.is_a?(Time)
      if value.is_a?(Numeric)
        raise InvalidValue, "Date serial must be a whole positive day" unless value.finite? && value.positive? && value == value.to_i && value <= 73_050
        return Date.new(1899, 12, 30) + value.to_i
      end
      text = value.to_s.strip
      if text.match?(/\A\d{6}\z/)
        year = text[0, 2].to_i
        year += year > reference_year % 100 ? 1900 : 2000
        return Date.new(year, text[2, 2].to_i, text[4, 2].to_i)
      end
      format = case text
      when /\A\d{4}-\d{2}-\d{2}\z/ then "%Y-%m-%d"
      when /\A\d{4}\/\d{2}\/\d{2}\z/ then "%Y/%m/%d"
      when /\A\d{2}\/\d{2}\/\d{4}\z/ then "%d/%m/%Y"
      end
      raise InvalidValue, "Date must use YYYY-MM-DD, YYYY/MM/DD, DD/MM/YYYY or YYMMDD" unless format
      Date.strptime(text, format)
    rescue ArgumentError, TypeError
      raise InvalidValue, "Invalid date: #{value}"
    end
  end
end
