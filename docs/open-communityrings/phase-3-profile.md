# Phase 3: Profile Feature

**Goal:** Build the full Profile feature: singleton resource routes, `ProfilesController`, profile show/edit views, and the Ring taxonomy reference partial. After this phase a user can create and edit their Profile, and the dashboard "Build your Profile" CTA works end-to-end.

---

## Files to Create or Modify

| Action | File |
|---|---|
| Modify | `config/routes.rb` |
| Create | `app/controllers/profiles_controller.rb` |
| Create | `app/views/profiles/show.html.erb` |
| Create | `app/views/profiles/edit.html.erb` |
| Create | `app/views/shared/_ring_taxonomy.html.erb` |
| Create | `spec/requests/profiles_spec.rb` |

---

## Routes

Profile is a **singleton resource** — one per user, no `:id` in the path.

```ruby
# config/routes.rb
resource :profile, only: [:show, :edit, :create, :update]
```

This generates:
- `GET  /profile`      → `profiles#show`
- `GET  /profile/edit` → `profiles#edit`
- `POST /profile`      → `profiles#create`
- `PATCH/PUT /profile` → `profiles#update`

Named helpers: `profile_path`, `edit_profile_path`.

---

## Controller — `app/controllers/profiles_controller.rb`

```ruby
class ProfilesController < ApplicationController
  before_action :require_authentication

  def show
    @profile = current_user.profile
    redirect_to edit_profile_path and return unless @profile
  end

  def edit
    @profile = current_user.profile || current_user.build_profile
  end

  def create
    @profile = current_user.build_profile(profile_params)
    if @profile.save
      redirect_to dashboard_path, notice: "Profile saved. You are ready to run Ring Discovery."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update
    @profile = current_user.profile
    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:profile).permit(
      :life_context, :family_situation, :neighborhood,
      :work_occupation, :interests, :values,
      :weekly_hours, :known_rings
    )
  end
end
```

---

## Views

### `app/views/profiles/show.html.erb`

A read-only view of all Profile fields. Empty optional fields show as "Not provided" in muted text.

```erb
<div class="container py-4">
  <div class="row">
    <div class="col-lg-8">
      <div class="d-flex justify-content-between align-items-center mb-4">
        <h1>My Profile</h1>
        <%= link_to "Edit Profile", edit_profile_path, class: "btn btn-outline-secondary btn-sm" %>
      </div>

      <% [
        ["Life context", @profile.life_context],
        ["Family situation", @profile.family_situation],
        ["Neighborhood", @profile.neighborhood],
        ["Work or main occupation", @profile.work_occupation],
        ["Hobbies and interests", @profile.interests],
        ["Values", @profile.values],
        ["Known rings", @profile.known_rings]
      ].each do |label, value| %>
        <div class="mb-4">
          <h6 class="text-uppercase text-muted small fw-semibold mb-1"><%= label %></h6>
          <% if value.present? %>
            <p class="mb-0"><%= value %></p>
          <% else %>
            <p class="mb-0 text-muted fst-italic">Not provided</p>
          <% end %>
        </div>
      <% end %>

      <div class="mb-4">
        <h6 class="text-uppercase text-muted small fw-semibold mb-1">Weekly hours available</h6>
        <p class="mb-0"><%= @profile.weekly_hours %> hours / week</p>
      </div>

      <div class="mt-4">
        <%= link_to "Go to My Map", dashboard_path, class: "btn btn-accent" %>
      </div>
    </div>
  </div>
</div>
```

### `app/views/profiles/edit.html.erb`

Bootstrap form with floating labels, large textareas, inline help text, and the taxonomy collapse. The form handles both create (when `@profile.new_record?`) and update.

