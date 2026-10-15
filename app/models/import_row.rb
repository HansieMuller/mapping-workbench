class ImportRow < ApplicationRecord
  belongs_to :import_batch
  belongs_to :athlete, optional: true
  belongs_to :race_result, optional: true
  validates :source_sheet, :source_row_number, :row_type, :status, presence: true
  scope :terminal, -> { where(status: %w[imported failed skipped]) }
end
