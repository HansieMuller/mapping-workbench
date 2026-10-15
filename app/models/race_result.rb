class RaceResult < ApplicationRecord
  belongs_to :athlete
  belongs_to :race
  belongs_to :import_batch
  has_many :import_rows, dependent: :restrict_with_error
  has_paper_trail
  validates :finish_time_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  scope :search, ->(query) {
    joins(:athlete).where("race_results.race_number ILIKE ? OR athletes.full_name ILIKE ?",
      *Array.new(2, "%#{sanitize_sql_like(query.to_s)}%"))
  }
end
