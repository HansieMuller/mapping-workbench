class Event < ApplicationRecord
  has_many :races, dependent: :restrict_with_error
  has_many :import_batches, dependent: :restrict_with_error
  has_paper_trail
  validates :name, :event_date, presence: true
  validates :name, uniqueness: { scope: :event_date }

  def display_name
    "#{name} · #{event_date}"
  end
end
