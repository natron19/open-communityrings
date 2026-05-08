FactoryBot.define do
  factory :ring_map do
    association :profile
    generated_at { Time.current }
    gemini_raw   { '{"rings":[],"overlaps":[],"starter_initiatives":[]}' }
  end
end
