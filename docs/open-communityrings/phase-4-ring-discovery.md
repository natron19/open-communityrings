# Phase 4: AI Templates & Ring Discovery

**Goal:** Seed the two AI templates, implement `RingMapsController` (`create`, `show`, `destroy`), and build the Ring map show view (basic version — Ring list and Overlap list rendered in HTML; the SVG Stimulus controller comes in Phase 6). After this phase the full Ring Discovery flow works end-to-end and passes all Gemini-stubbed tests.

---

## Files to Create or Modify

| Action | File |
|---|---|
| Modify | `db/seeds.rb` |
| Modify | `config/routes.rb` |
| Create | `app/controllers/ring_maps_controller.rb` |
| Create | `app/views/ring_maps/show.html.erb` |
| Create | `app/views/ring_maps/_ring.html.erb` |
| Create | `app/views/ring_maps/_overlap.html.erb` |
| Create | `app/views/ring_maps/_starter_initiative.html.erb` |
| Create | `spec/requests/ring_maps_spec.rb` |
| Create | `spec/support/ring_discovery_fixture.rb` |

---

## Model Note: `gemini-2.0-flash` vs `gemini-2.5-flash`

> **Correction from spec v1:** The spec says `model: "gemini-2.0-flash"` in the template seeds. The boilerplate docs confirm that `gemini-2.0-flash` returns 404 for new API keys on v1beta. **Use `gemini-2.5-flash` instead.** The temperatures and token limits from the spec are correct and unchanged.

---

## 1. AI Template Seeds — `db/seeds.rb`

