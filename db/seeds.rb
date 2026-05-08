# Admin user — credentials for local demo use only
User.find_or_create_by!(email: "demo@example.com") do |u|
  u.name                  = "Demo User"
  u.password              = "password123"
  u.password_confirmation = "password123"
  u.admin                 = true
end

puts "Demo user: demo@example.com / password123"

# Health ping template — used by /up/llm
AiTemplate.find_or_create_by!(name: "health_ping") do |t|
  t.description          = "Minimal prompt used by the /up/llm health check endpoint."
  t.system_prompt        = "You are a health check endpoint. Respond with exactly: ok"
  t.user_prompt_template = "ping"
  t.model                = "gemini-2.5-flash"
  t.max_output_tokens    = 10
  t.temperature          = 0.0
  t.notes                = "Do not modify. Used by HealthController#llm."
end

puts "Seeded: health_ping AI template"

# ── AI Templates ──────────────────────────────────────────────────────────────

AiTemplate.find_or_create_by!(name: "ring_discovery_v1") do |t|
  t.description = "Generates a draft Ring map (5 to 9 Rings, Overlaps, and 2 Starter Initiatives) from a user's Profile."
  t.model = "gemini-2.5-flash"
  t.max_output_tokens = 3500
  t.temperature = 0.5

  t.system_prompt = <<~PROMPT.strip
    You are a community-mapping assistant. Your job is to help the user see the
    communities they already belong to and pick where to take ownership of their
    contribution. You do this once, from a Profile they fill out. You do not coach
    the user, you do not score the user, you do not assign the user tasks. You
    draft a map; the user is the owner.

    The Ring taxonomy has exactly fifteen types. Use only these:

    - family
    - neighborhood
    - civic
    - workplace
    - professional
    - faith_or_values
    - education
    - sports_recreation
    - arts_cultural
    - health_wellness
    - hobby_interest
    - online_digital
    - cause_based
    - service_volunteer
    - mentorship

    Voice and constraints, all of which are non-negotiable:

    - Plain, secular, warm. Never use religious language. If the user names a
      faith community in their Profile, classify the Ring as faith_or_values
      and describe it in plain civic language. Never quote scripture, never
      invoke deities, never use phrases like "called to serve" or "blessed
      community."
    - Owner not coach. When you describe a Ring's rationale or suggest an
      Initiative, use language of suggestion ("you might consider", "one
      option is", "a small experiment could be"), never of assignment ("you
      should", "your task is", "you must").
    - No scoring of the user. The Improvement Frame applies to Rings, not to
      people. Where a Ring is strong, the question is "how do we make it even
      better?". Where a Ring is weak, "how do we improve or change it?". The
      user is never the subject of an assessment.
    - No productivity-app jargon. Avoid "leverage", "optimize", "engage",
      "stakeholders", "synergies".
    - No invented people or places. Do not name specific neighbors, coworkers,
      or local businesses unless the user named them in the Profile.

    Generate five to nine Candidate Rings. Choose Rings that are clearly visible
    in the Profile; do not invent communities the user did not signal. Each Ring
    gets a name, a type (one of the fifteen above), a one-to-three sentence
    description, a one-sentence rationale on why this Ring belongs on the map,
    and a position from 1 to N. Mark exactly two Rings as is_priority based on
    the user's stated weekly_hours and values; choose Rings where a small amount
    of contribution would have visible effect.

    Generate Overlaps for any pair of Rings that share people, places, or
    purposes. There may be zero, two, or up to roughly seven Overlaps; do not
    manufacture overlaps where none exist. Each Overlap names the two Rings by
    position, identifies the shared_element in one sentence, and gives one
    cross_ring_idea (one sentence) for a service idea that would strengthen
    both Rings at once.

    Generate exactly one Starter Initiative per priority Ring (so two Initiatives
    total). Each Initiative has a goal in plain language, two to four activities
    listed on separate lines, a one-paragraph expected_outcomes sketch, and a
    single concrete next_step the user could take this week. Initiatives must
    fit inside the user's stated weekly_hours.

    You always respond with a single valid JSON object in the schema given in
    the user prompt. Do not wrap the JSON in markdown code fences. Do not
    include any prose before or after the JSON.
  PROMPT

  t.user_prompt_template = <<~PROMPT.strip
    PROFILE

    Life context:
    {{life_context}}

    Family situation:
    {{family_situation}}

    Neighborhood:
    {{neighborhood}}

    Work or main occupation:
    {{work_occupation}}

    Hobbies and interests:
    {{interests}}

    Values:
    {{values}}

    Weekly hours available for community contribution: {{weekly_hours}}

    Rings the user already knows they want on the map:
    {{known_rings}}

    Generate the user's Ring map and respond with a single JSON object in
    exactly this shape:

    {
      "rings": [
        {
          "position": 1,
          "name": "human-readable Ring name",
          "ring_type": "one of the fifteen taxonomy values",
          "description": "1 to 3 sentences",
          "rationale": "one sentence",
          "is_priority": false
        }
      ],
      "overlaps": [
        {
          "ring_a_position": 1,
          "ring_b_position": 3,
          "shared_element": "what these two Rings share",
          "cross_ring_idea": "one-sentence cross-Ring service idea"
        }
      ],
      "starter_initiatives": [
        {
          "ring_position": 1,
          "goal": "one-sentence goal in plain language",
          "activities": "1. First activity\n2. Second activity\n3. Third activity",
          "expected_outcomes": "one-paragraph sketch of what success looks like",
          "next_step": "one concrete action the user could take this week"
        }
      ]
    }

    Mark exactly two Rings as is_priority: true. Generate exactly one
    starter_initiative per priority Ring. Use ring positions, not names, to
    reference Rings inside overlaps and starter_initiatives.
  PROMPT

  t.notes = <<~NOTES.strip
    The hardest parts of this prompt are the constraints, not the content:
    - Exactly two priority Rings (the model occasionally produces three or one)
    - Exactly one Initiative per priority Ring
    - No religious language even when the user names a faith community
    - Five to nine Rings

    Watch for: Rings that are not really communities, overlaps that are
    coincidental, Initiatives that quietly assume more than weekly_hours.

    Known failure modes:
    - Short life_context with blank optional fields → generic Rings
    - known_rings longer than 600 characters → model may drop named Rings
    - Model occasionally invents specific people or places (forbidden)
  NOTES
end

puts "Seeded: ring_discovery_v1 AI template"

AiTemplate.find_or_create_by!(name: "overlap_regeneration_v1") do |t|
  t.description = "Regenerates the Overlaps for an existing RingMap after Ring edits."
  t.model = "gemini-2.5-flash"
  t.max_output_tokens = 1500
  t.temperature = 0.4

  t.system_prompt = <<~PROMPT.strip
    You are a community-mapping assistant. The user has already built their Ring
    map and has now edited, added, or dropped Rings. Your job is to look at the
    current Ring set and identify the Overlaps among them: pairs of Rings that
    share people, places, or purposes.

    The same voice and constraints apply as in initial discovery:
    - Plain, secular, warm. Never use religious language.
    - Owner not coach. Use language of observation, not assignment.
    - No invented people or places. Only refer to the elements the user has
      named in their Rings.
    - No productivity-app jargon.

    Identify the Overlaps among the Rings provided. There may be zero or up to
    roughly seven Overlaps depending on how the Rings cluster; do not manufacture
    overlaps where none exist. For each Overlap, name the two Rings by the
    position numbers given in the input, describe the shared_element in one
    sentence, and give one cross_ring_idea (one sentence) for a service idea
    that would strengthen both Rings at once.

    You always respond with a single valid JSON object in the schema given in
    the user prompt. Do not wrap the JSON in markdown code fences. Do not
    include any prose before or after the JSON.
  PROMPT

  t.user_prompt_template = <<~PROMPT.strip
    The user's current Ring set (each Ring is listed with its position, name,
    type, and description):

    {{rings_text}}

    Identify the Overlaps among these Rings and respond with a single JSON
    object in exactly this shape:

    {
      "overlaps": [
        {
          "ring_a_position": 1,
          "ring_b_position": 3,
          "shared_element": "what these two Rings share",
          "cross_ring_idea": "one-sentence cross-Ring service idea"
        }
      ]
    }

    Use the position numbers given above to reference Rings.
  PROMPT

  t.notes = <<~NOTES.strip
    Invoked when the user has changed their Ring set. Only Overlaps come back;
    Rings and Initiatives are not regenerated.

    Watch for: Overlaps referencing position numbers not in the current Ring
    set (the controller validates this and discards invalid overlaps).

    Known failure modes:
    - Zero overlaps returned when some clearly exist; re-running usually fixes it.
    - Fewer than three Rings often yields zero overlaps (correct).
  NOTES
