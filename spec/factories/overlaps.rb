FactoryBot.define do
  factory :overlap do
    association :ring_map
    association :ring_a, factory: :ring
    association :ring_b, factory: :ring
    shared_element  { "Families with school-age children living on the same block." }
    cross_ring_idea { "Organize a block-level school supply drive to bridge the neighborhood and education Rings." }
  end
end
