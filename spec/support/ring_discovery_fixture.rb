module RingDiscoveryFixture
  VALID_RESPONSE = JSON.generate({
    rings: [
      { position: 1, name: "Cedar Street block",         ring_type: "neighborhood",      description: "Long-time and newer residents on the same walkable block.",    rationale: "You live here and already know several neighbors.",               is_priority: true  },
      { position: 2, name: "Lincoln Elementary parents", ring_type: "education",         description: "Parents and caregivers of kids at Lincoln Elementary.",         rationale: "Your kids attend this school and you know several other parents.", is_priority: true  },
      { position: 3, name: "Tuesday running club",       ring_type: "sports_recreation", description: "A weekly trail running group that meets on Tuesday mornings.",   rationale: "You joined last year and attend most weeks.",                     is_priority: false },
      { position: 4, name: "Remote engineering team",    ring_type: "workplace",         description: "A small distributed software team.",                            rationale: "You spend most of your working hours with this group.",           is_priority: false },
      { position: 5, name: "Extended family",            ring_type: "family",            description: "Immediate family and extended relatives across three states.",   rationale: "Family is a core Ring even when geographically distributed.",     is_priority: false }
    ],
    overlaps: [
      { ring_a_position: 1, ring_b_position: 2, shared_element: "Families with school-age children living on the same block.",    cross_ring_idea: "Organize a block-level school supply drive to bridge the neighborhood and school communities." },
      { ring_a_position: 1, ring_b_position: 3, shared_element: "A neighbor who runs the same Tuesday morning trails.",           cross_ring_idea: "Propose a neighborhood running meetup to bring the running club closer to the block community." }
    ],
    starter_initiatives: [
      { ring_position: 1, goal: "Host a small block gathering to introduce newer residents to long-time neighbors.", activities: "1. Reserve the block park\n2. Print and distribute flyers\n3. Ask long-time residents to share stories", expected_outcomes: "At least twelve households attend and three new connections form.", next_step: "Check the city park reservation portal this week." },
      { ring_position: 2, goal: "Join one Lincoln Elementary committee this semester.",                              activities: "1. Attend the next PTA meeting\n2. Volunteer for one committee\n3. Follow up with the committee chair",    expected_outcomes: "You know the committee members and have one task you can own.",           next_step: "Email the PTA chair to ask about upcoming meetings." }
    ]
  })
end
