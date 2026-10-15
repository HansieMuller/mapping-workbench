class ImportBatchesController < ApplicationController
  before_action :set_batch, only: [ :show, :update_headers, :confirm_mapping, :resume, :download ]

  def index
    @query = params[:q].to_s.strip
    @page = [ params[:page].to_i, 1 ].max
    @batches = current_user.import_batches.search(@query).includes(:event, :race).order(id: :desc).limit(25).offset((@page - 1) * 25)
  end

  def new
    @events = Event.order(event_date: :desc)
    @races = Race.includes(:event).order(:name)
    @race = Race.find(params[:race_id]) if params[:race_id].present?
  end

  def context
    race = Importer::ImportContextResolver.call(context_params.to_h)
    redirect_to new_import_batch_path(race_id: race.id)
  rescue Importer::ImportContextResolver::Error, Importer::InvalidValue, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    @error = error.is_a?(ActiveRecord::RecordNotFound) ? "Select an existing event and race" : error.message
    new
    render :new, status: :unprocessable_entity
  end

  def create
    race = Race.find(params.require(:race_id))
    @batch = Importer::Upload.call(current_user, race, params.dig(:import_batch, :source_file))
    redirect_to import_batch_path(@batch), notice: "Workbook inspected. Confirm each worksheet's header and mapping."
  rescue Importer::WorkbookGuard::Error, ActiveRecord::RecordNotFound, ActionController::ParameterMissing => error
    @error = error.is_a?(Importer::WorkbookGuard::Error) ? error.message : "Select a race before uploading"
    new
    render :new, status: :unprocessable_entity
  end

  def show
    @row_page = [ params[:page].to_i, 1 ].max
    @rows = @batch.import_rows.includes(:athlete, :race_result).order(:source_sheet, :source_row_number).limit(50).offset((@row_page - 1) * 50)
    @versions = @batch.versions.order(id: :desc).limit(25)
  end

  def update_headers
    @batch.with_lock do
      raise Importer::MappingValidator::Error, "Headers are locked once queued" unless @batch.pending_mapping?
      rows = params.require(:header_rows).permit(*@batch.preview_data.fetch("sheets").map { |s| s.fetch("key") }).to_h
      preview = Importer::WorkbookPreview.call(@batch, header_rows: rows)
      @batch.update!(preview_data: preview, mapping_config: Importer::MappingValidator.suggest(preview))
    end
    redirect_to @batch, notice: "Headers updated. Review the refreshed mappings."
  rescue Importer::MappingValidator::Error, Importer::WorkbookGuard::Error, ArgumentError => error
    redirect_to @batch, alert: error.message
  end

  def confirm_mapping
    mapping = params.require(:mapping_config)
    raise Importer::MappingValidator::Error, "Mappings must be an object" unless mapping.is_a?(ActionController::Parameters)
    config = mapping.to_unsafe_h
    @batch.queue!(config)
    redirect_to @batch, notice: "Import queued. Keep this page open for live progress."
  rescue Importer::MappingValidator::Error, ActionController::ParameterMissing => error
    redirect_to @batch, alert: error.message
  rescue RedisClient::Error
    redirect_to @batch, alert: "Queue unavailable. The queued batch is durable; start Redis and resume."
  end

  def resume
    @batch.resume!
    redirect_to @batch, notice: "Resume queued. Committed and failed rows remain checkpoints."
  rescue Importer::MappingValidator::Error => error
    redirect_to @batch, alert: error.message
  rescue RedisClient::Error
    redirect_to @batch, alert: "Queue unavailable. Start Redis and resume this batch."
  end

  def download
    response.headers["Cache-Control"] = "private, no-store"
    send_data @batch.source_file.download, filename: @batch.file_name,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", disposition: "attachment"
  end

  private

  def set_batch
    @batch = current_user.import_batches.find(params[:id])
  end

  def context_params
    params.fetch(:import_context, ActionController::Parameters.new).permit(:event_id, :race_id, :event_name, :event_date, :race_name, :race_distance)
  end
end