```erb
<div class="container py-4">
  <div class="row justify-content-center">
    <div class="col-lg-8">
      <h1 class="mb-4"><%= @profile.new_record? ? "Build your Profile" : "Edit Profile" %></h1>

      <%= form_with model: @profile, url: @profile.new_record? ? profile_path : profile_path, method: @profile.new_record? ? :post : :patch do |f| %>

        <%# Validation errors %>
        <% if @profile.errors.any? %>
          <div class="alert alert-danger mb-4">
            <strong>Please fix the following:</strong>
            <ul class="mb-0 mt-1">
              <% @profile.errors.full_messages.each do |msg| %>
                <li><%= msg %></li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <%# Life context — required %>
        <div class="mb-4">
          <%= f.label :life_context, "Life context *", class: "form-label fw-semibold" %>
          <%= f.text_area :life_context, rows: 4,
              class: "form-control #{"is-invalid" if @profile.errors[:life_context].any?}",
              placeholder: "Career stage, life stage, recent transitions. What is the broad context of your life right now?" %>
          <div class="form-text">Required. Be specific — the AI uses this to choose communities that fit your actual situation, not a generic version of it.</div>
          <% if @profile.errors[:life_context].any? %>
            <div class="invalid-feedback"><%= @profile.errors[:life_context].first %></div>
          <% end %>
        </div>

        <%# Family situation %>
        <div class="mb-4">
          <%= f.label :family_situation, "Family situation", class: "form-label fw-semibold" %>
          <%= f.text_area :family_situation, rows: 3,
              class: "form-control #{"is-invalid" if @profile.errors[:family_situation].any?}",
              placeholder: "Household composition, dependents, caregiving responsibilities." %>
          <div class="form-text">Optional. Helps identify family and education Rings that fit your actual household.</div>
        </div>

        <%# Neighborhood %>
        <div class="mb-4">
          <%= f.label :neighborhood, "Neighborhood", class: "form-label fw-semibold" %>
          <%= f.text_area :neighborhood, rows: 3,
              class: "form-control #{"is-invalid" if @profile.errors[:neighborhood].any?}",
              placeholder: "Where you live, the type of place (urban, suburban, rural), how long you have been there." %>
          <div class="form-text">Optional. Named streets, local landmarks, or community names are helpful.</div>
        </div>

        <%# Work / occupation %>
        <div class="mb-4">
          <%= f.label :work_occupation, "Work or main occupation", class: "form-label fw-semibold" %>
          <%= f.text_area :work_occupation, rows: 3,
              class: "form-control #{"is-invalid" if @profile.errors[:work_occupation].any?}",
              placeholder: "What you do for work, where, and in what kind of setting (remote, in-person, self-employed, etc.)." %>
          <div class="form-text">Optional. Helps identify workplace and professional Rings.</div>
        </div>

        <%# Interests %>
        <div class="mb-4">
          <%= f.label :interests, "Hobbies and interests", class: "form-label fw-semibold" %>
          <%= f.text_area :interests, rows: 3,
              class: "form-control #{"is-invalid" if @profile.errors[:interests].any?}",
              placeholder: "Recreational pursuits, clubs, online communities, learning interests." %>
          <div class="form-text">Optional. Lists are fine: "trail running, board games, local history."</div>
        </div>

        <%# Values %>
        <div class="mb-4">
          <%= f.label :values, "Values", class: "form-label fw-semibold" %>
          <%= f.text_area :values, rows: 3,
              class: "form-control #{"is-invalid" if @profile.errors[:values].any?}",
              placeholder: "What kinds of contributions matter to you? Causes, places, kinds of people you want to invest in." %>
          <div class="form-text">Optional. Used to identify priority Rings and set Initiative goals.</div>
        </div>

        <%# Weekly hours — required %>
        <div class="mb-4">
          <%= f.label :weekly_hours, "Weekly hours available *", class: "form-label fw-semibold" %>
          <%= f.number_field :weekly_hours, min: 1, max: 40,
              class: "form-control #{"is-invalid" if @profile.errors[:weekly_hours].any?}",
              placeholder: "1–40" %>
          <div class="form-text">Required. How many hours per week can you realistically spend on community contribution? Be honest — this shapes what Initiatives the AI suggests.</div>
          <% if @profile.errors[:weekly_hours].any? %>
            <div class="invalid-feedback"><%= @profile.errors[:weekly_hours].first %></div>
          <% end %>
        </div>

        <%# Known rings %>
        <div class="mb-4">
          <%= f.label :known_rings, "Communities you already know you want on the map", class: "form-label fw-semibold" %>
          <%= f.text_area :known_rings, rows: 3,
              class: "form-control #{"is-invalid" if @profile.errors[:known_rings].any?}",
              placeholder: "e.g. Cedar Street block, Lincoln Elementary PTA, Tuesday running club" %>
          <div class="form-text">Optional. Name specific groups, clubs, or gatherings. The AI will include them and may add others you did not mention.</div>
        </div>

        <%# Taxonomy reference collapse %>
        <div class="mb-4">
          <a class="text-muted small" data-bs-toggle="collapse" href="#ring-taxonomy" role="button">
            What kinds of communities count? ▾
          </a>
          <div class="collapse mt-2" id="ring-taxonomy">
            <%= render "shared/ring_taxonomy" %>
          </div>
        </div>

        <div class="d-flex gap-2">
          <%= f.submit @profile.new_record? ? "Build Profile" : "Save Profile",
              class: "btn btn-accent" %>
          <% unless @profile.new_record? %>
            <%= link_to "Cancel", profile_path, class: "btn btn-outline-secondary" %>
          <% end %>
        </div>

      <% end %>
    </div>
  </div>
</div>
```

