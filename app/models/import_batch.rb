class ImportBatch < ApplicationRecord
  belongs_to :user
  belongs_to :event
  belongs_to :race
  has_one_attached :source_file
  has_many :import_rows, dependent: :destroy
  has_many :race_results, dependent: :restrict_with_error
  has_paper_trail ignore: [ :heartbeat_at, :imported_rows, :failed_rows, :skipped_rows ]
  enum :status, %w[pending_mapping queued processing completed completed_with_errors failed].index_with(&:itself)
  validates :file_name, presence: true
  validate :race_belongs_to_event
  scope :search, ->(query) {
    joins(:event, :race).where("import_batches.file_name ILIKE :q OR import_batches.status ILIKE :q OR events.name ILIKE :q OR races.name ILIKE :q",
      q: "%#{sanitize_sql_like(query.to_s.strip)}%")
  }

  def processed_rows
    imported_rows + failed_rows + skipped_rows
  end

  def progress_payload
    { id: id, status: status, total_rows: total_rows, imported_rows: imported_rows,
      failed_rows: failed_rows, skipped_rows: skipped_rows, processed_rows: processed_rows,
      percentage: total_rows.zero? ? 0 : (100.0 * processed_rows / total_rows).round.clamp(0, 100) }
  end

  def broadcast_progress!
    ImportBatchChannel.broadcast_to(self, progress_payload)
  end

  def refresh_counts!
    counts = import_rows.group(:status).count
    update_columns(imported_rows: counts.fetch("imported", 0), failed_rows: counts.fetch("failed", 0),
      skipped_rows: counts.fetch("skipped", 0), heartbeat_at: Time.current, updated_at: Time.current)
  end

  # Queue state is durable before Redis delivery. A lost delivery can be explicitly resumed.
  def queue!(config)
    with_lock do
      raise Importer::MappingValidator::Error, "Mappings are locked once queued" unless pending_mapping?
      Importer::MappingValidator.validate!(preview_data, config)
      update!(mapping_config: config, status: :queued, queued_at: Time.current,
        total_rows: preview_data.fetch("sheets").sum { |sheet| sheet.fetch("total_rows") })
    end
    enqueue!
  end

  def enqueue!
    job = ImportWorkbookJob.perform_later(id)
    update_column(:job_id, job.provider_job_id)
  end

  # Availability of the advisory lock proves there is no connected worker owner.
  # It is safe to resume immediately; no timer guesses that a live worker has died.
  def resume!
    acquired = Importer::DatabaseLock.with_batch(id) do
      reload
      raise Importer::MappingValidator::Error, "This batch cannot be resumed" unless queued? || processing? || failed?
      update!(status: :queued, fatal_error: nil, queued_at: Time.current)
    end
    raise Importer::MappingValidator::Error, "A worker still owns this batch" unless acquired
    enqueue!
  end

  private

  def race_belongs_to_event
    errors.add(:race, "must belong to the selected event") if race && event && race.event_id != event.id
  end
end
