FactoryBot.define do
  factory :ring do
    association :ring_map
    sequence(:name)     { |n| "Ring #{n}" }
    ring_type           { "neighborhood" }
    description         { "A community of neighbors on the same block who know each other by name." }
    rationale           { "You live here and already know several neighbors." }
    is_priority         { false }
    sequence(:position) { |n| n }
    source              { "ai_generated" }

    trait :priority do
      is_priority { true }
    end

    trait :user_added do
      source { "user_added" }
    end
  end
end