### `app/views/shared/_ring_taxonomy.html.erb`

A reference card listing all fifteen Ring types with one-sentence definitions. Rendered inside the Bootstrap collapse on the Profile form.

```erb
<div class="card card-body small">
  <p class="text-muted mb-2 fw-semibold">The fifteen Ring types:</p>
  <dl class="row mb-0 small">
    <dt class="col-sm-4">Family</dt>
    <dd class="col-sm-8">Immediate and extended family, however you define it.</dd>

    <dt class="col-sm-4">Neighborhood</dt>
    <dd class="col-sm-8">People who share a block, building, street, or district with you.</dd>

    <dt class="col-sm-4">Civic</dt>
    <dd class="col-sm-8">Local government, city councils, civic associations, town halls.</dd>

    <dt class="col-sm-4">Workplace</dt>
    <dd class="col-sm-8">Your team, company, or organization where you spend your working hours.</dd>

    <dt class="col-sm-4">Professional</dt>
    <dd class="col-sm-8">Your industry, trade association, or professional peer group beyond your current employer.</dd>

    <dt class="col-sm-4">Faith / Values</dt>
    <dd class="col-sm-8">A congregation, ethical society, or community organized around shared beliefs or values.</dd>

    <dt class="col-sm-4">Education</dt>
    <dd class="col-sm-8">Schools, PTAs, alumni groups, or learning communities you are currently part of.</dd>

    <dt class="col-sm-4">Sports & Rec</dt>
    <dd class="col-sm-8">A team, league, club, or regular group that plays or trains together.</dd>

    <dt class="col-sm-4">Arts & Culture</dt>
    <dd class="col-sm-8">A band, choir, theater group, makers collective, or other creative community.</dd>

    <dt class="col-sm-4">Health & Wellness</dt>
    <dd class="col-sm-8">A fitness class, support group, or health-focused community you participate in.</dd>

    <dt class="col-sm-4">Hobby / Interest</dt>
    <dd class="col-sm-8">A club or recurring group organized around a shared hobby or pastime.</dd>

    <dt class="col-sm-4">Online / Digital</dt>
    <dd class="col-sm-8">A forum, Discord, subreddit, or other digital community where you are an active participant.</dd>

    <dt class="col-sm-4">Cause-Based</dt>
    <dd class="col-sm-8">An advocacy group, campaign, or movement organized around a specific issue or cause.</dd>

    <dt class="col-sm-4">Service / Volunteer</dt>
    <dd class="col-sm-8">A volunteer organization, food bank, mutual aid network, or other service community.</dd>

    <dt class="col-sm-4">Mentorship</dt>
    <dd class="col-sm-8">A mentoring relationship, apprenticeship circle, or coaching group.</dd>
  </dl>
</div>
```