Append to `db/seeds.rb` (after the boilerplate's user/admin seed):

```ruby
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
```

Run `rails db:seed` to load the templates. Verify them in the admin panel at `/admin/ai_templates`.

---

## 2. Routes

Add to `config/routes.rb`:

```ruby
resources :ring_maps, only: [:create, :show, :destroy] do
  member do
    post :regenerate_overlaps
  end
end
```

This phase implements `create`, `show`, and `destroy`. `regenerate_overlaps` is implemented in Phase 6.

---

## 3. Controller — `app/controllers/ring_maps_controller.rb`

```ruby
class RingMapsController < ApplicationController
  before_action :require_authentication
  before_action :load_profile, only: [:create]
  before_action :load_ring_map, only: [:show, :destroy, :regenerate_overlaps]

  def create
    result = GeminiService.generate(
      template: "ring_discovery_v1",
      variables: {
        life_context:   @profile.life_context,
        family_situation: @profile.family_situation.to_s,
        neighborhood:   @profile.neighborhood.to_s,
        work_occupation: @profile.work_occupation.to_s,
        interests:      @profile.interests.to_s,
        values:         @profile.values.to_s,
        weekly_hours:   @profile.weekly_hours.to_s,
        known_rings:    @profile.known_rings.to_s
      }
    )

    if @profile.known_rings.to_s.length > 600
      Rails.logger.warn("[RingMapsController] known_rings exceeds 600 chars for profile #{@profile.id}; model may drop user-named Rings")
    end

    ring_map = persist_ring_map!(result, @profile)
    redirect_to ring_map_path(ring_map), notice: "Your Ring map is ready."

  rescue GeminiService::BudgetExceededError
    flash.now[:alert] = "You have reached your daily AI call limit. Try again tomorrow."
    render partial: "shared/ai_error", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity
  rescue GeminiService::GatekeeperError
    flash.now[:alert] = "Your Profile contained content that could not be sent to the AI."
    render partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity
  rescue GeminiService::TimeoutError
    flash.now[:alert] = "The AI took too long to respond. Please try again."
    render partial: "shared/ai_error", locals: { error_type: :timeout }, status: :unprocessable_entity
  rescue GeminiService::GeminiError
    flash.now[:alert] = "Something went wrong with the AI call. Please try again."
    render partial: "shared/ai_error", locals: { error_type: :error }, status: :unprocessable_entity
  rescue JSON::ParserError
    flash.now[:alert] = "We could not parse the AI response. Please try again."
    render template: "ring_maps/parse_error", status: :unprocessable_entity
  end

  def show
    @rings    = @ring_map.rings.includes(:starter_initiatives)
    @overlaps = @ring_map.overlaps.includes(:ring_a, :ring_b)
    @priority_rings = @rings.select(&:is_priority)
  end

  def destroy
    @ring_map.destroy
    redirect_to dashboard_path, notice: "Ring map deleted."
  end

  def regenerate_overlaps
    # Implemented in Phase 6
    head :not_implemented
  end

  private

  def load_profile
    @profile = current_user.profile
    render file: Rails.public_path.join("404.html"), status: :not_found unless @profile
  end

  def load_ring_map
    @ring_map = current_user.profile&.ring_maps&.find_by(id: params[:id])
    render file: Rails.public_path.join("404.html"), status: :not_found unless @ring_map
  end

  def persist_ring_map!(json_string, profile)
    data = JSON.parse(json_string)

    ActiveRecord::Base.transaction do
      ring_map = profile.ring_maps.create!(
        generated_at: Time.current,
        gemini_raw:   json_string
      )

      # Create rings and build a position → Ring UUID index
      position_to_ring = {}
      (data["rings"] || []).each do |ring_data|
        ring = ring_map.rings.create!(
          name:        ring_data["name"],
          ring_type:   ring_data["ring_type"],
          description: ring_data["description"],
          rationale:   ring_data["rationale"],
          is_priority: ring_data["is_priority"] == true,
          position:    ring_data["position"].to_i,
          source:      "ai_generated"
        )
        position_to_ring[ring_data["position"].to_i] = ring
      end

      # Create overlaps (canonicalize: smaller UUID goes in ring_a_id)
      (data["overlaps"] || []).each do |overlap_data|
        ring_a = position_to_ring[overlap_data["ring_a_position"].to_i]
        ring_b = position_to_ring[overlap_data["ring_b_position"].to_i]
        next unless ring_a && ring_b
        next if ring_a.id == ring_b.id

        a_id, b_id = [ring_a.id, ring_b.id].sort
        ring_map.overlaps.create!(
          ring_a_id:      a_id,
          ring_b_id:      b_id,
          shared_element: overlap_data["shared_element"],
          cross_ring_idea: overlap_data["cross_ring_idea"]
        )
      rescue ActiveRecord::RecordInvalid
        next  # Skip duplicate overlap pairs
      end

      # Create starter initiatives for priority rings only
      (data["starter_initiatives"] || []).each do |init_data|
        ring = position_to_ring[init_data["ring_position"].to_i]
        next unless ring&.is_priority

        ring.starter_initiatives.create!(
          goal:              init_data["goal"],
          activities:        init_data["activities"],
          expected_outcomes: init_data["expected_outcomes"],
          next_step:         init_data["next_step"]
        )
      end

      ring_map
    end
  end
end
```

---

## 4. Views

### `app/views/ring_maps/show.html.erb`

Basic version. The SVG map and full layout are completed in Phase 6. This phase renders the Ring list, Overlap list, and Starter Initiatives in readable HTML so the flow is testable.

```erb
<div class="container py-4">

  <%# Header strip %>
  <div class="d-flex justify-content-between align-items-start mb-4">
    <div>
      <h1>Your Ring Map</h1>
      <p class="text-muted small mb-0">Generated <%= @ring_map.generated_at.strftime("%B %-d, %Y at %-I:%M %p") %></p>
    </div>
    <div class="d-flex gap-2">
      <%= link_to "Delete this map", ring_map_path(@ring_map),
          data: { turbo_method: :delete, turbo_confirm: "Delete this Ring map and all its Rings? This cannot be undone." },
          class: "btn btn-outline-danger btn-sm" %>
    </div>
  </div>

  <%# SVG placeholder (Phase 6 replaces this) %>
  <div class="card mb-4">
    <div class="card-body text-center text-muted py-4">
      <p class="mb-1 fst-italic">Ring map visualization coming in Phase 6.</p>
      <p class="mb-0 small"><em>This is a draft to argue with, not a verdict to follow.</em></p>
    </div>
  </div>

  <%# AI interpretation disclaimer %>
  <p class="text-muted small fst-italic mb-3">Ring types and overlaps are AI interpretations; rename, retype, or drop anything that does not match how you see your communities.</p>

  <%# Ring list %>
  <div class="card mb-4">
    <div class="card-header d-flex justify-content-between align-items-center">
      <h5 class="mb-0">Your Rings (<%= @rings.count %>)</h5>
    </div>
    <ul class="list-group list-group-flush" id="ring-list">
      <% @rings.each do |ring| %>
        <%= render "ring_maps/ring", ring: ring %>
      <% end %>
    </ul>
    <div class="card-footer">
      <%# Add Ring form — implemented in Phase 5 %>
      <p class="text-muted small mb-0">Ring editing and adding comes in Phase 5.</p>
    </div>
  </div>

  <%# Overlap list %>
  <% if @overlaps.any? %>
    <div class="card mb-4" id="overlap-list">
      <div class="card-header">
        <h5 class="mb-0">Overlaps (<%= @overlaps.count %>)</h5>
      </div>
      <div class="card-body">
        <% @overlaps.each do |overlap| %>
          <%= render "ring_maps/overlap", overlap: overlap %>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Starter Initiatives %>
  <% if @priority_rings.any? %>
    <div class="card mb-4" id="starter-initiatives">
      <div class="card-header">
        <h5 class="mb-0">Starter Initiatives</h5>
      </div>
      <div class="card-body">
        <% @priority_rings.each do |ring| %>
          <% if ring.starter_initiatives.any? %>
            <h6 class="mt-3 mb-2">
              <%= ring.name %> <%= ring_type_badge(ring.ring_type) %>
            </h6>
            <% ring.starter_initiatives.each do |initiative| %>
              <%= render "ring_maps/starter_initiative", initiative: initiative %>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Raw response toggle %>
  <div class="mb-4">
    <a class="text-muted small" data-bs-toggle="collapse" href="#raw-response" role="button">
      Show raw response (advanced) ▾
    </a>
    <div class="collapse mt-2" id="raw-response">
      <% if @ring_map.gemini_raw.present? %>
        <p class="small text-muted mb-1">ring_discovery_v1 — <%= @ring_map.generated_at.strftime("%B %-d, %Y at %-I:%M %p") %></p>
        <pre class="small bg-dark border rounded p-3" style="overflow-x:auto;"><%= @ring_map.gemini_raw %></pre>
      <% end %>
      <% if @ring_map.gemini_raw_overlaps.present? %>
        <p class="small text-muted mb-1 mt-3">overlap_regeneration_v1 — <%= @ring_map.overlaps_regenerated_at&.strftime("%B %-d, %Y at %-I:%M %p") %></p>
        <pre class="small bg-dark border rounded p-3" style="overflow-x:auto;"><%= @ring_map.gemini_raw_overlaps %></pre>
      <% end %>
    </div>
  </div>

  <%# Footer actions %>
  <div class="d-flex gap-2">
    <%= link_to "Edit my Profile", edit_profile_path, class: "btn btn-outline-secondary" %>
    <%= button_to "Start a fresh map", ring_maps_path, method: :post,
        class: "btn btn-accent",
        data: { turbo_confirm: "This will generate a new Ring map. Your current map will not be deleted but will no longer be the latest. Continue?" } %>
  </div>

</div>
```

### `app/views/ring_maps/_ring.html.erb`

```erb
<li class="list-group-item" id="ring-<%= ring.id %>">
  <div class="d-flex justify-content-between align-items-start">
    <div>
      <span class="me-2 text-muted small"><%= ring.position %>.</span>
      <strong><%= ring.name %></strong>
      <%= ring_type_badge(ring.ring_type) %>
      <% if ring.is_priority %>
        <span class="badge text-bg-warning ms-1">Priority</span>
      <% end %>
      <p class="mb-1 mt-1 small"><%= ring.description %></p>
      <p class="mb-0 text-muted small fst-italic"><%= ring.rationale %></p>
    </div>
  </div>
</li>
```

### `app/views/ring_maps/_overlap.html.erb`

```erb
<div class="mb-4 pb-4 border-bottom last-child-no-border">
  <div class="d-flex align-items-center gap-2 mb-1">
    <span class="fw-semibold small"><%= overlap.ring_a.name %></span>
    <span class="text-muted">—</span>
    <span class="fw-semibold small"><%= overlap.ring_b.name %></span>
  </div>
  <p class="text-muted small mb-1"><%= overlap.shared_element %></p>
  <p class="mb-0 ps-3 small"><%= overlap.cross_ring_idea %></p>
</div>
```

### `app/views/ring_maps/_starter_initiative.html.erb`

```erb
<div class="card mb-3 initiative-card">
  <div class="card-body">
    <div class="mb-3">
      <span class="text-uppercase text-muted small fw-semibold">Goal</span>
      <p class="mb-0"><%= initiative.goal %></p>
    </div>
    <div class="mb-3">
      <span class="text-uppercase text-muted small fw-semibold">Activities</span>
      <% initiative.activities.split("\n").reject(&:blank?).each do |activity| %>
        <p class="mb-1 small"><%= activity %></p>
      <% end %>
    </div>
    <div class="mb-3">
      <span class="text-uppercase text-muted small fw-semibold">Expected Outcomes</span>
      <p class="mb-0"><%= initiative.expected_outcomes %></p>
    </div>
    <div class="next-step-cell p-2 rounded">
      <span class="text-uppercase text-muted small fw-semibold">Next Step</span>
      <p class="mb-0"><%= initiative.next_step %></p>
    </div>
  </div>
</div>
```

Add to `application.css`:

```css
.initiative-card .next-step-cell {
  border-left: 4px solid var(--secondary-accent);
}
```

### `app/views/ring_maps/parse_error.html.erb`

Shown when `JSON::ParserError` is raised:

```erb
<div class="container py-4">
  <div class="row justify-content-center">
    <div class="col-md-6">
      <div class="alert alert-warning">
        <h5>We could not read the AI response.</h5>
        <p>The AI returned a response that could not be parsed. This sometimes happens — please try again.</p>
        <%= button_to "Try again", ring_maps_path, method: :post, class: "btn btn-accent" %>
        <%= link_to "Go to dashboard", dashboard_path, class: "btn btn-outline-secondary ms-2" %>
      </div>
    </div>
  </div>
</div>
```

---

## 5. RSpec Fixture — `spec/support/ring_discovery_fixture.rb`

Create a valid JSON fixture representing a minimal Ring Discovery response for use in tests:

```ruby
module RingDiscoveryFixture
  VALID_RESPONSE = JSON.generate({
    rings: [
      { position: 1, name: "Cedar Street block",         ring_type: "neighborhood",      description: "Long-time and newer residents on the same walkable block.",              rationale: "You live here and already know several neighbors.",                      is_priority: true  },
      { position: 2, name: "Lincoln Elementary parents", ring_type: "education",         description: "Parents and caregivers of kids at Lincoln Elementary.",                  rationale: "Your kids attend this school and you know several other parents.",        is_priority: true  },
      { position: 3, name: "Tuesday running club",       ring_type: "sports_recreation", description: "A weekly trail running group that meets on Tuesday mornings.",           rationale: "You joined last year and attend most weeks.",                             is_priority: false },
      { position: 4, name: "Remote engineering team",    ring_type: "workplace",         description: "A small distributed software team.",                                     rationale: "You spend most of your working hours with this group.",                   is_priority: false },
      { position: 5, name: "Extended family",            ring_type: "family",            description: "Immediate family and extended relatives across three states.",           rationale: "Family is a core Ring even when geographically distributed.",            is_priority: false }
    ],
    overlaps: [
      { ring_a_position: 1, ring_b_position: 2, shared_element: "Families with school-age children living on the same block.", cross_ring_idea: "Organize a block-level school supply drive to bridge the neighborhood and school communities." },
      { ring_a_position: 1, ring_b_position: 3, shared_element: "A neighbor who runs the same Tuesday morning trails.",          cross_ring_idea: "Propose a neighborhood running meetup to bring the running club closer to the block community." }
    ],
    starter_initiatives: [
      { ring_position: 1, goal: "Host a small block gathering to introduce newer residents to long-time neighbors.", activities: "1. Reserve the block park\n2. Print and distribute flyers\n3. Ask long-time residents to share stories", expected_outcomes: "At least twelve households attend and three new connections form.", next_step: "Check the city park reservation portal this week." },
      { ring_position: 2, goal: "Join one Lincoln Elementary committee this semester.", activities: "1. Attend the next PTA meeting\n2. Volunteer for one committee\n3. Follow up with the committee chair", expected_outcomes: "You know the committee members and have one task you can own.", next_step: "Email the PTA chair to ask about upcoming meetings." }
    ]
  })
end
```

Include in `spec/rails_helper.rb`:

```ruby
require "support/ring_discovery_fixture"
RSpec.configure do |config|
  config.include RingDiscoveryFixture
end
```

---

## 6. RSpec Tests

### `spec/requests/ring_maps_spec.rb`

```ruby
RSpec.describe "RingMaps", type: :request do
  let(:user)    { create(:user) }
  let(:profile) { create(:profile, user: user) }

  describe "POST /ring_maps" do
    context "when not signed in" do
      it "redirects to sign in" do
        post ring_maps_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in without a profile" do
      before { sign_in_as(user) }

      it "returns 404" do
        post ring_maps_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in with a profile and Gemini succeeds" do
      before do
        sign_in_as(user)
        profile
        gemini_returns(RingDiscoveryFixture::VALID_RESPONSE)
      end

      it "creates a RingMap" do
        expect { post ring_maps_path }.to change(RingMap, :count).by(1)
      end

      it "creates the correct number of Rings" do
        post ring_maps_path
        expect(user.profile.ring_maps.first.rings.count).to eq(5)
      end

      it "creates the correct number of Overlaps" do
        post ring_maps_path
        expect(user.profile.ring_maps.first.overlaps.count).to eq(2)
      end

      it "creates one StarterInitiative per priority Ring" do
        post ring_maps_path
        priority_rings = user.profile.ring_maps.first.rings.where(is_priority: true)
        expect(priority_rings.count).to eq(2)
        expect(StarterInitiative.count).to eq(2)
        priority_rings.each do |ring|
          expect(ring.starter_initiatives.count).to eq(1)
        end
      end

      it "stores the raw Gemini response in gemini_raw" do
        post ring_maps_path
        expect(user.profile.ring_maps.first.gemini_raw).to be_present
      end

      it "redirects to the new ring map" do
        post ring_maps_path
        expect(response).to redirect_to(ring_map_path(RingMap.last))
      end

      it "calls GeminiService.generate with ring_discovery_v1" do
        expect(GeminiService).to receive(:generate).with(
          hash_including(template: "ring_discovery_v1")
        ).and_return(RingDiscoveryFixture::VALID_RESPONSE)
        post ring_maps_path
      end
    end

    context "when Gemini raises BudgetExceededError" do
      before do
        sign_in_as(user)
        profile
        gemini_raises(GeminiService::BudgetExceededError)
      end

      it "does not create a RingMap" do
        expect { post ring_maps_path }.not_to change(RingMap, :count)
      end

      it "renders an error response" do
        post ring_maps_path
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when Gemini raises TimeoutError" do
      before do
        sign_in_as(user)
        profile
        gemini_raises(GeminiService::TimeoutError)
      end

      it "does not create a RingMap" do
        expect { post ring_maps_path }.not_to change(RingMap, :count)
      end
    end

    context "when Gemini returns malformed JSON" do
      before do
        sign_in_as(user)
        profile
        gemini_returns("This is not JSON")
      end

      it "does not create a RingMap" do
        expect { post ring_maps_path }.not_to change(RingMap, :count)
      end

      it "renders the parse error template" do
        post ring_maps_path
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("could not read")
      end
    end
  end

  describe "GET /ring_maps/:id" do
    let(:ring_map) { create(:ring_map, profile: profile) }

    before { sign_in_as(user) }

    it "returns 200 for the owner" do
      get ring_map_path(ring_map)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's ring map" do
      other = create(:user)
      sign_in_as(other)
      get ring_map_path(ring_map)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /ring_maps/:id" do
    let(:ring_map) { create(:ring_map, profile: profile) }

    before { sign_in_as(user) }

    it "destroys the ring map and redirects to dashboard" do
      ring_map
      expect { delete ring_map_path(ring_map) }.to change(RingMap, :count).by(-1)
      expect(response).to redirect_to(dashboard_path)
    end

    it "returns 404 if another user tries to delete" do
      other = create(:user)
      sign_in_as(other)
      delete ring_map_path(ring_map)
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

---

## Manual Test Checklist

After completing Phase 4, verify in the browser (requires a real `GEMINI_API_KEY` in `.env`):

- [ ] `rails db:seed` — no errors; `/admin/ai_templates` shows `ring_discovery_v1` and `overlap_regeneration_v1`
- [ ] Sign in, go to dashboard → "Run Ring Discovery" button is present
- [ ] Click "Run Ring Discovery" → spinner appears, then redirects to `/ring_maps/:id`
- [ ] Ring map show page loads with the correct Ring list (5–9 Rings)
- [ ] Priority Rings are visually distinguished with a "Priority" badge
- [ ] Ring types display as human-readable labels (e.g., "Neighborhood" not "neighborhood")
- [ ] Overlaps section appears if any overlaps were returned
- [ ] Starter Initiatives section appears with two initiative cards
- [ ] "Show raw response" collapse works and shows the raw JSON
- [ ] "Delete this map" confirmation dialog appears and deletes on confirm
- [ ] After delete, redirects to dashboard
- [ ] Sign in as a second user and manually hit `/ring_maps/:id` from first user → 404
- [ ] No Profile? POST to `/ring_maps` → 404
- [ ] `bundle exec rspec spec/requests/ring_maps_spec.rb` — all tests pass (no real API calls)
