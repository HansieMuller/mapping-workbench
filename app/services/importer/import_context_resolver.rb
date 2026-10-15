module Importer
  class ImportContextResolver
    class Error < StandardError; end

    def self.call(params)
      params = params.with_indifferent_access
      if params[:race_id].present?
        race = Race.find(params[:race_id])
        raise Error, "Selected race does not belong to the selected event" if params[:event_id].present? && race.event_id.to_s != params[:event_id].to_s
        return race
      end
      Event.transaction do
        event = if params[:event_id].present?
          Event.find(params[:event_id])
        else
          date = DateParser.date(params[:event_date])
          raise Error, "Event name and date are required" if params[:event_name].blank? || date.nil?
          Event.find_or_create_by!(name: params[:event_name].strip, event_date: date)
        end
        name = params[:race_name].to_s.strip.presence || params[:race_distance].to_s.strip.presence
        distance = params[:race_distance].to_s.strip.presence || name
        raise Error, "Race name or distance is required" unless name
        event.races.find_or_create_by!(name: name, distance: distance)
      end
    end
  end
end