---

## RSpec Tests

### `spec/requests/profiles_spec.rb`

```ruby
RSpec.describe "Profiles", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /profile" do
    context "when not signed in" do
      it "redirects to sign in" do
        get profile_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in without a profile" do
      before { sign_in_as(user) }

      it "redirects to edit" do
        get profile_path
        expect(response).to redirect_to(edit_profile_path)
      end
    end

    context "when signed in with a profile" do
      before do
        sign_in_as(user)
        create(:profile, user: user)
      end

      it "returns 200" do
        get profile_path
        expect(response).to have_http_status(:ok)
      end

      it "shows the user's life_context" do
        get profile_path
        expect(response.body).to include("Mid-career developer")
      end
    end
  end

  describe "GET /profile/edit" do
    context "when not signed in" do
      it "redirects to sign in" do
        get edit_profile_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in without a profile" do
      before { sign_in_as(user) }

      it "renders the new-profile form" do
        get edit_profile_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Build your Profile")
      end
    end

    context "when signed in with an existing profile" do
      before do
        sign_in_as(user)
        create(:profile, user: user)
      end

      it "renders the edit form" do
        get edit_profile_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Edit Profile")
      end
    end
  end

  describe "POST /profile" do
    before { sign_in_as(user) }

    context "with valid params" do
      let(:valid_params) do
        {
          profile: {
            life_context: "Mid-career developer looking to be more rooted in the community.",
            weekly_hours: 4
          }
        }
      end

      it "creates a Profile and redirects to dashboard" do
        expect { post profile_path, params: valid_params }
          .to change(Profile, :count).by(1)
        expect(response).to redirect_to(dashboard_path)
      end

      it "associates the profile with the current user" do
        post profile_path, params: valid_params
        expect(user.reload.profile).to be_present
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors when life_context is missing" do
        post profile_path, params: { profile: { weekly_hours: 4 } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
      end

      it "does not create a Profile" do
        expect {
          post profile_path, params: { profile: { life_context: "" } }
        }.not_to change(Profile, :count)
      end
    end
  end

  describe "PATCH /profile" do
    before do
      sign_in_as(user)
      create(:profile, user: user)
    end

    context "with valid params" do
      it "updates the profile and redirects to show" do
        patch profile_path, params: { profile: { weekly_hours: 8 } }
        expect(response).to redirect_to(profile_path)
        expect(user.profile.reload.weekly_hours).to eq(8)
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors" do
        patch profile_path, params: { profile: { weekly_hours: 100 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "profile isolation between users" do
    it "does not mix profiles between users" do
      sign_in_as(user)
      post profile_path, params: { profile: { life_context: "User one context here, enough characters.", weekly_hours: 3 } }

      sign_in_as(other_user)
      get profile_path
      expect(response).to redirect_to(edit_profile_path)
    end
  end
end
```

---

## Manual Test Checklist

After completing Phase 3, verify in the browser:

- [ ] `GET /profile` while not signed in → redirects to sign in
- [ ] Sign in, visit `/profile` with no profile → redirects to `/profile/edit` showing "Build your Profile"
- [ ] Submit the form with no `life_context` → form re-renders with validation error inline
- [ ] Submit with `weekly_hours: 99` → validation error for out-of-range
- [ ] Submit a valid form → redirect to dashboard with flash "Profile saved"
- [ ] Dashboard now shows "Run Ring Discovery" CTA (Branch 2 of the router view)
- [ ] Visit `/profile` again → shows read-only view with all entered fields
- [ ] Fields not entered show "Not provided" in muted italic text
- [ ] Click "Edit Profile" → form pre-fills with existing values
- [ ] "What kinds of communities count?" collapse opens and shows all 15 Ring types
- [ ] Saving an edit redirects to `/profile` with flash "Profile updated"
- [ ] Sign in as a second user → their profile is empty, independent of the first user
- [ ] Navbar "My Profile" link works
