# CommunityRings Demo - Spec Document

**Document Version:** 1.0
**Built On:** Open Demo Starter v2.0
**License:** MIT
**Accent Color:** `#a3501f` (terracotta) | Secondary: `#15803d` (forest green) | Overlap accent: `#f59e0b` (amber)
**UX Pattern:** Profile form plus Ring map with overlap visualization

---

## 1. App Overview

CommunityRings Demo is a single-feature open source Rails 8 app that helps a person see all of the communities they belong to at once and pick where to take meaningful ownership of their contribution. The user fills out a short Profile (life context, family situation, neighborhood, work, hobbies, values, weekly hours available, and any communities they already know they want on the map). One Gemini call then returns a draft Ring map: five to nine Candidate Rings drawn from a guided taxonomy, the Overlaps among those Rings, and a small Starter Initiative for each of two priority Rings. The user edits, drops, and adds Rings as needed, and can regenerate the Overlaps after edits.

The problem this addresses is structural. Most civic and volunteer tools start from a marketplace of opportunities and ask the user to pick from a list of strangers' projects. CommunityRings inverts the model: it starts from the communities the user is already inside and helps them take ownership of how they contribute to each one. The Three Pillars framework (Connecting, Learning, Co-Creating) is the discipline applied inside every Ring in the production app, but the entry point is the Ring map itself; this demo shows the Ring Discovery engine that produces that map.

This demo is one tool from a larger multi-tenant SaaS suite the author is building. The production version is multi-tenant with team collaboration, supports shared Rings across a household or congregation or civic association, tracks Ring health over time, and integrates with the rest of the suite. This open source version is single-user, runs locally, stores everything in PostgreSQL, and exists to make the core insight inspectable, runnable, and forkable in under thirty minutes.

Open source under MIT license. Scoped to a single signed-in user. Runs on localhost.

---

## 2. Customizations Applied to the Boilerplate

The following items diverge from the Open Demo Starter v2.0 defaults:

- `APP_NAME` set to `CommunityRings Demo` in `.env.example` and `.env`
- `APP_TAGLINE` set to `Map your communities. See where they overlap. Pick where to serve.`
- `APP_DESCRIPTION` set to a one-paragraph version of Section 1
- Accent color set to `#a3501f` (terracotta) with `--accent-hover` of `#7c3a16` in `app/assets/stylesheets/_accent.scss`. Two additional CSS custom properties added in the same file: `--secondary-accent: #15803d` (forest green) and `--overlap-accent: #f59e0b` (amber)
- Navbar gets two new links visible to signed-in users: `My Map` (the Ring map dashboard) and `My Profile`. The `Dashboard` link from the boilerplate is renamed to `My Map`
- `home/index.html.erb` replaced with the CommunityRings Demo landing pitch: a hero with the tagline, a three-card explainer of the discovery flow (Profile, Map, Initiatives), a sample Ring map screenshot placeholder, and a sign-up call to action
- `dashboard/show.html.erb` replaced with a router view that renders one of three states: the most recent Ring map if one exists, a "Run Ring Discovery" empty state if a Profile exists but no map exists, or a "Build your Profile" empty state if no Profile exists
- UX pattern selected: profile form plus Ring map with overlap visualization (described in detail in Section 6)
- AI templates seeded into `db/seeds.rb`: `ring_discovery_v1` and `overlap_regeneration_v1` (full content in Section 7)
- Five new domain models (Section 3)
- Three new controllers (Section 5)
- Two custom Stimulus controllers (`ring_map_controller.js` for the SVG hand-drawn rendering, `priority_toggle_controller.js` for the inline priority button)
- A custom helper module (`ring_helpers.rb`) that maps a `ring_type` string to a human-readable label and to a Bootstrap variant for badges
- A custom partial (`shared/_ai_error.html.erb`) is already provided by the boilerplate; this demo adds `shared/_ring_taxonomy.html.erb` (a small reference card the Profile form links out to in a Bootstrap collapse)

---

## 3. Data Model

Five new models on top of `User`, `AiTemplate`, and `LlmRequest` from the boilerplate.

### Profile

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `user_id` | uuid | Foreign key. `belongs_to :user`. Unique (one Profile per user) |
| `life_context` | text | Required. One paragraph on the user's broad situation (career stage, life stage, recent transitions) **(template variable: life_context)** |
| `family_situation` | text | Optional. Household composition, dependents, caregiving responsibilities **(template variable: family_situation)** |
| `neighborhood` | text | Optional. Where the user lives, type of place (urban, suburban, rural), how long they have been there **(template variable: neighborhood)** |
| `work_occupation` | text | Optional. What the user does for work or main occupation **(template variable: work_occupation)** |
| `interests` | text | Optional. Hobbies, recreational pursuits, online communities **(template variable: interests)** |
| `values` | text | Optional. What the user cares about contributing toward (causes, places, kinds of people) **(template variable: values)** |
| `weekly_hours` | integer | Required. Hours per week the user can realistically spend on community contribution. Range 1 to 40 **(template variable: weekly_hours)** |
| `known_rings` | text | Optional. A free-text list of Rings the user already knows they want on the map **(template variable: known_rings)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Validations: `life_context` presence and length 30 to 1500, `weekly_hours` presence and inclusion in 1..40, `family_situation`/`neighborhood`/`work_occupation`/`interests`/`values`/`known_rings` length up to 1500 each (presence not required). Uniqueness of `user_id`.

