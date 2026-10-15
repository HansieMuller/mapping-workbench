module Importer
  class RowClassifier
    def self.classify(data)
      return "blank" if data.values.all?(&:blank?)
      return "finish_result" if data["finish_time"].present? || FinishStatus.canonical(data["finish_status"])
      return "registration" if data["finish_status"].to_s.downcase == "unknown" || data["race_number"].present?
      return "athlete_profile" if data.values_at("id_number", "passport_number", "full_name", "first_name", "last_name").any?(&:present?)
      "unsupported"
    end
  end
end
