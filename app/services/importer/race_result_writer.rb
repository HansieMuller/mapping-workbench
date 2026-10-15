module Importer
  class RaceResultWriter
    def initialize(batch, athlete, data)
      @batch, @athlete, @data = batch, athlete, data
    end

    # Keep the creating batch when updating a numbered result. Each contributing row is audited.
    def write
      number = @data["race_number"].to_s.strip.presence
      result = if number
        RaceResult.find_or_initialize_by(race: @batch.race, race_number: number)
      else
        RaceResult.find_or_initialize_by(race: @batch.race, athlete: @athlete, import_batch: @batch, race_number: nil)
      end
      if result.persisted? && result.athlete_id != @athlete.id
        raise AthleteResolver::IdentityConflict, "Race number already belongs to another athlete"
      end
      result.import_batch ||= @batch
      result.assign_attributes(athlete: @athlete, finish_time_display: @data["finish_time"].to_s.presence,
        finish_time_seconds: TimeParser.seconds(@data["finish_time"]), finish_status: @data["finish_status"],
        overall_position: position("overall_position"), category: @data["category"],
        category_position: position("category_position"), gender_position: position("gender_position"),
        gender: @data["gender"], club: @data["club"], age_at_race: age_at_race)
      result.save!
      result
    end

    private

    def position(key)
      text = @data[key].to_s.strip
      return if text.blank?
      raise InvalidValue, "#{key.humanize} must be a positive whole number" unless text.match?(/\A[1-9]\d*\z/)
      number = Integer(text)
      raise InvalidValue, "#{key.humanize} exceeds the supported integer range" if number > 2_147_483_647
      number
    end

    def age_at_race
      birth = @athlete.date_of_birth
      return unless birth
      date = @batch.event.event_date
      years = date.year - birth.year
      # Preserve calendar birthday semantics: a Feb 29 birthday passes on March 1 in a non-leap year.
      passed = date.month > birth.month || (date.month == birth.month && date.day >= birth.day)
      passed ? years : years - 1
    end
  end
end
