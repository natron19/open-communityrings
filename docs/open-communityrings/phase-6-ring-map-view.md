# Phase 6: Full Ring Map View, SVG, Overlap Regeneration & Styles

**Goal:** Complete the ring_maps/show page to the full spec: SVG cluster visualization (hand-drawn ring shapes, overlap lens regions, Bootstrap tooltips), overlap regeneration, all custom CSS, the dashboard Branch 3 inline render, and the system spec. After this phase the demo is visually complete and all tests pass.

---

## Files to Create or Modify

| Action | File |
|---|---|
| Modify | `app/views/ring_maps/show.html.erb` |
| Modify | `app/views/dashboard/show.html.erb` |
| Modify | `app/controllers/ring_maps_controller.rb` |
| Create | `app/javascript/controllers/ring_map_controller.js` |
| Modify | `app/assets/stylesheets/application.css` |
| Create | `spec/system/discovery_flow_spec.rb` |
| Modify | `spec/requests/ring_maps_spec.rb` |

---

## Pattern Reference

Before writing any code, review:
- [`docs/turbo-stimulus-patterns.md`](../turbo-stimulus-patterns.md) — Stimulus controller structure, `window.bootstrap`, dispose in `disconnect()`
- `CLAUDE.md` — "NO PLAIN JAVASCRIPT — STIMULUS ONLY"

---

## 1. Custom CSS — `app/assets/stylesheets/application.css`

Append to `application.css` (the accent color rules were added in Phase 1; add the ring-specific styles here):

```css
/* ── Ring map SVG styles ─────────────────────────────────────────────── */
.ring-shape {
  stroke: var(--accent);
  stroke-width: 2;
  fill: rgba(163, 80, 31, 0.08);
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.4));
}

.ring-shape:hover {
  fill: rgba(163, 80, 31, 0.15);
  cursor: default;
}

.overlap-lens {
  fill: rgba(245, 158, 11, 0.35);
  stroke: none;
  mix-blend-mode: screen;
}

.ring-label {
  fill: var(--accent);
  font-size: 11px;
  font-family: system-ui, -apple-system, sans-serif;
  text-anchor: middle;
  dominant-baseline: middle;
  pointer-events: none;
}

/* ── Overlap list ────────────────────────────────────────────────────── */
.overlap-connector {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.25rem;
}

.overlap-connector-line {
  flex: 1;
  height: 1px;
  background-color: var(--accent);
  position: relative;
}

.overlap-connector-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background-color: var(--overlap-accent);
  flex-shrink: 0;
}

/* ── Starter Initiative cards ────────────────────────────────────────── */
.initiative-card {
  background-color: rgba(255, 255, 255, 0.04);
  border-radius: 0.5rem;
}

.initiative-card .next-step-cell {
  border-left: 4px solid var(--secondary-accent);
  padding: 0.5rem 0.75rem;
  border-radius: 0 0.25rem 0.25rem 0;
}
```

---

## 2. Stimulus Controller — `app/javascript/controllers/ring_map_controller.js`

