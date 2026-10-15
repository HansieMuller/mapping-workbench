class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :import_batches, dependent: :restrict_with_error
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, allow_nil: true
end
