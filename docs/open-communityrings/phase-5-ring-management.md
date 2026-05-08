# Phase 5: Ring Management (Turbo Streams)

**Goal:** Build the full `RingsController` with `create`, `update`, `destroy`, and `toggle_priority` actions — all responding with Turbo Streams so the Ring list updates without a full page reload. Add the `priority_toggle_controller.js` Stimulus controller and the inline Ring edit/add Turbo Frames. No AI calls in this phase.

---

## Files to Create or Modify

| Action | File |
|---|---|
| Modify | `config/routes.rb` |
| Create | `app/controllers/rings_controller.rb` |
| Create | `app/views/rings/_form.html.erb` |
| Create | `app/views/rings/create.turbo_stream.erb` |
| Create | `app/views/rings/update.turbo_stream.erb` |
| Create | `app/views/rings/destroy.turbo_stream.erb` |
| Create | `app/views/rings/toggle_priority.turbo_stream.erb` |
| Modify | `app/views/ring_maps/_ring.html.erb` |
| Modify | `app/views/ring_maps/show.html.erb` |
| Create | `app/javascript/controllers/priority_toggle_controller.js` |
| Create | `spec/requests/rings_spec.rb` |

---

## Pattern Reference

Before writing any code, review:
- [`docs/turbo-stimulus-patterns.md`](../turbo-stimulus-patterns.md) — Turbo Stream rules (always `update()`, never `replace()`)
- `CLAUDE.md` — "TURBO STREAM: ALWAYS `update()`, NEVER `replace()`"
- [`docs/turbo-stimulus-patterns.md`](../turbo-stimulus-patterns.md) — Stimulus controller patterns, `window.bootstrap`, dispose in `disconnect()`

---

## 1. Routes

Add to `config/routes.rb`:

```ruby
resources :rings, only: [:create, :update, :destroy] do
  member do
    patch :toggle_priority
  end
end
```

`rings#create` is nested under `ring_maps` via `ring_map_id` in the URL (see controller). The routes above are unnested for `update`, `destroy`, and `toggle_priority` since the Ring ID is sufficient to scope ownership in the controller.

Update the `ring_maps` resource block to add the nested `rings#create` route:

```ruby
resources :ring_maps, only: [:create, :show, :destroy] do
  member do
    post :regenerate_overlaps
  end
  resources :rings, only: [:create]
end
```

This gives `POST /ring_maps/:ring_map_id/rings` for create and keeps `PATCH/DELETE /rings/:id` for update and destroy.

---

## 2. Controller — `app/controllers/rings_controller.rb`

```ruby
class RingsController < ApplicationController
  before_action :require_authentication
  before_action :load_ring_map, only: [:create]
  before_action :load_ring,     only: [:update, :destroy, :toggle_priority]

  def create
    @ring = @ring_map.rings.build(ring_params)
    @ring.source = "user_added"
    @ring.position = (@ring_map.rings.maximum(:position) || 0) + 1

    if @ring.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to ring_map_path(@ring_map) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("ring-form-errors",
            partial: "rings/errors", locals: { ring: @ring })
        end
        format.html { redirect_to ring_map_path(@ring_map), alert: "Could not add Ring." }
      end
    end
  end

  def update
    @ring_map = @ring.ring_map
    if @ring.update(ring_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to ring_map_path(@ring_map) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("ring-#{@ring.id}-edit",
            partial: "rings/form", locals: { ring: @ring, ring_map: @ring_map })
        end
        format.html { redirect_to ring_map_path(@ring_map), alert: "Could not save Ring." }
      end
    end
  end

  def destroy
    @ring_map = @ring.ring_map
    @ring.destroy
    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to ring_map_path(@ring_map),
          notice: "Ring removed. #{view_context.link_to('Regenerate overlaps', regenerate_overlaps_ring_map_path(@ring_map), data: { turbo_method: :post })}"
      end
    end
  end

  def toggle_priority
    @ring_map = @ring.ring_map
    @ring.update!(is_priority: !@ring.is_priority)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to ring_map_path(@ring_map) }
    end
  end

  private

  def load_ring_map
    @ring_map = current_user.profile&.ring_maps&.find_by(id: params[:ring_map_id])
    render file: Rails.public_path.join("404.html"), status: :not_found unless @ring_map
  end

  def load_ring
    ring = Ring.find_by(id: params[:id])
    if ring && ring.ring_map.profile.user_id == current_user.id
      @ring = ring
    else
      render file: Rails.public_path.join("404.html"), status: :not_found
    end
  end

  def ring_params
    params.require(:ring).permit(:name, :ring_type, :description, :rationale)
  end
end
```