Associations: `has_many :ring_maps, dependent: :destroy`.

### RingMap

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `profile_id` | uuid | Foreign key. `belongs_to :profile` |
| `generated_at` | datetime | When the Gemini Ring Discovery call completed successfully |
| `overlaps_regenerated_at` | datetime | Nullable. When `overlap_regeneration_v1` was last run on this map |
| `gemini_raw` | text | **(Gemini output, used for Show raw response toggle)**. The full JSON string from `ring_discovery_v1` |
| `gemini_raw_overlaps` | text | Nullable. The full JSON string from the most recent `overlap_regeneration_v1` call, if any |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Validations: `generated_at` presence.

Associations: `has_many :rings, dependent: :destroy`. `has_many :overlaps, dependent: :destroy`. `has_one :user, through: :profile`. Default scope orders by `generated_at desc`.

### Ring

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `ring_map_id` | uuid | Foreign key. `belongs_to :ring_map` |
| `name` | string | Required. The Ring's display name (e.g., "Cedar Street neighbors") |
| `ring_type` | string | One of fifteen taxonomy values listed in Section 7 |
| `description` | text | Required. One to three sentences on what this Ring is and who is in it |
| `rationale` | text | Required. One sentence on why this Ring belongs on the user's map. Generated by AI on discovery, editable by user |
| `is_priority` | boolean | Default false. The user marks two Rings as priority initially (AI suggests two; user can change) |
| `position` | integer | The 1-indexed display order on the Ring map. Used by the SVG layout |
| `source` | string | One of `ai_generated` or `user_added`. Tracks whether this Ring came from Discovery or was added by the user manually |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Validations: `name` presence and length 2 to 80, `ring_type` inclusion in the taxonomy, `description` presence and length 10 to 1500, `rationale` presence and length 10 to 500, `position` presence and uniqueness scoped to `ring_map_id`, `source` inclusion in `%w[ai_generated user_added]`.

Associations: `has_many :starter_initiatives, dependent: :destroy`. `has_many :overlaps_as_a, class_name: "Overlap", foreign_key: :ring_a_id, dependent: :destroy`. `has_many :overlaps_as_b, class_name: "Overlap", foreign_key: :ring_b_id, dependent: :destroy`. Default scope orders by `position asc`.

### Overlap

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `ring_map_id` | uuid | Foreign key. `belongs_to :ring_map` |
| `ring_a_id` | uuid | Foreign key to Ring. The first Ring in the pair |
| `ring_b_id` | uuid | Foreign key to Ring. The second Ring in the pair |
| `shared_element` | text | Required. What the two Rings share (people, places, or purposes) |
| `cross_ring_idea` | text | Required. One sentence on a service idea that would strengthen both Rings at once |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Validations: `shared_element` presence, `cross_ring_idea` presence, `ring_a_id` and `ring_b_id` cannot be equal, the pair `(ring_a_id, ring_b_id)` must be unique within a `ring_map_id` (canonicalized: store the smaller UUID as `ring_a_id` for deterministic uniqueness).

### StarterInitiative

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `ring_id` | uuid | Foreign key. `belongs_to :ring` |
| `goal` | text | Required. One sentence on what this Initiative aims to do, in plain language |
| `activities` | text | Required. Two to four activities, stored as a newline-delimited list |
| `expected_outcomes` | text | Required. A short sketch of what success would look like, in plain language |
| `next_step` | text | Required. The single concrete next action the user could take this week |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Validations: all four text fields presence, `goal` length 10 to 300, `activities` length 10 to 1000, `expected_outcomes` length 10 to 600, `next_step` length 10 to 300.

Associations: `belongs_to :ring`. Indirectly belongs to `ring_map` and `user` through the parent Ring.

All Profile, RingMap, Ring, Overlap, and StarterInitiative queries are scoped via the user's Profile. RingMap is loaded as `current_user.profile.ring_maps`; Rings, Overlaps, and StarterInitiatives are reached only through their parent RingMap, so user scoping is enforced by always loading the parent first.

---

## 4. Routes

| Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/profile` | `profiles#show` | View own Profile |
| GET | `/profile/edit` | `profiles#edit` | Edit Profile (also serves as the new-Profile form when no Profile exists yet) |
| POST | `/profile` | `profiles#create` | Create the Profile |
| PATCH | `/profile` | `profiles#update` | Update the Profile |
| POST | `/ring_maps` | `ring_maps#create` | Trigger Ring Discovery; persists a new RingMap |
| GET | `/ring_maps/:id` | `ring_maps#show` | View a specific RingMap |
| DELETE | `/ring_maps/:id` | `ring_maps#destroy` | Delete a RingMap and its children |
| POST | `/ring_maps/:id/regenerate_overlaps` | `ring_maps#regenerate_overlaps` | Trigger `overlap_regeneration_v1` after Ring edits |
| POST | `/ring_maps/:id/rings` | `rings#create` | Add a Ring manually to an existing RingMap |
| PATCH | `/rings/:id` | `rings#update` | Edit a Ring (rename, change type, edit description) |
| DELETE | `/rings/:id` | `rings#destroy` | Drop a Ring from the map |
| PATCH | `/rings/:id/toggle_priority` | `rings#toggle_priority` | Mark or unmark as priority (no AI call) |

Notes:

