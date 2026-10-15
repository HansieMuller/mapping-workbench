class RaceResult < ApplicationRecord
  belongs_to :athlete
  belongs_to :race
  belongs_to :import_batch
  has_many :import_rows, dependent: :restrict_with_error
  has_paper_trail
  before_validation :normalize_finish_status
  validates :finish_time_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :finish_status, inclusion: { in: Importer::FinishStatus::ALIASES.keys,
    message: "is not a supported result status" }, allow_nil: true
  scope :search, ->(query) {
    joins(:athlete).where("race_results.race_number ILIKE ? OR athletes.full_name ILIKE ?",
      *Array.new(2, "%#{sanitize_sql_like(query.to_s)}%"))
  }

  private

  # Preserve unknown values for validation; aliases normalize, and blank statuses remain optional.
  # Workbook raw cells retain the supplied text independently of this authoritative status.
  def normalize_finish_status
    self.finish_status = Importer::FinishStatus.canonical(finish_status) || finish_status.to_s.strip.presence
  end
end
