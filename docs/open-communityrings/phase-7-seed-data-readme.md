# Phase 7: Seed Data & README

**Goal:** Add a fully-populated sample Profile and RingMap to `db/seeds.rb` so the demo renders a meaningful Ring map on first boot without spending a Gemini call. Update the README with the CommunityRings-specific sections. After this phase the repo is ready to open-source.

---

## Files to Modify

| Action | File |
|---|---|
| Modify | `db/seeds.rb` |
| Modify | `README.md` |

---

## 1. Domain Seeds — `db/seeds.rb`

Append to `db/seeds.rb` after the AI template seeds from Phase 4. This creates a sample Profile and Ring map belonging to the seeded admin user (`demo@example.com`), using `find_or_create` guards so re-seeding is safe.

```ruby
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

  # Create Rings
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

  # Create Overlaps (canonicalize: smaller UUID → ring_a_id)
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

  # Create StarterInitiatives for priority rings
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
```

Run `rails db:seed` to verify. After seeding, signing in as `demo@example.com` / `password123` should show the Ring map immediately at the dashboard with no Gemini call needed.

---

## 2. README Updates

Add the following sections to `README.md`, after the boilerplate's standard Stack, Setup, License, and About the Author sections.

### App description block

```markdown
# CommunityRings Demo

> Map your communities. See where they overlap. Pick where to serve.

CommunityRings Demo is a single-feature open source Rails 8 app that helps a
person see all of the communities they belong to at once and pick where to
take ownership of their contribution. You fill out a short Profile (life
context, family, neighborhood, work, hobbies, values, weekly hours available).
One AI call returns a draft Ring map: 5 to 9 communities you already belong to,
the overlaps among them, and a small starter initiative for each of two priority
Rings. You edit aggressively; the AI drafts, you pick. It is the Ring Discovery
engine from the larger CommunityRings platform, sliced out as a runnable demo.
```

### Screenshot placeholder

```markdown
## Screenshot

[Screenshot of the Ring map view — the hand-drawn SVG cluster with amber overlap
regions, the Ring list, the Overlap card, and the Starter Initiatives section.
Replace this placeholder once the README is live in the repo.]
```

### Why I built this

```markdown
## Why I built this

I am building a multi-tenant SaaS suite of community-first tools. The production
CommunityRings is multi-tenant, supports shared Rings across a household or
congregation or civic association, tracks Ring health across the Three Pillars
(Connecting, Learning, Co-Creating), and integrates with the rest of the suite.
This open source demo is one tool from that suite, sliced thin so anyone can
clone it, run it, and inspect how the discovery engine actually works.

If you are an adult who has decided that showing up to the communities you care
about is not the same as contributing, and you want a map of your Rings instead
of a marketplace of strangers' projects, this demo is the smallest possible
artifact that lets you feel the shape of the idea.

This demo is open source under the MIT license. Fork it, run it, change the
prompt in the admin UI, see what it does to the output.
```

### Editable AI prompts note

```markdown
## Editable AI prompts

The AI prompts for this demo are editable in `/admin/ai_templates`. Sign in as
the seeded admin user (`demo@example.com` / `password123`), navigate to the
admin panel from the user dropdown, and click on `ring_discovery_v1` or
`overlap_regeneration_v1`. Use the Test panel on the right to sanity-check
changes before saving.

The voice rules in the system prompt (owner not coach, no religious language,
no productivity jargon, no inventing people or places) are the most opinionated
thing in the demo. If you change them, you change what the demo is. That is
fine; it is your fork.
```

### Demo credentials section

```markdown
## Demo credentials

| Field | Value |
|---|---|
| Email | `demo@example.com` |
| Password | `password123` |
| Admin | yes |

After running `bin/setup` and `rails db:seed`, sign in with these credentials
to see a pre-populated Ring map without spending a Gemini API call.
```

---

## Manual Test Checklist

After completing Phase 7:

- [ ] `rails db:seed` completes without errors
- [ ] Signing in as `demo@example.com` / `password123` shows the Ring map at the dashboard immediately (no Gemini call)
- [ ] The seeded map has 6 Rings, 3 Overlaps, and 2 Starter Initiatives
- [ ] All Ring types show correct labels (e.g., "Arts & Culture" not "arts_cultural")
- [ ] The SVG renders all 6 Ring shapes with 3 overlap lenses
- [ ] Running `rails db:seed` a second time does not duplicate the sample data
- [ ] README contains the app name, tagline, demo credentials, and editable prompts note
- [ ] `bundle exec rspec` — full suite still passes
- [ ] A fresh clone + `bin/setup` + `rails db:seed` + sign-in produces the working demo