---

## 3. Turbo Stream Views

### `app/views/rings/create.turbo_stream.erb`

Appends the new Ring to the list and clears the add-ring form:

```erb
<%= turbo_stream.append "ring-list" do %>
  <%= render "ring_maps/ring", ring: @ring %>
<% end %>
<%= turbo_stream.update "add-ring-form" do %>
  <%# Clear the form after successful submission %>
<% end %>
<%= turbo_stream.update "flash" do %>
  <div class="alert alert-success alert-dismissible fade show">
    "<%= @ring.name %>" added to your Ring map.
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  </div>
<% end %>
```

### `app/views/rings/update.turbo_stream.erb`

Replaces the Ring's list item with the updated version and exits edit mode:

```erb
<%= turbo_stream.update "ring-#{@ring.id}" do %>
  <%= render "ring_maps/ring", ring: @ring %>
<% end %>
<%= turbo_stream.update "flash" do %>
  <div class="alert alert-success alert-dismissible fade show">
    Ring updated.
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  </div>
<% end %>
```

### `app/views/rings/destroy.turbo_stream.erb`

Removes the Ring's row and shows a flash with a "Regenerate overlaps" link:

```erb
<%= turbo_stream.remove "ring-#{@ring.id}" %>
<%= turbo_stream.update "flash" do %>
  <div class="alert alert-warning alert-dismissible fade show">
    Ring removed.
    <%= link_to "Regenerate overlaps", regenerate_overlaps_ring_map_path(@ring_map), data: { turbo_method: :post }, class: "alert-link" %>
    after editing Rings to keep your Overlap list accurate.
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  </div>
<% end %>
```

### `app/views/rings/toggle_priority.turbo_stream.erb`

Updates only the priority button and badge for this Ring:

```erb
<%= turbo_stream.update "ring-priority-#{@ring.id}" do %>
  <%= render "ring_maps/ring_priority_cell", ring: @ring %>
<% end %>
```

---

## 4. Updated Ring Partial — `app/views/ring_maps/_ring.html.erb`

Replace the Phase 4 version with the fully-interactive version that includes inline edit (Turbo Frame), priority toggle, and delete controls:

```erb
<li class="list-group-item" id="ring-<%= ring.id %>">
  <%= turbo_frame_tag "ring-#{ring.id}-edit" do %>
    <div class="d-flex justify-content-between align-items-start gap-2">
      <div class="flex-grow-1">
        <span class="me-2 text-muted small"><%= ring.position %>.</span>
        <strong><%= ring.name %></strong>
        <%= ring_type_badge(ring.ring_type) %>
        <span id="ring-priority-<%= ring.id %>">
          <%= render "ring_maps/ring_priority_cell", ring: ring %>
        </span>
        <p class="mb-1 mt-1 small"><%= ring.description %></p>
        <p class="mb-0 text-muted small fst-italic"><%= ring.rationale %></p>
      </div>
      <div class="d-flex gap-1 flex-shrink-0">
        <%# Priority toggle %>
        <%= button_to toggle_priority_ring_path(ring),
            method: :patch,
            class: "btn btn-sm #{ring.is_priority ? 'btn-accent' : 'btn-outline-secondary'}",
            title: ring.is_priority ? "Unmark as priority" : "Mark as priority",
            data: { controller: "priority-toggle" } do %>
          <%= ring.is_priority ? "★ Priority" : "☆ Priority" %>
        <% end %>
        <%# Edit — loads inline form in this Turbo Frame %>
        <%= link_to "Edit", edit_ring_form_path(ring),
            data: { turbo_frame: "ring-#{ring.id}-edit" },
            class: "btn btn-sm btn-outline-secondary" if false # replaced below %>
        <%# Inline edit trigger: we use a button that submits to a custom path or toggles a frame %>
        <%# Simplest pattern: link pointing to a rings#edit route that renders the form partial %>
        <%# For now, use a direct edit button that renders the form inside the frame %>
        <%= link_to "Edit", "#",
            class: "btn btn-sm btn-outline-secondary",
            data: {
              action: "click->priority-toggle#openEdit",
              ring_id: ring.id
            } %>
        <%# Delete %>
        <%= link_to ring_path(ring),
            data: { turbo_method: :delete, turbo_confirm: "Remove \"#{ring.name}\" from the map?" },
            class: "btn btn-sm btn-outline-danger" do %>
          ✕
        <% end %>
      </div>
    </div>
  <% end %>
</li>
```