end

puts "Seeded: overlap_regeneration_v1 AI template"

# ── Domain Seed: Sample Profile and Ring Map ───────────────────────────

demo_user = User.find_by(email: "demo@example.com")

unless demo_user&.profile
  profile = demo_user.create_profile!(
    life_context: "Mid-career software developer, married, two school-age kids, just moved to a smaller city after ten years in a big metro. Looking to be more rooted in a place than I have been in years.",
    family_situation: "Spouse works full time. Two kids, ages 8 and 11. Aging parents two states over.",
    neighborhood: "Older walkable neighborhood, mix of long-time residents and newer arrivals. Block has a small public park.",
    work_occupation: "Senior software engineer at a remote-first company. Work from home four days a week.",
    interests: "Trail running, board games with the kids, learning the cello very slowly, neighborhood history.",
    values: "Want my kids to grow up knowing their neighbors. Care about local civic life and public schools. Worry about how online-only people lose the practice of showing up.",
    weekly_hours: 4,
    known_rings: "Cedar Street block, the kids' elementary school PTA, the running club I joined last year"
  )

  ring_map = profile.ring_maps.create!(
    generated_at: Time.current,
    gemini_raw: JSON.generate({
      rings: [
        { position: 1, name: "Cedar Street block",         ring_type: "neighborhood",      description: "Long-time and newer residents sharing a walkable block with a small public park.",    rationale: "You live here and already know several neighbors by name.",                      is_priority: true  },
        { position: 2, name: "Lincoln Elementary parents", ring_type: "education",         description: "Parents and caregivers of kids at Lincoln Elementary, a walkable neighborhood school.", rationale: "Your kids attend this school and you recognize many parents at pickup.",            is_priority: true  },
        { position: 3, name: "Tuesday running club",       ring_type: "sports_recreation", description: "A weekly trail running group that meets on Tuesday mornings at the trailhead.",        rationale: "You joined last year and have attended most weeks.",                              is_priority: false },
        { position: 4, name: "Remote engineering team",    ring_type: "workplace",         description: "A small distributed software team spread across three time zones.",                   rationale: "You spend the majority of your working hours with this group.",                   is_priority: false },
        { position: 5, name: "Extended family",            ring_type: "family",            description: "Immediate family and extended relatives across three states.",                        rationale: "Family is a core Ring even when geographically distributed.",                    is_priority: false },
        { position: 6, name: "Cello learners group",       ring_type: "arts_cultural",     description: "A small group of adult beginners learning the cello together at the community arts center.", rationale: "One option worth considering: this group already shares a goal and meets regularly.", is_priority: false }
      ],
      overlaps: [
        { ring_a_position: 1, ring_b_position: 2, shared_element: "Families with school-age children who live on or near Cedar Street and send kids to Lincoln Elementary.", cross_ring_idea: "A block-level school supply drive would strengthen ties between neighbors and the school community at once." },
        { ring_a_position: 1, ring_b_position: 3, shared_element: "A neighbor on Cedar Street who runs the same Tuesday morning trails.",                                    cross_ring_idea: "Proposing a neighborhood running meetup could deepen both the block connection and the running club." },
        { ring_a_position: 2, ring_b_position: 4, shared_element: "A coworker whose child attends Lincoln Elementary.",                                                     cross_ring_idea: "Sharing PTA updates with that coworker could strengthen both workplace and school-community ties." }
      ],
      starter_initiatives: [
        { ring_position: 1, goal: "Host a small block gathering to introduce newer residents to long-time neighbors.", activities: "1. Reserve the block park for a Sunday afternoon\n2. Print and distribute flyers to twenty nearby households\n3. Ask two long-time residents to share one story about the block's history", expected_outcomes: "At least twelve households attend. Three new connections form between newer and longer-term residents. One follow-up idea emerges organically from the conversation.", next_step: "Check the city's park reservation portal this week and reserve a date two weeks out." },
        { ring_position: 2, goal: "Join one Lincoln Elementary committee this semester.", activities: "1. Attend the next PTA meeting\n2. Volunteer for one committee\n3. Follow up with the committee chair after the meeting", expected_outcomes: "You know the committee members by name and have one task you can own for the semester.", next_step: "Email the PTA chair to ask about the next meeting date and which committees need volunteers." }
      ]
    })
  )

  position_to_ring = {}
  [
    { pos: 1, name: "Cedar Street block",         type: "neighborhood",      desc: "Long-time and newer residents sharing a walkable block with a small public park.",    rat: "You live here and already know several neighbors by name.",                      priority: true  },
    { pos: 2, name: "Lincoln Elementary parents", type: "education",         desc: "Parents and caregivers of kids at Lincoln Elementary, a walkable neighborhood school.", rat: "Your kids attend this school and you recognize many parents at pickup.",            priority: true  },
    { pos: 3, name: "Tuesday running club",       type: "sports_recreation", desc: "A weekly trail running group that meets on Tuesday mornings at the trailhead.",        rat: "You joined last year and have attended most weeks.",                              priority: false },
    { pos: 4, name: "Remote engineering team",    type: "workplace",         desc: "A small distributed software team spread across three time zones.",                   rat: "You spend the majority of your working hours with this group.",                   priority: false },
    { pos: 5, name: "Extended family",            type: "family",            desc: "Immediate family and extended relatives across three states.",                        rat: "Family is a core Ring even when geographically distributed.",                    priority: false },
    { pos: 6, name: "Cello learners group",       type: "arts_cultural",     desc: "A small group of adult beginners learning the cello together at the community arts center.", rat: "One option worth considering: this group already shares a goal and meets regularly.", priority: false }
  ].each do |r|
    ring = ring_map.rings.create!(
      name: r[:name], ring_type: r[:type], description: r[:desc],
      rationale: r[:rat], is_priority: r[:priority],
      position: r[:pos], source: "ai_generated"
    )
    position_to_ring[r[:pos]] = ring
  end

  [
    { a: 1, b: 2, shared: "Families with school-age children who live on or near Cedar Street and send kids to Lincoln Elementary.", idea: "A block-level school supply drive would strengthen ties between neighbors and the school community at once." },
    { a: 1, b: 3, shared: "A neighbor on Cedar Street who runs the same Tuesday morning trails.",                                    idea: "Proposing a neighborhood running meetup could deepen both the block connection and the running club." },
    { a: 2, b: 4, shared: "A coworker whose child attends Lincoln Elementary.",                                                     idea: "Sharing PTA updates with that coworker could strengthen both workplace and school-community ties." }
  ].each do |o|
    ra = position_to_ring[o[:a]]
    rb = position_to_ring[o[:b]]
    a_id, b_id = [ra.id, rb.id].sort
    ring_map.overlaps.create!(ring_a_id: a_id, ring_b_id: b_id, shared_element: o[:shared], cross_ring_idea: o[:idea])
  end

  ring1 = position_to_ring[1]
  ring1.starter_initiatives.create!(
    goal: "Host a small block gathering to introduce newer residents to long-time neighbors.",
    activities: "1. Reserve the block park for a Sunday afternoon\n2. Print and distribute flyers to twenty nearby households\n3. Ask two long-time residents to share one story about the block's history",
    expected_outcomes: "At least twelve households attend. Three new connections form between newer and longer-term residents. One follow-up idea emerges organically from the conversation.",
    next_step: "Check the city's park reservation portal this week and reserve a date two weeks out."
  )

  ring2 = position_to_ring[2]
  ring2.starter_initiatives.create!(
    goal: "Join one Lincoln Elementary committee this semester.",
    activities: "1. Attend the next PTA meeting\n2. Volunteer for one committee\n3. Follow up with the committee chair after the meeting",
    expected_outcomes: "You know the committee members by name and have one task you can own for the semester.",
    next_step: "Email the PTA chair to ask about the next meeting date and which committees need volunteers."
  )

  puts "✓ Sample Ring map seeded for demo@example.com"
end
