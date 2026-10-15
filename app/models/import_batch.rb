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

  private

  def race_belongs_to_event
    errors.add(:race, "must belong to the selected event") if race && event && race.event_id != event.id
  end
end