- Profile is a singleton resource per user; no `/profiles` index, no `/profiles/:id`. The path is `/profile` (singular).
- All HTML responses. The `ring_maps#create` and `ring_maps#regenerate_overlaps` actions redirect on success and re-render with an inline alert on Gemini failure.
- `rings#toggle_priority`, `rings#update`, and `rings#destroy` use Turbo Streams to update the Ring map and the Ring list inline without a full-page reload. The other Ring map updates (`rings#create`) also use Turbo Streams.
- `dashboard/show` from the boilerplate is overridden to render whichever of the three router states applies (no Profile, no Map, or latest Map).

---

## 5. Controllers and Actions

### `ProfilesController`

The user's Profile is a prerequisite for Ring Discovery. Strong params permit all Profile fields except `user_id`.

- `show`: Loads `current_user.profile`. Renders the read-only Profile view with an Edit button. Redirects to `profiles#edit` if no Profile exists yet.
- `edit`: Renders the Profile form. Used both for first-time creation (when `current_user.profile` is nil and a fresh Profile is built) and for editing (when one exists).
- `create`: Builds and saves the Profile under `current_user`. On success, redirects to the dashboard, where the user will see a "Run Ring Discovery" call to action.
- `update`: Saves Profile edits. On success, redirects to `profiles#show`.

No Gemini calls in this controller.

### `RingMapsController`

The controller that triggers AI calls.

- `create`: Loads `current_user.profile` (404 if missing). Builds a fresh `RingMap` and triggers Ring Discovery:

```
result = GeminiService.generate(
  template: "ring_discovery_v1",
  variables: {
    life_context: profile.life_context,
    family_situation: profile.family_situation.to_s,
    neighborhood: profile.neighborhood.to_s,
    work_occupation: profile.work_occupation.to_s,
    interests: profile.interests.to_s,
    values: profile.values.to_s,
    weekly_hours: profile.weekly_hours.to_s,
    known_rings: profile.known_rings.to_s
  }
)
```

The returned JSON is parsed and persisted in a single transaction: the RingMap, its Rings (with `source: "ai_generated"` and ascending `position`), its Overlaps (using the position-to-Ring mapping built during the same transaction), and one StarterInitiative per Ring the AI marked as `is_priority`. The full JSON string is stored in `gemini_raw`. On success, redirects to `ring_maps#show`.

- `show`: Loads the RingMap (scoped to `current_user.profile.ring_maps`) and renders the Ring map view. Eager-loads `rings`, `overlaps`, and `rings.starter_initiatives` to avoid N+1 queries.
- `destroy`: Deletes the RingMap (cascades to Rings, Overlaps, and StarterInitiatives). Redirects to the dashboard.
- `regenerate_overlaps`: Loads the RingMap, calls `overlap_regeneration_v1` with the current Ring set as input, deletes existing Overlaps inside a transaction, and persists the new ones. The full JSON is stored in `gemini_raw_overlaps` and `overlaps_regenerated_at` is updated. On success, redirects back to `ring_maps#show` with a flash. StarterInitiatives are NOT touched by regeneration.

Both AI-calling actions wrap the Gemini call in `rescue GeminiService::GeminiError => e` and render the boilerplate's shared `_ai_error.html.erb` partial inline. Specific subclasses (`BudgetExceededError`, `GatekeeperError`, `TimeoutError`) get specific copy. A failed JSON parse is also caught: the `LlmRequest` log already exists, but no domain records are persisted, and the user sees a "We could not parse the response, please try again" message with a retry button.

### `RingsController`

All actions scope through the parent RingMap to enforce user ownership.

- `create`: Adds a manually-entered Ring to a RingMap. The user supplies name, type, description, and rationale. Sets `source: "user_added"` and assigns the next available `position`. No Gemini call. Renders a Turbo Stream that appends the Ring to the list and re-draws the SVG map.
- `update`: Edits Ring fields inline. No Gemini call. Renders a Turbo Stream that replaces the Ring's row and re-draws the SVG map if the Ring's name or position changed.
- `destroy`: Removes a Ring. Cascades to the Ring's StarterInitiatives and to any Overlaps that reference this Ring. Renders a Turbo Stream that removes the Ring's row and re-draws the SVG map. After a destroy, the user often wants to regenerate Overlaps; the flash includes a "Regenerate overlaps" link.
- `toggle_priority`: Flips `is_priority` on the Ring. No Gemini call. Renders a Turbo Stream that updates the priority badge and the priority list. Note: toggling priority does NOT generate a new StarterInitiative; the existing Initiatives remain attached to whichever Rings they were generated for. Section 8 explains this design choice.

---

## 6. Views

All views inherit the boilerplate's application layout, dark mode, navbar, flash container, and footer disclaimer.

### `home/index.html.erb` (replaces boilerplate landing)

- Hero: app name, tagline, single primary CTA "Build your Ring map"
- Three explainer cards in a row: "1. Build a Profile" (what you tell us), "2. See your map" (what we generate), "3. Pick where to serve" (what you do next)
- Sample Ring map screenshot placeholder
- A footer call to action linking to sign up

### `dashboard/show.html.erb` (replaces boilerplate dashboard)

A router view with three branches:

- If `current_user.profile` is nil: render an empty state card with a single CTA "Build your Profile" linking to `/profile/edit`
- Else if `current_user.profile.ring_maps` is empty: render an empty state card showing the Profile summary and a single CTA "Run Ring Discovery" that POSTs to `/ring_maps`. A Bootstrap spinner and a 15-second-bounded loading state appear while the call is in flight
- Else: render the most recent RingMap inline (same layout as `ring_maps#show`)

