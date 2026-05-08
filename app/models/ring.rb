class Ring < ApplicationRecord
  belongs_to :ring_map
  has_many :starter_initiatives, dependent: :destroy
  has_many :overlaps_as_a, class_name: "Overlap", foreign_key: :ring_a_id, dependent: :destroy
  has_many :overlaps_as_b, class_name: "Overlap", foreign_key: :ring_b_id, dependent: :destroy

  RING_TYPES = %w[
    family neighborhood civic workplace professional faith_or_values
    education sports_recreation arts_cultural health_wellness
    hobby_interest online_digital cause_based service_volunteer mentorship
  ].freeze

  SOURCES = %w[ai_generated user_added].freeze

  validates :name, presence: true, length: { minimum: 2, maximum: 80 }
  validates :ring_type, inclusion: { in: RING_TYPES }
  validates :description, presence: true, length: { minimum: 10, maximum: 1500 }
  validates :rationale, presence: true, length: { minimum: 10, maximum: 500 }
  validates :position, presence: true, uniqueness: { scope: :ring_map_id }
  validates :source, inclusion: { in: SOURCES }

  default_scope { order(position: :asc) }

  def all_overlaps
    Overlap.where(ring_a_id: id).or(Overlap.where(ring_b_id: id))
  end
end