This controller renders the hand-drawn SVG Ring map. Key behaviors:
- Each Ring is a jittered circle path (deterministic per Ring UUID) sized in a constrained range
- A simple force-repulsion layout positions Rings in a soft cluster
- Where two Rings have an Overlap record, an amber lens shape fills the intersection
- Bootstrap tooltips on each Ring shape show name, description, and rationale on hover
- Listens for `ring:added`, `ring:updated`, `ring:removed`, `overlap:replaced` custom events and re-renders

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values  = { rings: Array, overlaps: Array }

  connect() {
    this.render()
    this.handleRingAdded   = () => this.fetchAndRender()
    this.handleRingUpdated = () => this.fetchAndRender()
    this.handleRingRemoved = () => this.fetchAndRender()
    this.handleOverlapReplaced = () => this.fetchAndRender()

    document.addEventListener("ring:added",       this.handleRingAdded)
    document.addEventListener("ring:updated",      this.handleRingUpdated)
    document.addEventListener("ring:removed",      this.handleRingRemoved)
    document.addEventListener("overlap:replaced",  this.handleOverlapReplaced)
  }

  disconnect() {
    document.removeEventListener("ring:added",      this.handleRingAdded)
    document.removeEventListener("ring:updated",    this.handleRingUpdated)
    document.removeEventListener("ring:removed",    this.handleRingRemoved)
    document.removeEventListener("overlap:replaced", this.handleOverlapReplaced)
    this._disposeTooltips()
  }

  fetchAndRender() {
    // Re-read rings and overlaps from data attributes, then re-render.
    // The server updates data attributes on the container element via Turbo Streams.
    this.render()
  }

  render() {
    const rings    = this.ringsValue
    const overlaps = this.overlapsValue
    if (!rings.length) return

    const W = 800, H = 560
    const positions = this._layout(rings, W, H)
    const svg = this._buildSVG(rings, overlaps, positions, W, H)
    this.canvasTarget.innerHTML = svg
    this._initTooltips()
  }

  // ── Layout: simple force repulsion ──────────────────────────────────
  _layout(rings, W, H) {
    const n = rings.length
    const minR = 55, maxR = 95
    // Start rings in a circle
    const positions = rings.map((ring, i) => {
      const angle = (2 * Math.PI * i) / n
      const r = this._ringRadius(ring, minR, maxR)
      return {
        id: ring.id,
        x: W / 2 + (W * 0.32) * Math.cos(angle),
        y: H / 2 + (H * 0.32) * Math.sin(angle),
        r
      }
    })

    // 60 iterations of repulsion + centering
    for (let iter = 0; iter < 60; iter++) {
      for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
          const a = positions[i], b = positions[j]
          const dx = b.x - a.x, dy = b.y - a.y
          const dist = Math.sqrt(dx * dx + dy * dy) || 1
          const minDist = a.r + b.r + 8
          if (dist < minDist) {
            const factor = (minDist - dist) / dist * 0.5
            a.x -= dx * factor; a.y -= dy * factor
            b.x += dx * factor; b.y += dy * factor
          }
        }
        // Pull toward center
        positions[i].x += (W / 2 - positions[i].x) * 0.02
        positions[i].y += (H / 2 - positions[i].y) * 0.02
        // Clamp within bounds
        const p = positions[i]
        p.x = Math.max(p.r + 10, Math.min(W - p.r - 10, p.x))
        p.y = Math.max(p.r + 10, Math.min(H - p.r - 10, p.y))
      }
    }
    return positions
  }

  _ringRadius(ring, minR, maxR) {
    // All rings get a size in [minR, maxR]; no ring is "more important" by size.
    // Slight variation based on position for visual interest.
    const seed = this._hashString(ring.id)
    return minR + (seed % (maxR - minR))
  }

  // ── SVG construction ─────────────────────────────────────────────────
  _buildSVG(rings, overlaps, positions, W, H) {
    const posMap = {}
    positions.forEach(p => { posMap[p.id] = p })

    let svgParts = [`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" style="width:100%;height:auto;">`]

    // Overlap lens shapes (drawn first, under rings)
    overlaps.forEach(overlap => {
      const a = posMap[overlap.ring_a_id]
      const b = posMap[overlap.ring_b_id]
      if (!a || !b) return
      const lens = this._lensPath(a, b)
      if (lens) svgParts.push(`<path class="overlap-lens" d="${lens}"/>`)
    })

    // Ring shapes
    rings.forEach((ring, i) => {
      const p = posMap[ring.id]
      if (!p) return
      const path = this._jitteredCirclePath(p.x, p.y, p.r, ring.id)
      const label = this._escapeXml(ring.name.length > 16 ? ring.name.slice(0, 15) + "…" : ring.name)
      const tooltipTitle = this._escapeXml(`${ring.name}\n${ring.description}`)
      svgParts.push(`
        <path class="ring-shape" d="${path}"
              data-bs-toggle="tooltip"
              data-bs-placement="top"
              data-bs-title="${tooltipTitle}"
              data-bs-html="false"/>
        <text class="ring-label" x="${p.x}" y="${p.y}">${label}</text>
      `)
    })

    svgParts.push("</svg>")
    return svgParts.join("")
  }

  _jitteredCirclePath(cx, cy, r, id) {
    // Deterministic jitter per Ring UUID — shape stays stable across re-renders
    const seed = this._hashString(id)
    const points = 18
    let d = ""
    for (let i = 0; i <= points; i++) {
      const angle = (2 * Math.PI * i) / points
      const jitter = 1 + ((this._lcg(seed + i) % 12) - 6) / 100
      const x = cx + r * jitter * Math.cos(angle)
      const y = cy + r * jitter * Math.sin(angle)
      d += i === 0 ? `M ${x.toFixed(1)} ${y.toFixed(1)}` : ` L ${x.toFixed(1)} ${y.toFixed(1)}`
    }
    return d + " Z"
  }

  _lensPath(a, b) {
    const dx = b.x - a.x, dy = b.y - a.y
    const dist = Math.sqrt(dx * dx + dy * dy)
    if (dist >= a.r + b.r) return null  // No overlap
    if (dist <= Math.abs(a.r - b.r)) return null  // One contains the other

    const ra = a.r, rb = b.r
    const d2 = dist * dist
    const cosA = (d2 + ra * ra - rb * rb) / (2 * dist * ra)
    const cosB = (d2 + rb * rb - ra * ra) / (2 * dist * rb)
    const angleA = Math.acos(Math.max(-1, Math.min(1, cosA)))
    const angleB = Math.acos(Math.max(-1, Math.min(1, cosB)))

    const nx = dx / dist, ny = dy / dist
    const p1x = a.x + ra * Math.cos(Math.atan2(dy, dx) + angleA)
    const p1y = a.y + ra * Math.sin(Math.atan2(dy, dx) + angleA)
    const p2x = a.x + ra * Math.cos(Math.atan2(dy, dx) - angleA)
    const p2y = a.y + ra * Math.sin(Math.atan2(dy, dx) - angleA)

    const largeArc = 0
    return `M ${p1x.toFixed(1)} ${p1y.toFixed(1)}
            A ${rb.toFixed(1)} ${rb.toFixed(1)} 0 ${largeArc} 0 ${p2x.toFixed(1)} ${p2y.toFixed(1)}
            A ${ra.toFixed(1)} ${ra.toFixed(1)} 0 ${largeArc} 0 ${p1x.toFixed(1)} ${p1y.toFixed(1)} Z`
  }

  // ── Tooltips ─────────────────────────────────────────────────────────
  _initTooltips() {
    if (!window.bootstrap) return
    this._disposeTooltips()
    this._tooltips = [...this.canvasTarget.querySelectorAll("[data-bs-toggle='tooltip']")]
      .map(el => new window.bootstrap.Tooltip(el, { trigger: "hover focus", container: "body" }))
  }

  _disposeTooltips() {
    (this._tooltips || []).forEach(t => t.dispose())
    this._tooltips = []
  }

  // ── Utilities ────────────────────────────────────────────────────────
  _hashString(str) {
    let h = 0
    for (let i = 0; i < str.length; i++) {
      h = (Math.imul(31, h) + str.charCodeAt(i)) | 0
    }
    return Math.abs(h)
  }

  _lcg(seed) {
    return (1664525 * seed + 1013904223) & 0xffffffff
  }

  _escapeXml(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
```

---

## 3. Updated `ring_maps/show.html.erb`

The full seven-section layout from the spec. Replaces the Phase 4 basic version.

```erb
<%# Build the data arrays for the Stimulus SVG controller %>
<% rings_data = @rings.map { |r| { id: r.id, name: r.name, ring_type: r.ring_type, description: r.description, rationale: r.rationale, is_priority: r.is_priority, position: r.position } } %>
<% overlaps_data = @overlaps.map { |o| { ring_a_id: o.ring_a_id, ring_b_id: o.ring_b_id } } %>

<div class="container py-4">

  <%# 1. Header strip %>
  <div class="d-flex justify-content-between align-items-start mb-3">
    <div>
      <h1>Your Ring Map</h1>
      <p class="text-muted small mb-0">
        Generated <%= @ring_map.generated_at.strftime("%B %-d, %Y at %-I:%M %p") %>
        <% if @ring_map.overlaps_regenerated_at.present? %>
          &middot; Overlaps updated <%= @ring_map.overlaps_regenerated_at.strftime("%B %-d, %Y") %>
        <% end %>
      </p>
    </div>
    <div class="d-flex gap-2">
      <%= button_to "Regenerate overlaps", regenerate_overlaps_ring_map_path(@ring_map),
          method: :post,
          class: "btn btn-sm btn-outline-secondary",
          data: { turbo_submits_with: "Regenerating…" } %>
      <%= link_to "✕", ring_map_path(@ring_map),
          data: { turbo_method: :delete, turbo_confirm: "Delete this Ring map? This cannot be undone." },
          class: "btn btn-sm btn-outline-danger",
          title: "Delete this map" %>
    </div>
  </div>

  <%# 2. The SVG Ring map %>
  <div class="card mb-3"
       data-controller="ring-map"
       data-ring-map-rings-value="<%= rings_data.to_json %>"
       data-ring-map-overlaps-value="<%= overlaps_data.to_json %>">
    <div class="card-body p-2" data-ring-map-target="canvas">
      <%# Rendered by ring_map_controller.js — fallback for no-JS %>
      <p class="text-muted text-center small py-4 mb-0">Loading Ring map…</p>
    </div>
    <div class="card-footer text-center">
      <p class="text-muted small fst-italic mb-0">This is a draft to argue with, not a verdict to follow.</p>
    </div>
  </div>

  <%# AI interpretation disclaimer %>
  <p class="text-muted small fst-italic mb-3">Ring types and overlaps are AI interpretations; rename, retype, or drop anything that does not match how you see your communities.</p>

  <%# 3. Ring list %>
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
      <a class="btn btn-outline-secondary btn-sm" data-bs-toggle="collapse" href="#add-ring-collapse" role="button">
        + Add a Ring
      </a>
      <div class="collapse mt-3" id="add-ring-collapse">
        <div id="add-ring-form">
          <%= turbo_frame_tag "add-ring-frame" do %>
            <%= render "rings/form", ring: Ring.new, ring_map: @ring_map %>
          <% end %>
          <div id="ring-form-errors"></div>
        </div>
      </div>
    </div>
  </div>

  <%# 4. Overlap list %>
  <div class="card mb-4" id="overlap-list">
    <div class="card-header d-flex justify-content-between align-items-center">
      <h5 class="mb-0">Overlaps (<%= @overlaps.count %>)</h5>
      <%= button_to "Regenerate overlaps", regenerate_overlaps_ring_map_path(@ring_map),
          method: :post,
          class: "btn btn-sm btn-outline-secondary",
          data: { turbo_submits_with: "Regenerating…" } %>
    </div>
    <div class="card-body">
      <% if @overlaps.any? %>
        <% @overlaps.each do |overlap| %>
          <%= render "ring_maps/overlap", overlap: overlap %>
        <% end %>
      <% else %>
        <p class="text-muted small mb-0">No overlaps found. Edit your Rings and regenerate to find connections.</p>
      <% end %>
    </div>
  </div>

  <%# 5. Starter Initiatives %>
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

  <%# 6. Raw response toggle %>
  <div class="mb-4">
    <a class="text-muted small" data-bs-toggle="collapse" href="#raw-response" role="button">
      Show raw response (advanced) ▾
    </a>
    <div class="collapse mt-2" id="raw-response">
      <% if @ring_map.gemini_raw.present? %>
        <p class="small text-muted mb-1 fw-semibold">ring_discovery_v1 — <%= @ring_map.generated_at.strftime("%B %-d, %Y at %-I:%M %p") %></p>
        <pre class="small bg-dark border rounded p-3" style="overflow-x:auto;max-height:400px;"><%= @ring_map.gemini_raw %></pre>
      <% end %>
      <% if @ring_map.gemini_raw_overlaps.present? %>
        <p class="small text-muted mb-1 fw-semibold mt-3">overlap_regeneration_v1 — <%= @ring_map.overlaps_regenerated_at&.strftime("%B %-d, %Y at %-I:%M %p") %></p>
        <pre class="small bg-dark border rounded p-3" style="overflow-x:auto;max-height:300px;"><%= @ring_map.gemini_raw_overlaps %></pre>
      <% end %>
    </div>
  </div>

  <%# 7. Footer actions %>
  <div class="d-flex gap-2">
    <%= link_to "Edit my Profile", edit_profile_path, class: "btn btn-outline-secondary" %>
    <%= button_to "Start a fresh map", ring_maps_path, method: :post,
        class: "btn btn-accent",
        data: { turbo_confirm: "This will generate a new Ring map. Your current map will not be deleted but will no longer be the latest. Continue?",
                turbo_submits_with: "Running…" } %>
  </div>

</div>
```

---

## 4. Updated Overlap Partial — `app/views/ring_maps/_overlap.html.erb`

Replace the Phase 4 version with the full connector line + amber dot layout:

```erb
<div class="mb-4 pb-3 border-bottom">
  <div class="overlap-connector mb-1">
    <span class="small fw-semibold"><%= overlap.ring_a.name %></span>
    <div class="overlap-connector-line">
      <span class="overlap-connector-dot position-absolute" style="left:50%;top:-4px;transform:translateX(-50%);"></span>
    </div>
    <span class="small fw-semibold"><%= overlap.ring_b.name %></span>
  </div>
  <p class="text-muted small mb-1 ps-1"><%= overlap.shared_element %></p>
  <p class="mb-0 ps-3 small"><%= overlap.cross_ring_idea %></p>
</div>
```

---

## 5. Overlap Regeneration — `RingMapsController#regenerate_overlaps`

Replace the Phase 4 stub with the full implementation:

```ruby
def regenerate_overlaps
  rings = @ring_map.rings.order(:position)
  rings_text = rings.map { |r| "Position #{r.position}. #{r.name} (#{r.ring_type}): #{r.description}" }.join("\n")

  result = GeminiService.generate(
    template: "overlap_regeneration_v1",
    variables: { rings_text: rings_text }
  )

  data = JSON.parse(result)
  position_to_ring = rings.index_by(&:position)

  ActiveRecord::Base.transaction do
    @ring_map.overlaps.destroy_all

    (data["overlaps"] || []).each do |overlap_data|
      ring_a = position_to_ring[overlap_data["ring_a_position"].to_i]
      ring_b = position_to_ring[overlap_data["ring_b_position"].to_i]
      next unless ring_a && ring_b
      next if ring_a.id == ring_b.id

      a_id, b_id = [ring_a.id, ring_b.id].sort
      @ring_map.overlaps.create!(
        ring_a_id: a_id,
        ring_b_id: b_id,
        shared_element: overlap_data["shared_element"],
        cross_ring_idea: overlap_data["cross_ring_idea"]
      )
    rescue ActiveRecord::RecordInvalid
      next
    end

    @ring_map.update!(
      overlaps_regenerated_at: Time.current,
      gemini_raw_overlaps: result
    )
  end

  redirect_to ring_map_path(@ring_map), notice: "Overlaps regenerated."

rescue GeminiService::BudgetExceededError
  redirect_to ring_map_path(@ring_map), alert: "Daily AI call limit reached. Try again tomorrow."
rescue GeminiService::TimeoutError
  redirect_to ring_map_path(@ring_map), alert: "Gemini timed out. Please try again."
rescue GeminiService::GeminiError
  redirect_to ring_map_path(@ring_map), alert: "Something went wrong with the AI call. Please try again."
rescue JSON::ParserError
  redirect_to ring_map_path(@ring_map), alert: "Could not parse the AI response. Please try again."
end
```

---

## 6. Updated Dashboard Branch 3 — `dashboard/show.html.erb`

Replace the `redirect_to` placeholder with an inline render of the latest Ring map:

```erb
<% elsif current_user.respond_to?(:profile) && current_user.profile&.ring_maps&.any? %>
  <%
    @ring_map = current_user.profile.ring_maps.first
    @rings = @ring_map.rings.includes(:starter_initiatives)
    @overlaps = @ring_map.overlaps.includes(:ring_a, :ring_b)
    @priority_rings = @rings.select(&:is_priority)
  %>
  <%= render template: "ring_maps/show" %>
```

> **Note:** Rendering a template with instance variables set in the view is an unusual pattern. An alternative (cleaner) approach is to redirect to `ring_map_path` instead and remove Branch 3 from the dashboard entirely. Choose based on user experience preference — redirect is simpler, inline render keeps the URL as `/dashboard`.

---

## 7. RSpec System Spec — `spec/system/discovery_flow_spec.rb`

```ruby
require "rails_helper"

RSpec.describe "Discovery flow", type: :system do
  let(:user) { create(:user, password: "password123") }

  before do
    driven_by(:rack_test)
    # Stub Gemini so no real API call is made
    allow(GeminiService).to receive(:generate).and_return(RingDiscoveryFixture::VALID_RESPONSE)
    # Seed the ring_discovery_v1 template
    AiTemplate.find_or_create_by!(name: "ring_discovery_v1") do |t|
      t.description = "Test template"
      t.system_prompt = "You are a test assistant."
      t.user_prompt_template = "{{life_context}}"
      t.model = "gemini-2.5-flash"
      t.max_output_tokens = 500
      t.temperature = 0.5
    end
  end

  it "lets a user build a Profile and run Ring Discovery" do
    visit sign_in_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"

    expect(page).to have_current_path(dashboard_path)

    # No profile yet — "Build your Profile" CTA
    click_link "Build your Profile"
    expect(page).to have_current_path(edit_profile_path)
    expect(page).to have_content("Build your Profile")

    fill_in "Life context", with: "Mid-career developer in a walkable neighborhood, looking to be more rooted in the community after years of remote work."
    fill_in "Weekly hours available", with: "4"
    click_button "Build Profile"

    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_content("Run Ring Discovery")

    click_button "Run Ring Discovery"

    # Ring map show page
    expect(page).to have_content("Your Ring Map")
    expect(page).to have_content("Cedar Street block")
    expect(page).to have_content("Lincoln Elementary parents")
    expect(page).to have_css("svg")  # SVG map rendered
    expect(page).to have_content("Overlaps")
    expect(page).to have_content("Starter Initiatives")
    expect(page).to have_content("Show raw response")
  end
end
```

---

## 8. Overlap Regeneration Tests — Add to `spec/requests/ring_maps_spec.rb`

```ruby
describe "POST /ring_maps/:id/regenerate_overlaps" do
  let(:ring_map) { create(:ring_map, profile: profile) }
  let(:ring_a)   { create(:ring, ring_map: ring_map, position: 1) }
  let(:ring_b)   { create(:ring, ring_map: ring_map, position: 2) }

  let(:overlap_response) do
    JSON.generate({
      overlaps: [
        { ring_a_position: 1, ring_b_position: 2, shared_element: "Shared families.", cross_ring_idea: "Joint event." }
      ]
    })
  end

  before { sign_in_as(user) }

  it "replaces existing overlaps with regenerated ones" do
    ring_a; ring_b
    create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
    gemini_returns(overlap_response)

    expect {
      post regenerate_overlaps_ring_map_path(ring_map)
    }.not_to change(Ring, :count)

    expect(ring_map.reload.overlaps.count).to eq(1)
    expect(ring_map.overlaps_regenerated_at).to be_present
    expect(ring_map.gemini_raw_overlaps).to be_present
  end

  it "does not touch Rings or StarterInitiatives" do
    ring = create(:ring, :priority, ring_map: ring_map, position: 1)
    create(:starter_initiative, ring: ring)
    gemini_returns('{"overlaps":[]}')

    expect { post regenerate_overlaps_ring_map_path(ring_map) }
      .not_to change(StarterInitiative, :count)
    expect { post regenerate_overlaps_ring_map_path(ring_map) }
      .not_to change(Ring, :count)
  end

  it "calls overlap_regeneration_v1" do
    ring_a; ring_b
    expect(GeminiService).to receive(:generate).with(
      hash_including(template: "overlap_regeneration_v1")
    ).and_return('{"overlaps":[]}')
    post regenerate_overlaps_ring_map_path(ring_map)
  end

  it "returns 404 for another user" do
    other = create(:user)
    sign_in_as(other)
    post regenerate_overlaps_ring_map_path(ring_map)
    expect(response).to have_http_status(:not_found)
  end
end
```

---

## Manual Test Checklist

After completing Phase 6, verify the full demo end-to-end in the browser (requires real `GEMINI_API_KEY`):

### SVG Map
- [ ] The SVG canvas renders with Ring shapes (jittered circles, terracotta stroke)
- [ ] Each Ring is labeled with its name (truncated if > 16 chars)
- [ ] Hovering a Ring shape shows a Bootstrap tooltip with description
- [ ] Where two Rings have an overlap, an amber lens shape appears in their intersection
- [ ] Shapes are stable across page reloads (deterministic jitter)
- [ ] After adding a Ring (Phase 5), the new Ring appears in the SVG
- [ ] After deleting a Ring, it disappears from the SVG

### Overlap Regeneration
- [ ] Click "Regenerate overlaps" → spinner appears → page reloads with updated overlap count
- [ ] `overlaps_regenerated_at` timestamp appears in the header strip
- [ ] "Show raw response" shows the `gemini_raw_overlaps` JSON block
- [ ] StarterInitiatives are unchanged after regeneration
- [ ] Regeneration with budget exceeded → flash alert, no overlaps changed

### Full Layout
- [ ] All seven sections render in correct order
- [ ] "Show raw response" collapse works for both raw blocks
- [ ] "Start a fresh map" confirmation dialog appears; confirming generates a new map
- [ ] Dashboard (Branch 3) shows the latest Ring map inline at `/dashboard`
- [ ] The small italic disclaimer "This is a draft to argue with..." appears under the SVG

### Tests
- [ ] `bundle exec rspec spec/system/discovery_flow_spec.rb` — passes
- [ ] `bundle exec rspec spec/requests/ring_maps_spec.rb` — all tests pass
- [ ] `bundle exec rspec` — full suite passes with no real API calls
