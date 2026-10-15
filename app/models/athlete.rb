class Athlete < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :clubs, through: :memberships
  has_many :race_results, dependent: :restrict_with_error
  has_many :import_rows, dependent: :restrict_with_error
  has_paper_trail
  before_validation :normalize_name
  validates :id_number, format: { with: /\A\d{13}\z/ }, allow_nil: true
  validates :id_number, :passport_number, uniqueness: true, allow_nil: true
  validates :full_name, presence: true, if: -> { id_number.blank? && passport_number.blank? }
  scope :search, ->(query) { where("full_name ILIKE ? OR id_number ILIKE ?", *Array.new(2, "%#{sanitize_sql_like(query.to_s)}%")) }

  private

  def normalize_name
    self.full_name = [ first_name, last_name ].compact_blank.join(" ") if full_name.blank?
    self.identity_name = full_name.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish.presence
  end
end
