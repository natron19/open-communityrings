class Overlap < ApplicationRecord
  belongs_to :ring_map
  belongs_to :ring_a, class_name: "Ring"
  belongs_to :ring_b, class_name: "Ring"

  validates :shared_element, presence: true
  validates :cross_ring_idea, presence: true
  validate :rings_must_differ
  validate :pair_unique_within_ring_map

  private

  def rings_must_differ
    errors.add(:ring_b_id, "must differ from ring_a_id") if ring_a_id == ring_b_id
  end

  def pair_unique_within_ring_map
    return if ring_a_id.blank? || ring_b_id.blank?
    duplicate = Overlap.where(ring_map_id: ring_map_id)
                       .where(ring_a_id: ring_a_id, ring_b_id: ring_b_id)
                       .where.not(id: id)
    errors.add(:base, "Ring pair already overlaps") if duplicate.exists?
  end
end
