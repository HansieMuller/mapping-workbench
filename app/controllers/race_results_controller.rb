class RaceResultsController < ApplicationController
  def index
    @page = [ params[:page].to_i, 1 ].max
    @results = RaceResult.search(params[:q]).includes(:athlete, race: :event).order(id: :desc)
    @results = @results.where(race_id: params[:race_id]) if params[:race_id].present?
    @results = @results.limit(25).offset((@page - 1) * 25)
  end
end
