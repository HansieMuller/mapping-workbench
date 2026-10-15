class Membership < ApplicationRecord
  belongs_to :athlete
  belongs_to :club
  validates :athlete_id, uniqueness: { scope: :club_id }
end
