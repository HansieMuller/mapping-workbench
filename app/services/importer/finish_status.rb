module Importer
  class FinishStatus
    ALIASES = {
      "finished" => [ "finished" ],
      "dns" => [ "dns", "did not start", "not yet started" ],
      "dnf" => [ "dnf", "did not finish", "withdrawn during race", "withdrawn", "started and running" ],
      "disqualified" => [ "disqualified", "dq" ], "query" => [ "query" ]
    }.freeze

    def self.canonical(value)
      ALIASES.find { |_status, values| values.include?(value.to_s.downcase.strip) }&.first
    end
  end
end