> **Implementation note on inline edit:** The cleanest Turbo Frame pattern for inline editing is to add a `GET /rings/:id/edit` route that renders `rings/edit.html.erb` (just the form partial wrapped in the `turbo_frame_tag "ring-:id-edit"`). Then the "Edit" link targets that frame. Add `resources :rings, only: [:edit]` to get the `edit_ring_path` helper, and create `app/views/rings/edit.html.erb`:
>
> ```erb
> <%= turbo_frame_tag "ring-#{@ring.id}-edit" do %>
>   <%= render "rings/form", ring: @ring, ring_map: @ring.ring_map %>
> <% end %>
> ```
>
> Update routes to include `edit`:
> ```ruby
> resources :rings, only: [:edit, :update, :destroy] do
>   member { patch :toggle_priority }
> end
> ```
>
> Then in the ring partial, the "Edit" link becomes:
> ```erb
> <%= link_to "Edit", edit_ring_path(ring),
>     data: { turbo_frame: "ring-#{ring.id}-edit" },
>     class: "btn btn-sm btn-outline-secondary" %>
> ```

### `app/views/ring_maps/_ring_priority_cell.html.erb`

A small partial that renders just the priority badge, targeted by `toggle_priority.turbo_stream.erb`:

```erb
<% if ring.is_priority %>
  <span class="badge text-bg-warning ms-1">Priority</span>
<% end %>
```

---

## 5. Ring Form Partial — `app/views/rings/_form.html.erb`

Used for both the "Add a Ring" form and the inline edit form:

```erb
<%= form_with model: ring,
    url: ring.new_record? ? ring_map_rings_path(ring_map) : ring_path(ring),
    method: ring.new_record? ? :post : :patch do |f| %>

  <% if ring.errors.any? %>
    <div id="ring-form-errors" class="alert alert-danger py-2 small">
      <ul class="mb-0">
        <% ring.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="row g-2 mb-2">
    <div class="col-md-5">
      <%= f.text_field :name, placeholder: "Ring name", class: "form-control form-control-sm" %>
    </div>
    <div class="col-md-4">
      <%= f.select :ring_type,
          Ring::RING_TYPES.map { |t| [ring_type_label(t), t] },
          { include_blank: "Ring type…" },
          class: "form-select form-select-sm" %>
    </div>
  </div>
  <div class="mb-2">
    <%= f.text_area :description, placeholder: "Description (1–3 sentences on what this Ring is and who is in it)", rows: 2, class: "form-control form-control-sm" %>
  </div>
  <div class="mb-2">
    <%= f.text_area :rationale, placeholder: "Rationale (one sentence on why this Ring belongs on your map)", rows: 2, class: "form-control form-control-sm" %>
  </div>
  <div class="d-flex gap-1">
    <%= f.submit ring.new_record? ? "Add Ring" : "Save", class: "btn btn-accent btn-sm" %>
    <% unless ring.new_record? %>
      <%= link_to "Cancel", "#", data: { action: "click->priority-toggle#cancelEdit", ring_id: ring.id }, class: "btn btn-outline-secondary btn-sm" %>
    <% end %>
  </div>
<% end %>
```

### "Add a Ring" Section in `show.html.erb`

Replace the Phase 4 placeholder in the card footer:

```erb
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
```

---

## 6. Stimulus Controller — `app/javascript/controllers/priority_toggle_controller.js`

