class StarterInitiative < ApplicationRecord
  belongs_to :ring

  validates :goal, presence: true, length: { minimum: 10, maximum: 300 }
  validates :activities, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :expected_outcomes, presence: true, length: { minimum: 10, maximum: 600 }
  validates :next_step, presence: true, length: { minimum: 10, maximum: 300 }
end
