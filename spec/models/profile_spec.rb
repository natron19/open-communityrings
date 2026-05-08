require "rails_helper"

RSpec.describe Profile, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:life_context) }
    it { is_expected.to validate_presence_of(:weekly_hours) }

    it "requires life_context to be at least 30 characters" do
      profile = build(:profile, life_context: "Too short")
      expect(profile).not_to be_valid
      expect(profile.errors[:life_context]).to be_present
    end

    it "requires weekly_hours to be between 1 and 40" do
      expect(build(:profile, weekly_hours: 0)).not_to be_valid
      expect(build(:profile, weekly_hours: 41)).not_to be_valid
      expect(build(:profile, weekly_hours: 1)).to be_valid
      expect(build(:profile, weekly_hours: 40)).to be_valid
    end

    it "enforces maximum length on optional text fields" do
      long_text = "a" * 1501
      %i[family_situation neighborhood work_occupation interests values known_rings].each do |field|
        profile = build(:profile, field => long_text)
        expect(profile).not_to be_valid, "Expected #{field} to fail with 1501 chars"
      end
    end

    it "allows blank optional text fields" do
      profile = build(:profile, family_situation: nil, neighborhood: nil)
      expect(profile).to be_valid
    end

    it "enforces uniqueness of user_id" do
      user = create(:user)
      create(:profile, user: user)
      duplicate = build(:profile, user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:ring_maps).dependent(:destroy) }

    it "destroys ring_maps when profile is destroyed" do
      profile = create(:profile)
      create(:ring_map, profile: profile)
      expect { profile.destroy }.to change(RingMap, :count).by(-1)
    end
  end
end
