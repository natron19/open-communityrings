require "rails_helper"

RSpec.describe StarterInitiative, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:goal) }
    it { is_expected.to validate_presence_of(:activities) }
    it { is_expected.to validate_presence_of(:expected_outcomes) }
    it { is_expected.to validate_presence_of(:next_step) }

    it "enforces max length on goal" do
      expect(build(:starter_initiative, goal: "a" * 301)).not_to be_valid
    end

    it "enforces max length on activities" do
      expect(build(:starter_initiative, activities: "a" * 1001)).not_to be_valid
    end

    it "enforces max length on expected_outcomes" do
      expect(build(:starter_initiative, expected_outcomes: "a" * 601)).not_to be_valid
    end

    it "enforces max length on next_step" do
      expect(build(:starter_initiative, next_step: "a" * 301)).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:ring) }
  end
end
