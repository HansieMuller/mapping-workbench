class AthletesController < ApplicationController
  def index
    @page = [ params[:page].to_i, 1 ].max
    @athletes = Athlete.search(params[:q]).includes(:clubs).order(:full_name).limit(25).offset((@page - 1) * 25)
  end
end
