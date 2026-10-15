class Race < ApplicationRecord
  belongs_to :event
  has_many :race_results, dependent: :restrict_with_error
  has_many :import_batches, dependent: :restrict_with_error
  has_paper_trail
  validates :name, :distance, presence: true
  validates :name, uniqueness: { scope: [ :event_id, :distance ] }

  def display_name
    "#{name} (#{distance})"
  end
end
