FactoryBot.define do
  factory :starter_initiative do
    association :ring
    goal              { "Host a small block gathering to introduce newer residents to long-time neighbors." }
    activities        { "1. Reserve the block park for a Sunday afternoon\n2. Print and distribute flyers to twenty nearby households\n3. Ask two long-time residents to share one story about the block's history" }
    expected_outcomes { "At least twelve households attend. Three new connections are made between newer and longer-term residents. One follow-up idea emerges organically from the conversation." }
    next_step         { "Check the city's park reservation portal this week and reserve a date two weeks out." }
  end
end
