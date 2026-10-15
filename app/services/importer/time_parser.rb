module Importer
  class TimeParser
    def self.seconds(value)
      return if value.blank?
      if value.is_a?(Time) || value.is_a?(DateTime)
        return value.hour * 3600 + value.min * 60 + value.sec
      end
      if value.is_a?(Numeric) || value.to_s.strip.match?(/\A\d+(?:\.\d+)?\z/)
        number = Float(value)
        raise InvalidValue, "Time must be between 0 and 199999 seconds" unless number.finite? && number >= 0 && number < 200_000
        result = (number.positive? && number < 1 ? number * 86_400 : number).round
        raise InvalidValue, "Time exceeds 199999 seconds" if result >= 200_000
        return result
      end
      match = /\A(\d{1,3}):(\d{2})(?::(\d{2}(?:\.\d+)?))?\z/.match(value.to_s.strip)
      raise InvalidValue, "Time must be HH:MM[:SS], an Excel day fraction, or seconds" unless match
      hours, minutes, seconds = match[1].to_i, match[2].to_i, (match[3] || "0").to_f
      raise InvalidValue, "Time minutes and seconds must be less than 60" if minutes >= 60 || seconds >= 60
      result = (hours * 3600 + minutes * 60 + seconds).round
      raise InvalidValue, "Time exceeds 199999 seconds" if result >= 200_000
      result
    end
  end
end
