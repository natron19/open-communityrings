class Profile < ApplicationRecord
  belongs_to :user
  has_many :ring_maps, dependent: :destroy

  validates :life_context, presence: true, length: { minimum: 30, maximum: 1500 }
  validates :weekly_hours, presence: true, inclusion: { in: 1..40 }
  validates :user_id, uniqueness: true
  validates :family_situation,  length: { maximum: 1500 }, allow_blank: true
  validates :neighborhood,      length: { maximum: 1500 }, allow_blank: true
  validates :work_occupation,   length: { maximum: 1500 }, allow_blank: true
  validates :interests,         length: { maximum: 1500 }, allow_blank: true
  validates :values,            length: { maximum: 1500 }, allow_blank: true
  validates :known_rings,       length: { maximum: 1500 }, allow_blank: true
end
