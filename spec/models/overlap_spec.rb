require "rails_helper"

RSpec.describe Overlap, type: :model do
  let(:ring_map) { create(:ring_map) }
  let(:ring_a)   { create(:ring, ring_map: ring_map, position: 1) }
  let(:ring_b)   { create(:ring, ring_map: ring_map, position: 2) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:shared_element) }
    it { is_expected.to validate_presence_of(:cross_ring_idea) }

    it "rejects ring_a and ring_b being the same ring" do
      overlap = build(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_a)
      expect(overlap).not_to be_valid
      expect(overlap.errors[:ring_b_id]).to be_present
    end

    it "rejects duplicate ring pairs within the same ring_map" do
      create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      duplicate = build(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      expect(duplicate).not_to be_valid
    end

    it "allows the same ring pair in a different ring_map" do
      other_map = create(:ring_map, profile: ring_map.profile)
      other_a = create(:ring, ring_map: other_map, position: 1)
      other_b = create(:ring, ring_map: other_map, position: 2)
      create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      overlap = build(:overlap, ring_map: other_map, ring_a: other_a, ring_b: other_b)
      expect(overlap).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:ring_map) }
    it { is_expected.to belong_to(:ring_a).class_name("Ring") }
    it { is_expected.to belong_to(:ring_b).class_name("Ring") }
  end
end
