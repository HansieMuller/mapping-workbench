module Importer
  class AthleteResolver
    PLACEHOLDERS = %w[#n/a n/a na unknown null nil - --].freeze
    class IdentityConflict < StandardError; end

    def initialize(batch, data)
      @batch, @data = batch, data
    end

    # Serialize the small demo's identity decisions, then rely on unique indexes as backstops.
    # Call within the row transaction; never hold this lock across network work.
    def resolve
      DatabaseLock.lock_identities!
      attributes = profile_attributes
      id = attributes[:id_number]
      passport = attributes[:passport_number]
      name = comparable(attributes[:full_name])
      birth = attributes[:date_of_birth]
      raise IdentityConflict, "Missing athlete identity" if id.blank? && passport.blank? && name.blank?
      by_id = Athlete.find_by(id_number: id) if id
      by_passport = Athlete.find_by(passport_number: passport) if passport
      if by_id && by_passport && by_id != by_passport
        raise IdentityConflict, "ID and passport identify different athletes"
      end
      athlete = by_id || by_passport
      if athlete.nil? && name.present? && birth.present?
        candidates = Athlete.where(identity_name: name, date_of_birth: birth).limit(2).to_a
        raise IdentityConflict, "Ambiguous name and birth date; supply a matching ID" if candidates.size > 1
        athlete = candidates.first
      end
      if athlete.nil? && id.nil? && passport.nil? && birth.nil?
        key = "#{@batch.id}:#{name}"
        athlete = Athlete.find_by(weak_identity_key: key)
        if athlete.nil? && Athlete.where(identity_name: name).exists?
          raise IdentityConflict, "Name-only match is ambiguous across batches; supply ID or date of birth"
        end
        attributes[:weak_identity_key] = key
      end
      athlete ||= Athlete.new
      ensure_compatible!(athlete, attributes)
      attributes.each { |field, value| athlete[field] = value if value.present? && athlete[field].blank? }
      athlete.save!
      assign_club!(athlete)
      athlete
    end

    private

    def profile_attributes
      id = clean(@data["id_number"])
      # Invalid/placeholder IDs never become identity keys. Names/DOB may still identify a profile.
      id = nil unless id&.match?(/\A\d{13}\z/)
      birth = DateParser.date(clean(@data["date_of_birth"]), reference_year: @batch.event.event_date.year)
      raise InvalidValue, "Date of birth must precede the event" if birth && birth > @batch.event.event_date
      first, last = clean(@data["first_name"]), clean(@data["last_name"])
      name = clean(@data["full_name"]) || [ first, last ].compact_blank.join(" ").presence
      { first_name: first, last_name: last, full_name: name, id_number: id,
        passport_number: clean(@data["passport_number"]), date_of_birth: birth,
        permanent_number: clean(@data["permanent_number"]), gender: clean(@data["gender"]),
        email: clean(@data["email"]), mobile_number: clean(@data["mobile_number"]) }
    end

    def ensure_compatible!(athlete, attributes)
      %i[id_number passport_number date_of_birth full_name].each do |key|
        old, incoming = athlete[key], attributes[key]
        next if old.blank? || incoming.blank?
        different = key == :full_name ? comparable(old) != comparable(incoming) : old != incoming
        raise IdentityConflict, "Athlete identity conflict in #{key.to_s.humanize.downcase}" if different
      end
    end

    def assign_club!(athlete)
      name = clean(@data["club"])
      return unless name
      club = Club.find_or_create_by!(normalized_name: name.downcase.squish) { |c| c.name = name }
      Membership.find_or_create_by!(athlete: athlete, club: club)
    end

    def clean(value)
      text = value.is_a?(Date) ? value.iso8601 : value
      return text if text.is_a?(Numeric)
      text = text.to_s.strip.presence
      text unless text && PLACEHOLDERS.include?(text.downcase)
    end

    def comparable(name)
      name.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
    end
  end
end
