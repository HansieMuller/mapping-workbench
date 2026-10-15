module Importer
  class HeaderMapper
    FIELDS = %w[race_number first_name last_name full_name id_number permanent_number date_of_birth gender email mobile_number club finish_status finish_time overall_position category category_position gender_position].freeze
    ALIASES = {
      "race_number" => [ "raceno", "race number", "race no", "21 10km race no" ],
      "first_name" => [ "first name", "firstname", "given name" ],
      "last_name" => [ "last name", "surname", "family name" ],
      "full_name" => [ "full name" ],
      "id_number" => [ "id number", "idnumber", "id no", "identity number", "rsa id" ],
      "permanent_number" => [ "permanent number" ],
      "date_of_birth" => [ "date of birth", "dob", "dob formatted", "dateofbirth" ],
      "gender" => [ "gender" ], "email" => [ "email" ],
      "mobile_number" => [ "tel c", "mobile number", "cell number", "selfoon", "contact phone number" ],
      "club" => [ "club", "name of athletic club" ],
      "finish_status" => [ "finish status" ],
      "finish_time" => [ "racetime", "finish time", "result time", "race time" ],
      "overall_position" => [ "overallfinishposition", "overall position", "overall pos" ],
      "category" => [ "category", "age group", "age category" ],
      "category_position" => [ "categoryfinishposition", "category position" ],
      "gender_position" => [ "genderfinishposition", "gender position" ]
    }.freeze

    def self.suggest(header)
      normalized = header.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip
      ALIASES.find { |_field, names| names.include?(normalized) }&.first || "unused"
    end

    def self.letter(index)
      number = index + 1
      output = +""
      while number.positive?
        number, remainder = (number - 1).divmod(26)
        output.prepend((65 + remainder).chr)
      end
      output
    end
  end
end
