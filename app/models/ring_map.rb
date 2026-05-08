class RingMap < ApplicationRecord
  belongs_to :profile
  has_many :rings, dependent: :destroy
  has_many :overlaps, dependent: :destroy
  has_one :user, through: :profile

  validates :generated_at, presence: true

  default_scope { order(generated_at: :desc) }
end