### `profiles/show.html.erb` and `profiles/edit.html.erb`

- `show`: A read-only view of all Profile fields with an Edit button. Empty optional fields show as "Not provided" in muted text
- `edit`: A Bootstrap form with floating labels for the short fields and large textareas for the longer fields. Inline help text under each field showing what makes a useful entry. A Bootstrap collapse below the form, "What kinds of communities count?", reveals the `shared/_ring_taxonomy.html.erb` partial listing the fifteen Ring types with one-sentence definitions
- Validation errors render inline as Bootstrap invalid-feedback under each field
- Save button uses `--accent`

### `ring_maps/show.html.erb`

This is the demo's hero view. The layout from top to bottom:

1. **Header strip.** "Your Ring Map" with the `generated_at` timestamp, an "Updated overlaps" timestamp if `overlaps_regenerated_at` is present, a "Regenerate overlaps" button (visible only when at least one Ring has been edited or added since the last overlap generation), and a "Delete this map" icon button.

2. **The Ring map (the SVG).** A roughly 800 by 600 px SVG rendered by `ring_map_controller.js`. Each Ring is drawn as a hand-drawn-feeling closed shape (a circle with deliberate jitter applied to its perimeter via Stimulus) sized roughly proportional to the user's stated involvement (the Stimulus controller picks sizes within a constrained range; a bigger Ring is not "more important", it is "more present in the user's life"). Rings are arranged in a soft cluster using a simple force layout encoded inline in the controller (no third-party graph library). Where two Rings overlap (because the data says they share an Overlap row), the controller renders the intersection as an amber-filled lens shape. The Ring's name is rendered as a small label inside its perimeter; on hover, a Bootstrap tooltip shows the Ring's `description` and `rationale`.

3. **The Ring list.** Below the SVG, a vertical list-group of all Rings on the map. Each row shows: position number, Ring name, Ring type badge (color-coded by type via `ring_helpers.rb`), short description, AI rationale in muted text, a "Mark as priority" toggle button (filled terracotta when active), an Edit icon, and a Delete icon. Inline editing is a Turbo Frame: clicking Edit replaces the row with a small form. An "Add a Ring" button at the bottom of the list opens a Turbo Frame form.

4. **The Overlap list.** A separate Bootstrap card titled "Overlaps". Each Overlap row shows: the two Ring names connected by a thin terracotta horizontal line with an amber dot at its midpoint (pure CSS, no SVG here); below the line, the `shared_element` text in muted color; and below that, the `cross_ring_idea` rendered in regular weight as an indented suggestion. The card header has the "Regenerate overlaps" button (duplicated from the header strip for visibility).