Manages the optimistic UI state of the priority button while the form submits. Bootstrap dispose pattern is followed since no Bootstrap components are used here — this controller is simple.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // No initialization needed — all state is in the DOM via Turbo Stream updates
  }
}
```

> **Note:** The priority toggle button already uses `button_to` which submits a Turbo Stream form. The Turbo Stream response updates the DOM. No complex Stimulus state is needed. The controller is a named placeholder for future enhancement (e.g., optimistic toggling before the server responds). Keep it minimal.

---

## 7. RSpec Tests

### `spec/requests/rings_spec.rb`

```ruby
RSpec.describe "Rings", type: :request do
  let(:user)     { create(:user) }
  let(:profile)  { create(:profile, user: user) }
  let(:ring_map) { create(:ring_map, profile: profile) }
  let(:ring)     { create(:ring, ring_map: ring_map, position: 1) }

  describe "POST /ring_maps/:ring_map_id/rings" do
    context "when not signed in" do
      it "redirects to sign in" do
        post ring_map_rings_path(ring_map), params: { ring: { name: "New Ring" } }
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "creates a Ring with source user_added and the next position" do
        ring  # ensure ring_map exists with one ring
        expect {
          post ring_map_rings_path(ring_map),
               params: { ring: { name: "New neighborhood ring", ring_type: "neighborhood", description: "A small group of neighbors on Cedar Street.", rationale: "You have lived here for three years." } },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Ring, :count).by(1)

        new_ring = Ring.last
        expect(new_ring.source).to eq("user_added")
        expect(new_ring.position).to eq(2)
      end

      it "returns a Turbo Stream response" do
        post ring_map_rings_path(ring_map),
             params: { ring: { name: "New Ring", ring_type: "neighborhood", description: "Some neighbors.", rationale: "You live there." } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "returns 404 when trying to add to another user's ring map" do
        other = create(:user)
        sign_in_as(other)
        post ring_map_rings_path(ring_map),
             params: { ring: { name: "Intrusion ring", ring_type: "civic", description: "Unauthorized.", rationale: "Not yours." } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /rings/:id" do
    before { sign_in_as(user) }

    it "updates the Ring and returns a Turbo Stream" do
      ring
      patch ring_path(ring),
            params: { ring: { name: "Updated name", ring_type: ring.ring_type, description: ring.description, rationale: ring.rationale } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(ring.reload.name).to eq("Updated name")
    end

    it "returns 404 if another user tries to edit" do
      ring
      other = create(:user)
      sign_in_as(other)
      patch ring_path(ring), params: { ring: { name: "Hacked" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /rings/:id" do
    before { sign_in_as(user) }

    it "destroys the Ring and cascades to overlaps and initiatives" do
      ring_b = create(:ring, ring_map: ring_map, position: 2)
      create(:overlap, ring_map: ring_map, ring_a: ring, ring_b: ring_b)
      create(:starter_initiative, ring: ring)

      expect { delete ring_path(ring), headers: { "Accept" => "text/vnd.turbo-stream.html" } }
        .to change(Ring, :count).by(-1)
        .and change(Overlap, :count).by(-1)
        .and change(StarterInitiative, :count).by(-1)
    end

    it "returns a Turbo Stream response" do
      delete ring_path(ring), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "returns 404 if another user tries to delete" do
      other = create(:user)
      sign_in_as(other)
      delete ring_path(ring)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /rings/:id/toggle_priority" do
    before { sign_in_as(user) }

    it "flips is_priority and does not call Gemini" do
      expect(GeminiService).not_to receive(:generate)
      patch toggle_priority_ring_path(ring),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(ring.reload.is_priority).to be true
    end

    it "toggles back to false on second call" do
      ring.update!(is_priority: true)
      patch toggle_priority_ring_path(ring),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(ring.reload.is_priority).to be false
    end

    it "returns 404 if another user tries to toggle" do
      other = create(:user)
      sign_in_as(other)
      patch toggle_priority_ring_path(ring)
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

---

## Manual Test Checklist

After completing Phase 5, verify in the browser:

- [ ] The Ring map show page has a "+ Add a Ring" button in the card footer
- [ ] Clicking "+ Add a Ring" expands the form inline (Bootstrap collapse)
- [ ] Filling in all fields and submitting appends the new Ring to the list without a page reload
- [ ] The new Ring appears with position = (max existing position + 1)
- [ ] New Ring's "source" is `user_added` (verify in Rails console: `Ring.last.source`)
- [ ] Leaving the name field blank and submitting shows inline validation errors
- [ ] Clicking "Edit" on a Ring replaces that row with the edit form inline (Turbo Frame)
- [ ] Saving the edit updates the row in place without a page reload
- [ ] Clicking "Cancel" on the edit form restores the original row
- [ ] Clicking the delete icon (✕) shows a confirmation dialog
- [ ] Confirming delete removes the Ring row; flash appears with "Regenerate overlaps" link
- [ ] The "Regenerate overlaps" link in the flash leads to Phase 6's endpoint (currently 501 Not Implemented — acceptable)
- [ ] Clicking "☆ Priority" toggles the Ring to priority (button turns terracotta, badge appears)
- [ ] Clicking "★ Priority" on a priority Ring unmarks it
- [ ] Priority toggling does NOT reload the page or create a StarterInitiative
- [ ] All actions return 404 when a second user attempts them via direct URL manipulation
- [ ] `bundle exec rspec spec/requests/rings_spec.rb` — all tests pass
