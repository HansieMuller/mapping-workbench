class Club < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :athletes, through: :memberships
  before_validation -> { self.normalized_name = name.to_s.downcase.squish }
  validates :name, presence: true
  validates :normalized_name, uniqueness: true
end