5. **The Starter Initiatives section.** A third card titled "Starter Initiatives". Initiatives are grouped under their parent Ring (a small subheader for each priority Ring with that Ring's name and type badge). Each StarterInitiative renders as a Bootstrap card with a slightly off-white note-card background tint and four labeled cells: Goal, Activities (rendered as a numbered list), Expected Outcomes, and Next Step. The Next Step cell is given a left-border in `--secondary-accent` (forest green) to draw the eye to the single concrete action.

6. **Show raw response toggle.** A Bootstrap collapse element labeled "Show raw response (advanced)". When opened, reveals two stacked `<pre>` blocks with the contents of `gemini_raw` and `gemini_raw_overlaps` (the second one shown only if present). Each block is labeled with the template name and the timestamp.

7. **Footer actions.** Two buttons: "Edit my Profile" (links to `profiles/edit`) and "Start a fresh map" (POSTs to `/ring_maps` to generate a new map; a confirmation dialog warns that the current map will not be deleted but will no longer be the latest).

The `ring_map_controller.js` Stimulus controller listens for `ring:added`, `ring:updated`, `ring:removed`, and `overlap:replaced` custom events fired by Turbo Stream responses, and re-renders the SVG when any of them fire. The hand-drawn jitter is deterministic per Ring (seeded by the Ring's UUID) so the shape stays stable across re-renders.

### Tone of voice in copy

The interface uses owner-not-coach voice across all views. Buttons use plain verbs ("Build", "Run", "Add", "Edit", "Drop", "Mark as priority"). Empty states use second-person observational sentences ("You have not built a Profile yet"). The system never tells the user how they are doing as a community member. There are no streaks, no reminders, no nudges, no scoring of the user. There is no religious language anywhere in the UI, even when the user has named a faith community in `known_rings`.

---

## 7. AI Templates and Gemini Integration

This demo seeds **two** AiTemplates. The full records are below.

### Template `ring_discovery_v1`

**Description:** Generates a draft Ring map from a user's Profile: five to nine Candidate Rings drawn from the fifteen-type taxonomy, the Overlaps among them, and one Starter Initiative for each of two Rings the model marks as priority.

**System prompt:**

```
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
```

**User prompt template:**

```
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
```

**Variables consumed:**

- `{{life_context}}`: from `Profile.life_context`
- `{{family_situation}}`: from `Profile.family_situation` (empty string if blank)
- `{{neighborhood}}`: from `Profile.neighborhood` (empty string if blank)
- `{{work_occupation}}`: from `Profile.work_occupation` (empty string if blank)
- `{{interests}}`: from `Profile.interests` (empty string if blank)
- `{{values}}`: from `Profile.values` (empty string if blank)
- `{{weekly_hours}}`: from `Profile.weekly_hours`
- `{{known_rings}}`: from `Profile.known_rings` (empty string if blank)

**Model:** `gemini-2.0-flash` (default).

**`max_output_tokens`:** 3500. Higher than the boilerplate default of 2000 because the response includes up to nine Rings (each with name, type, description, rationale), up to seven Overlaps (each with two text fields), and two full Initiatives (each with four text fields including a multi-line activities list). A populated map can run 2500 to 3000 tokens.

**`temperature`:** 0.5. Lower than the boilerplate default of 0.7 because the output is structured JSON with strict schema requirements and a fixed taxonomy. Higher than 0.3 because the rationales, cross-ring ideas, and Initiative goals benefit from some creative variation; the user is doing the picking, not the model.

**Author's notes (`notes` field):**

```
The hardest parts of this prompt are the constraints, not the content:
- Exactly two priority Rings (the model occasionally produces three or one)
- Exactly one Initiative per priority Ring (the model sometimes produces
  multiple, or zero, especially when one of the priority Rings is sparse)
- No religious language even when the user names a faith community
- Five to nine Rings (the model sometimes produces four or eleven)

Watch for: Rings that are not really communities ("my morning routine"),
overlaps that are coincidental rather than substantive ("both involve
walking"), Initiatives that quietly assume more than the user's
weekly_hours.

Known failure modes:
- If life_context is short and most optional fields are blank, the model
  produces generic Rings ("workplace", "neighbors"). The Profile form's
  helper text nudges the user toward specifics.
- If the user's known_rings field lists more than nine Rings, the model
  sometimes drops Rings the user explicitly named. The controller logs a
  warning when known_rings is longer than 600 characters.
- The model occasionally invents specific people or places ("your
  neighbor Maria"). The system prompt forbids this, but it is the most
  common voice violation; fix in seeded data and re-test if observed.
```

**Where it's called:** `RingMapsController#create` invokes
`GeminiService.generate(template: "ring_discovery_v1", variables: {...})`.

**Expected output format:** A single JSON object with the schema shown above.

**How the response is parsed and rendered:** `RingMapsController#create` parses the JSON with `JSON.parse`. On parse failure, the user sees a friendly retry. On success, in a single transaction, the controller creates the RingMap, then creates Rings (mapping the `position` field through), then resolves `ring_a_position` and `ring_b_position` to the actual Ring UUIDs (canonicalizing the smaller UUID into `ring_a_id`) and creates Overlaps, then creates StarterInitiatives by resolving `ring_position` to the appropriate Ring UUID. The full JSON string is stored in `gemini_raw`.

**Which domain field stores the raw response:** `ring_maps.gemini_raw`.

---

### Template `overlap_regeneration_v1`

**Description:** Regenerates the Overlaps for a RingMap after the user has edited, added, or dropped Rings. Takes the current Ring set as input and returns only Overlaps; does not generate Rings or Initiatives.

**System prompt:**

```
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
```

**User prompt template:**

```
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
```

**Variables consumed:**

- `{{rings_text}}`: a server-built string assembled by `RingMapsController#regenerate_overlaps` from the current Rings, formatted as `Position N. NAME (TYPE): DESCRIPTION` on separate lines, joined by newlines

**Model:** `gemini-2.0-flash` (default).

**`max_output_tokens`:** 1500. Smaller than the discovery default because the output is just Overlaps (no Rings, no Initiatives). A typical regeneration produces fewer than 1000 tokens.

**`temperature`:** 0.4. Slightly higher than discovery JSON-only sub-prompts but still lower than boilerplate default; the cross-ring ideas need some creativity, but the structure is rigid.

**Author's notes (`notes` field):**

```
This template is invoked when the user has changed their Ring set since the
last discovery. It is intentionally narrow: only Overlaps come back. Rings
and Initiatives are not regenerated; the user owns those edits.

Watch for: Overlaps that reference position numbers not in the current Ring
set (the controller validates this and discards invalid overlaps).

Known failure modes:
- The model sometimes produces zero Overlaps when there are clearly some;
  re-running usually fixes it. The user can re-trigger.
- If the user has fewer than three Rings, Overlaps are often genuinely
  zero, and the empty result is correct.
```

**Where it's called:** `RingMapsController#regenerate_overlaps` invokes
`GeminiService.generate(template: "overlap_regeneration_v1", variables: { rings_text: ... })`.

**Expected output format:** A single JSON object with one top-level key, `overlaps`, identical in shape to the `overlaps` array in `ring_discovery_v1`.

**How the response is parsed and rendered:** `RingMapsController#regenerate_overlaps` parses the JSON, validates that each `ring_a_position` and `ring_b_position` resolves to a Ring on this RingMap, deletes the existing Overlaps in a transaction, creates new ones (canonicalizing the smaller UUID as `ring_a_id`), and updates `overlaps_regenerated_at` and `gemini_raw_overlaps` on the RingMap.

**Which domain field stores the raw response:** `ring_maps.gemini_raw_overlaps`.

This demo does not use Gemini's function calling. Two single-shot calls only.

---

## 8. AI Safety Considerations (Specific to This App)

Beyond the boilerplate's gatekeeper, budget cap, request log, timeout, and raw response toggle, the following considerations apply to this demo specifically.

**Content sensitivity.** Medium. The Profile contains personal information: family situation, neighborhood, values, hobbies. None of this is regulated data (no health diagnoses, no financial records, no protected-class designations beyond what the user volunteers), and the demo is local, single-user, and never transmits Profile data anywhere except to Gemini. The `LlmRequest` log records token counts and durations but not full prompts or responses by default; the admin user (the demo's author) can see prompts and responses by clicking through to a single request. The demo's README warns the user that everything they type goes to Gemini.

**Consequential outputs.** Low to medium. A user acting on the AI's Ring map might mis-identify which community to invest in, or run an Initiative that lands poorly inside a Ring whose dynamics the model misread. Worst case is wasted personal time or a slightly awkward initiative; not harm to a third party. The mitigation is the explicit owner-not-coach framing throughout the UI: the AI drafts, the user picks. Every Ring is editable; every Initiative is presented as a candidate to take, edit, or reject.

**Domain accuracy requirements.** The fifteen-type Ring taxonomy is normative, not empirical. Reasonable people will disagree about whether a particular community is `civic` or `cause_based`, or whether two Rings genuinely overlap. The output is interpretive and the show page makes that explicit: a small inline note above the Ring list reads "Ring types and overlaps are AI interpretations; rename, retype, or drop anything that does not match how you see your communities."

**App-specific disclaimer copy.** In addition to the boilerplate footer note, the Ring map view renders a small italic line directly under the SVG: "This is a draft to argue with, not a verdict to follow." This is consistent with the demo's voice; a person reading it should feel invited to edit aggressively.

**Tightened settings.** None justified. The default per-user daily call cap (50) is generous for a single user iterating on their map; even a heavy session of "edit, regenerate overlaps, edit, regenerate again" would not approach 50. The 15-second timeout is sufficient for `gemini-2.0-flash` on a typical Profile. The temperatures are already lowered (0.5 for discovery, 0.4 for regeneration) for output structure consistency, not for safety.

**What this demo deliberately does NOT do (for safety reasons).**

- It does not score the user as a community member. The Improvement Frame applies to Rings, not to people. Nowhere in the UI or the AI output does the system tell the user how they are doing.
- It does not prescribe Initiatives. Every Initiative is a candidate. The AI uses suggestion language ("you might consider", "one option is"), and the UI renders Initiatives as note-cards, not assignments.
- It does not use religious framing, ever. The system prompt explicitly excludes religious language even when a user names a faith community. The Ring is named for what it is; the discipline applied to it is secular and civic.
- It does not share data across users. Profiles, RingMaps, Rings, Overlaps, and Initiatives are scoped to the signed-in user. There is no public profile, no aggregate benchmarking, no cross-user insights. Aggregate features are a v2 concept gated behind explicit opt-in in the production app and are out of scope for this demo.
- It does not invent specific people or places. The system prompt forbids the model from naming specific neighbors, coworkers, or local businesses the user did not name themselves.
- It does not track streaks, send reminders, or run notifications. Engagement-shaped UX patterns are deliberately absent.
- It does not retain a log of edits to Rings beyond what the database transaction history would show; there is no edit history view, no "what changed" diff. The user's current Ring map is the canonical state.

This demo handles personal context (family, neighborhood, values) but at low stakes. The framework is normative and contestable, the outputs are interpretive, and the worst case is a misaligned personal practice. The boilerplate's general guardrails plus the consistent owner-not-coach framing plus the explicit forbidden-language list in the system prompt are sufficient.

---

## 9. RSpec Outline

New spec files only. The boilerplate's specs (User, AiTemplate, LlmRequest, GeminiService, AiGatekeeper, AiBudgetChecker, the auth flows) are not redescribed.

### `spec/models/profile_spec.rb`

- Validates presence of `life_context` and `weekly_hours`
- Validates `weekly_hours` is in the range 1 to 40
- Validates length bounds on the long-text fields
- Validates uniqueness of `user_id` (one Profile per user)
- `belongs_to :user` and `has_many :ring_maps` with `dependent: :destroy`

### `spec/models/ring_map_spec.rb`

- Validates `generated_at` is present
- `has_many :rings`, `has_many :overlaps`, both with `dependent: :destroy`
- Default scope orders by `generated_at desc`
- Destroying a RingMap cascades to Rings, Overlaps, and StarterInitiatives

### `spec/models/ring_spec.rb`

- Validates presence of `name`, `description`, `rationale`, `position`
- Validates `ring_type` is one of the fifteen taxonomy values
- Validates `source` is one of the two allowed values
- Validates `position` uniqueness scoped to `ring_map_id`
- Default scope orders by `position asc`
- Destroying a Ring cascades to its StarterInitiatives and to Overlaps that reference it

### `spec/models/overlap_spec.rb`

- Validates `shared_element` and `cross_ring_idea` are present
- Validates `ring_a_id` and `ring_b_id` cannot be equal
- Validates the pair is unique within a `ring_map_id`

### `spec/models/starter_initiative_spec.rb`

- Validates presence and length bounds on `goal`, `activities`, `expected_outcomes`, `next_step`
- `belongs_to :ring`

### `spec/requests/profiles_spec.rb`

- A signed-in user can view, create, and update their own Profile
- A second user has their own Profile separate from the first
- Validation errors render the form again with messages
- A user without a Profile is redirected from `profiles#show` to `profiles#edit`

### `spec/requests/ring_maps_spec.rb`

The most important spec file. Uses the boilerplate's `GeminiService` test double.

- `ring_maps#create` requires the user to have a Profile (404 otherwise)
- `ring_maps#create` calls `GeminiService.generate(template: "ring_discovery_v1", variables: {...})` exactly once with the expected variable hash
- On a stubbed successful Gemini response, a RingMap is created with the right number of Rings, the right number of Overlaps, and exactly one StarterInitiative per `is_priority: true` Ring
- An `LlmRequest` record is created on every Gemini call (success or failure); the boilerplate's stub writes the log row
- On a stubbed `GeminiService::BudgetExceededError`, no RingMap is created and the user sees the budget-exceeded copy
- On a stubbed `GeminiService::TimeoutError`, no RingMap is created and the retry button is shown
- On malformed JSON, no RingMap is created and the user sees a parse-failure message
- `ring_maps#regenerate_overlaps` calls `overlap_regeneration_v1` and replaces the existing Overlaps; existing Rings and StarterInitiatives are not touched
- A different signed-in user cannot view, regenerate, or destroy another user's RingMap (404 expected)

### `spec/requests/rings_spec.rb`

- `rings#create` adds a manually-entered Ring and assigns the next position; `source` is set to `"user_added"`
- `rings#update` edits Ring fields and renders a Turbo Stream
- `rings#destroy` cascades to Overlaps and StarterInitiatives that reference the Ring
- `rings#toggle_priority` flips `is_priority` and does not call Gemini
- A different signed-in user cannot edit, delete, or toggle priority on another user's Ring (404 expected)

### `spec/system/discovery_flow_spec.rb` (one system spec for the primary flow)

- Sign in as the seeded user, visit `/profile/edit`, fill in the Profile form, submit, see the Profile show page
- Click "Run Ring Discovery"; the Gemini stub returns a fixture response; verify the Ring map view renders the SVG (presence of expected `<svg>` element with the right number of Ring shapes), the Ring list with the right number of rows, the Overlap list with the right number of rows, the Starter Initiatives section with two Initiatives, and the Show raw response toggle

No specs are written for the admin panel, the auth flow, or the GeminiService internals; those belong to the boilerplate.

---

## 10. Seed Data

`db/seeds.rb` extends the boilerplate's seed (which creates the admin demo user) with two parts.

### Part 1: AiTemplate seeds

Two records:

```
AiTemplate.find_or_create_by!(name: "ring_discovery_v1") do |t|
  t.description = "Generates a draft Ring map (5 to 9 Rings, Overlaps, and 2 Starter Initiatives) from a user's Profile."
  t.system_prompt = "..."   # Full system prompt text from Section 7
  t.user_prompt_template = "..."  # Full user prompt text from Section 7
  t.model = "gemini-2.0-flash"
  t.max_output_tokens = 3500
  t.temperature = 0.5
  t.notes = "..."  # Author's notes from Section 7
end

AiTemplate.find_or_create_by!(name: "overlap_regeneration_v1") do |t|
  t.description = "Regenerates the Overlaps for an existing RingMap after Ring edits."
  t.system_prompt = "..."   # Full system prompt text from Section 7
  t.user_prompt_template = "..."
  t.model = "gemini-2.0-flash"
  t.max_output_tokens = 1500
  t.temperature = 0.4
  t.notes = "..."
end
```

The full text values are exactly what is specified in Section 7.

### Part 2: Domain seeds

A sample Profile and a fully-populated RingMap belonging to the seeded admin demo user, so the dashboard renders something meaningful on first run without spending a Gemini call.

```
demo_user = User.find_by!(email: "demo@example.com")

profile = demo_user.create_profile_unless_exists!(
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
  gemini_raw: "{...full sample JSON...}"
)

# Six seeded Rings: Cedar Street block (neighborhood), Lincoln Elementary
# parents (education), the running club (sports_recreation), the work team
# (workplace), the cello adult-learners group (arts_cultural), and the
# extended family across three states (family).
#
# Two of the six are marked is_priority: Cedar Street block and Lincoln
# Elementary parents. Each gets one StarterInitiative.
#
# Three Overlaps are seeded: Cedar Street block <-> Lincoln Elementary
# (shared families on the same block whose kids attend the school), Cedar
# Street block <-> running club (a neighbor who runs the same trails), and
# Lincoln Elementary <-> work team (a coworker whose kid attends the same
# school).
#
# Each StarterInitiative has a Goal, Activities (3 lines), Expected
# Outcomes, and a Next Step that fits inside 4 weekly hours.
```

The seeded analysis exists so a user who clones the repo, runs `bin/setup`, and signs in as the demo user can immediately see what a populated Ring map looks like without spending a single Gemini call.

---

## 11. README Additions

The boilerplate's README template provides the standard Stack, Setup, License, AI Safety Posture, and About the Author sections. This demo extends them with the following.

### App name, tagline, one-paragraph description

```
# CommunityRings Demo

> Map your communities. See where they overlap. Pick where to serve.

CommunityRings Demo is a single-feature open source Rails 8 app that helps a
person see all of the communities they belong to at once and pick where to
take ownership of their contribution. You fill out a short Profile (life
context, family, neighborhood, work, hobbies, values, weekly hours
available). One AI call returns a draft Ring map: 5 to 9 communities you
already belong to, the overlaps among them, and a small starter initiative
for each of two priority Rings. You edit aggressively; the AI drafts, you
pick. It is the Ring Discovery engine from the larger CommunityRings
platform, sliced out as a runnable demo.
```

### Screenshot placeholder note

```
[Screenshot of the Ring map view goes here: the hand-drawn SVG cluster
with amber overlap regions, the Ring list below, the Overlap card, and
the Starter Initiatives section. Replace this placeholder once the
README is live in the repo.]
```

### Why I built this (indie hacker voice)

```
I am building a multi-tenant SaaS suite of community-first tools. The
production CommunityRings is multi-tenant, supports shared Rings across a
household or congregation or civic association, tracks Ring health across
the Three Pillars (Connecting, Learning, Co-Creating), and integrates with
the rest of the suite. This open source demo is one tool from that suite,
sliced thin so anyone can clone it, run it, and inspect how the discovery
engine actually works.

If you are an adult who has decided that showing up to the communities you
care about is not the same as contributing, and you want a map of your
Rings instead of a marketplace of strangers' projects, this demo is the
smallest possible artifact that lets you feel the shape of the idea.

The production app's landing page is at https://example.com/communityrings
(placeholder URL while the production app is in private beta).

This demo is open source under the MIT license. Fork it, run it, change
the prompt in the admin UI, see what it does to the output. The voice
constraints on the model (owner not coach, plain and secular, no scoring)
are spelled out in the system prompt; if you disagree with any of them,
edit and re-run.
```

### Note about the editable AI prompt

```
The AI prompts for this demo are editable in `/admin/ai_templates`. Sign
in as the seeded admin user (`demo@example.com` / `password123`),
navigate to the admin panel from the user dropdown, click on
`ring_discovery_v1` or `overlap_regeneration_v1`, and tune the system
prompt, user prompt template, model, temperature, or max_output_tokens.
Use the Test panel on the right to sanity-check changes before saving.
Save persists; nothing is reset until you re-run `db:seed` with a
`force: true` block in `seeds.rb`.

The voice rules in the system prompt (owner not coach, no religious
language, no productivity jargon, no inventing people or places) are the
most opinionated thing in the demo. If you change them, you change what
the demo is. That is fine; it is your fork.
```

### App-specific setup steps beyond `bin/setup`

None. This demo does not require Serper.dev, Active Storage, or any
other service beyond the standard Gemini API key the boilerplate already
documents.

The standard boilerplate sections (Stack, Setup, License, AI Safety Posture, About the Author) are not rewritten here; the boilerplate's template provides them.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

### Bootstrap component choices

This demo uses a profile form plus visualization pattern, so the Bootstrap palette is a mix of form components and card layouts.

- **Bootstrap form** with floating labels and large textareas on the Profile pages
- **Bootstrap collapse** for the Ring taxonomy reference card on the Profile form, and for the "Show raw response" toggle on the Ring map view
- **List groups** for the Ring list under the SVG map
- **Cards** for the Overlap list, the Starter Initiatives section, the empty-state dashboards, and the home page explainers
- **Badges** for Ring type labels (color-coded by `ring_helpers.rb`) and for the priority indicator
- **Bootstrap tooltips** on each Ring shape in the SVG to show description and rationale on hover
- **Alerts** for inline AI errors via the boilerplate's `shared/_ai_error.html.erb` partial
- **Turbo Frames** for inline Ring editing and adding
- **Turbo Streams** for `rings#create`, `rings#update`, `rings#destroy`, and `rings#toggle_priority`, all of which mutate the Ring map without a full reload
- **No Bootstrap modal anywhere.** The demo has no popovers and no modal dialogs

### Accent color application

The accent (`#a3501f`, terracotta) and its hover (`#7c3a16`) are the primary CSS custom properties. Two secondary properties extend the palette: `--secondary-accent: #15803d` (forest green) for affirmative subtle accents, and `--overlap-accent: #f59e0b` (amber) reserved for the SVG overlap regions and the small midpoint dot in the Overlap list.

Terracotta shows up consistently in:

- Primary buttons (Save, Run Ring Discovery, Add a Ring, Regenerate overlaps)
- Active navbar link state
- Text links inside cards and list rows
- The "Mark as priority" toggle button when active (terracotta fill)
- The thin connecting line in the Overlap list between two Ring names
- The Ring name labels inside the SVG
- Focus rings on form inputs

Forest green is reserved for:

- The left border on each StarterInitiative's "Next Step" cell
- The "Saved" toast color for successful Profile saves

Amber is reserved for:

- The intersection lens-shape fill in the SVG where two Rings overlap
- The midpoint dot on the connecting line in the Overlap list
- The active state of the Overlap card's "Regenerate overlaps" button background tint

### Custom CSS beyond Bootstrap

Kept minimal. Three additions in `app/assets/stylesheets/_communityrings.scss`:

1. The hand-drawn Ring shape style. Rings are SVG `<path>` elements (not `<circle>`) generated by the Stimulus controller; the SCSS file gives them a 2px terracotta stroke and a translucent 8% terracotta fill. A subtle `filter: drop-shadow(0 1px 2px rgba(0,0,0,0.4))` softens them against the dark background.

2. The amber overlap lens. SVG `<path>` elements representing the intersection of two Ring shapes get a translucent 35% amber fill with no stroke. The SCSS sets the `mix-blend-mode: screen` so the overlap reads correctly on the dark theme without overpowering the underlying Ring outlines.

3. The Initiative note-card tint. A small SCSS class gives StarterInitiative cards a 4% off-white background tint and a slightly larger border-radius than standard Bootstrap cards, so they read as "notes pinned to the map" rather than as additional UI cards.

No custom typography beyond what the boilerplate ships. No custom breakpoints. No custom dark-mode tokens; the boilerplate's `data-bs-theme="dark"` on the `<html>` element governs everything.

---

*v1.0 - CommunityRings Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
