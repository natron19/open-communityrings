require "rails_helper"

RSpec.describe Ring, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:rationale) }
    it { is_expected.to validate_presence_of(:position) }

    it "validates ring_type is in the taxonomy" do
      expect(build(:ring, ring_type: "neighborhood")).to be_valid
      expect(build(:ring, ring_type: "invalid_type")).not_to be_valid
    end

    it "validates source is ai_generated or user_added" do
      expect(build(:ring, source: "ai_generated")).to be_valid
      expect(build(:ring, source: "user_added")).to be_valid
      expect(build(:ring, source: "other")).not_to be_valid
    end

    it "validates position uniqueness scoped to ring_map_id" do
      ring_map = create(:ring_map)
      create(:ring, ring_map: ring_map, position: 1)
      duplicate = build(:ring, ring_map: ring_map, position: 1)
      expect(duplicate).not_to be_valid
    end

    it "allows the same position on different ring_maps" do
      create(:ring, position: 1)
      ring = build(:ring, position: 1)
      expect(ring).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:ring_map) }
    it { is_expected.to have_many(:starter_initiatives).dependent(:destroy) }

    it "destroys overlaps when ring is destroyed" do
      ring_map = create(:ring_map)
      ring_a = create(:ring, ring_map: ring_map, position: 1)
      ring_b = create(:ring, ring_map: ring_map, position: 2)
      create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      expect { ring_a.destroy }.to change(Overlap, :count).by(-1)
    end
  end

  describe "default scope" do
    it "orders by position ascending" do
      ring_map = create(:ring_map)
      r3 = create(:ring, ring_map: ring_map, position: 3)
      r1 = create(:ring, ring_map: ring_map, position: 1)
      expect(ring_map.rings.first).to eq(r1)
    end
  end
end
