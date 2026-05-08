require "rails_helper"

RSpec.describe RingMap, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:generated_at) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:profile) }
    it { is_expected.to have_many(:rings).dependent(:destroy) }
    it { is_expected.to have_many(:overlaps).dependent(:destroy) }

    it "cascades destroy through rings to starter_initiatives" do
      ring_map = create(:ring_map)
      ring = create(:ring, ring_map: ring_map)
      create(:starter_initiative, ring: ring)
      expect { ring_map.destroy }.to change(StarterInitiative, :count).by(-1)
    end
  end

  describe "default scope" do
    it "orders by generated_at descending" do
      profile = create(:profile)
      older = create(:ring_map, profile: profile, generated_at: 2.days.ago)
      newer = create(:ring_map, profile: profile, generated_at: 1.day.ago)
      expect(profile.ring_maps.first).to eq(newer)
    end
  end
end
