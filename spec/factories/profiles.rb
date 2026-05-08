FactoryBot.define do
  factory :profile do
    association :user
    life_context     { "Mid-career developer in a walkable neighborhood, looking to be more rooted in the community after years of remote work." }
    family_situation { "Married with two school-age kids." }
    neighborhood     { "Older walkable neighborhood with a mix of long-time residents and newer arrivals." }
    work_occupation  { "Senior software engineer at a remote-first company." }
    interests        { "Trail running, board games, neighborhood history." }
    values           { "Civic life, public schools, local community, showing up." }
    weekly_hours     { 4 }
    known_rings      { "Cedar Street block, school PTA, local running club" }
  end
end
