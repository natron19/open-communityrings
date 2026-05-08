# Phase 1: Boilerplate Customizations

**Goal:** Apply all CommunityRings-specific overrides to the Open Demo Starter shell before any domain code exists. After this phase the app boots, the landing page reflects the CommunityRings brand, and the dashboard renders the correct empty-state shell.

---

## Files to Create or Modify

| Action | File |
|---|---|
| Modify | `.env.example` |
| Modify | `.env` (local only, not committed) |
| Modify | `app/assets/stylesheets/application.css` |
| Modify | `app/views/layouts/application.html.erb` (navbar links) |
| Replace | `app/views/home/index.html.erb` |
| Replace | `app/views/dashboard/show.html.erb` |

---

## 1. Environment Variables

In `.env.example` (and your local `.env`), set:

```
APP_NAME=CommunityRings Demo
APP_TAGLINE=Map your communities. See where they overlap. Pick where to serve.
APP_DESCRIPTION=CommunityRings Demo is a single-feature open source Rails 8 app that helps a person see all of the communities they belong to at once and pick where to take ownership of their contribution. You fill out a short Profile, one AI call returns a draft Ring map, and you edit aggressively. The AI drafts; you pick.
```

All views must read these via `ENV.fetch("APP_NAME", "Open Demo Starter")`. Never hardcode "CommunityRings Demo" anywhere.

---

## 2. Accent Colors (Plain CSS)

> **Note:** This boilerplate uses Propshaft with no SCSS compilation. All styles go in plain `.css` files. The spec v1 references `.scss` files — ignore that; use `.css` instead.

Append to `app/assets/stylesheets/application.css`:

```css
:root {
  --accent: #a3501f;
  --accent-hover: #7c3a16;
  --secondary-accent: #15803d;
  --overlap-accent: #f59e0b;
}

.btn-accent {
  background-color: var(--accent);
  border-color: var(--accent);
  color: #fff;
}
.btn-accent:hover {
  background-color: var(--accent-hover);
  border-color: var(--accent-hover);
  color: #fff;
}
a { color: var(--accent); }
a:hover { color: var(--accent-hover); }
.nav-link.active { color: var(--accent) !important; }
input:focus, textarea:focus, select:focus {
  border-color: var(--accent) !important;
  box-shadow: 0 0 0 0.25rem rgba(163, 80, 31, 0.25) !important;
}
```

The full custom styles for SVG rings, overlap lens, and initiative note-cards are added in Phase 6. Only put foundational accent-color rules here.

---

## 3. Navbar

In `app/views/layouts/application.html.erb`, update the signed-in nav links:

- Rename the boilerplate `Dashboard` link to `My Map` — keep it pointing to `dashboard_path`
- Add `My Profile` link pointing to `profile_path` (this route does not exist yet; the link will 404 until Phase 3 — that is acceptable for now)

Do not change the admin dropdown, the sign-out link, or the brand name rendering.

The brand name must render `ENV.fetch("APP_NAME", "CommunityRings Demo")`.

---

## 4. Landing Page — `home/index.html.erb`

Replace the boilerplate landing page with:

```erb
<div class="container py-5">

  <%# Hero %>
  <div class="row justify-content-center text-center mb-5">
    <div class="col-lg-8">
      <h1 class="display-4 fw-bold mb-3"><%= ENV.fetch("APP_NAME", "CommunityRings Demo") %></h1>
      <p class="lead mb-4"><%= ENV.fetch("APP_TAGLINE", "") %></p>
      <%= link_to "Build your Ring map", sign_up_path, class: "btn btn-accent btn-lg" %>
    </div>
  </div>

  <%# Three-card explainer %>
  <div class="row g-4 mb-5">
    <div class="col-md-4">
      <div class="card h-100">
        <div class="card-body">
          <h5 class="card-title">1. Build a Profile</h5>
          <p class="card-text text-muted">Tell us about your life context, neighborhood, work, hobbies, values, and how many hours a week you can realistically give.</p>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card h-100">
        <div class="card-body">
          <h5 class="card-title">2. See your map</h5>
          <p class="card-text text-muted">One AI call returns a draft Ring map: five to nine communities you already belong to, the overlaps among them, and a starter initiative for each of two priority Rings.</p>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card h-100">
        <div class="card-body">
          <h5 class="card-title">3. Pick where to serve</h5>
          <p class="card-text text-muted">Edit aggressively. Drop Rings that do not fit. Add ones the AI missed. Mark two as priority. The AI drafts; you pick.</p>
        </div>
      </div>
    </div>
  </div>

  <%# Screenshot placeholder %>
  <div class="row justify-content-center mb-5">
    <div class="col-lg-10">
      <div class="card">
        <div class="card-body text-center text-muted py-5">
          <p class="mb-0"><em>[Screenshot of the Ring map view — the hand-drawn SVG cluster with amber overlap regions, the Ring list, the Overlap card, and Starter Initiatives. Replace this placeholder once the UI is built.]</em></p>
        </div>
      </div>
    </div>
  </div>

  <%# Footer CTA %>
  <div class="row justify-content-center text-center">
    <div class="col-md-6">
      <p class="text-muted mb-3">Already have an account?</p>
      <%= link_to "Sign in", sign_in_path, class: "btn btn-outline-secondary" %>
      &nbsp;
      <%= link_to "Sign up free", sign_up_path, class: "btn btn-accent" %>
    </div>
  </div>

</div>
```

---

## 5. Dashboard Router View — `dashboard/show.html.erb`

Replace the boilerplate dashboard with a three-branch router. Domain objects (`Profile`, `RingMap`) do not exist yet — use a placeholder that will be wired up in later phases:

```erb
<div class="container py-4">
  <% if current_user.respond_to?(:profile) && current_user.profile.nil? %>

    <%# Branch 1: No Profile yet %>
    <div class="row justify-content-center">
      <div class="col-md-6">
        <div class="card text-center py-5">
          <div class="card-body">
            <h4 class="mb-3">You have not built a Profile yet.</h4>
            <p class="text-muted mb-4">Tell us about your communities and we will draft your Ring map.</p>
            <%= link_to "Build your Profile", edit_profile_path, class: "btn btn-accent btn-lg" %>
          </div>
        </div>
      </div>
    </div>

  <% elsif current_user.respond_to?(:profile) && current_user.profile&.ring_maps&.none? %>

    <%# Branch 2: Profile exists, no map yet %>
    <div class="row justify-content-center">
      <div class="col-md-8">
        <div class="card text-center py-5">
          <div class="card-body">
            <h4 class="mb-3">Your Profile is ready. Time to build your Ring map.</h4>
            <p class="text-muted mb-4">This will take about 15 seconds. The AI will draft five to nine Rings drawn from your Profile.</p>
            <%= button_to "Run Ring Discovery", ring_maps_path, method: :post,
                class: "btn btn-accent btn-lg",
                data: { turbo_submits_with: "Running…" } %>
          </div>
        </div>
      </div>
    </div>

  <% elsif current_user.respond_to?(:profile) && current_user.profile&.ring_maps&.any? %>

    <%# Branch 3: Latest Ring map exists — rendered inline here in Phase 6 %>
    <%# For now, redirect to the most recent map %>
    <% redirect_to ring_map_path(current_user.profile.ring_maps.first) %>

  <% else %>

    <%# Fallback: Profile not yet set up (before Phase 2 models exist) %>
    <div class="row justify-content-center">
      <div class="col-md-6">
        <div class="card text-center py-5">
          <div class="card-body">
            <h4 class="mb-3">Welcome to <%= ENV.fetch("APP_NAME", "CommunityRings Demo") %></h4>
            <p class="text-muted">Setup is in progress. Come back after Phase 2.</p>
          </div>
        </div>
      </div>
    </div>

  <% end %>
</div>
```

> **Note:** The `redirect_to` in Branch 3 is a temporary approach. In Phase 6, the latest Ring map will render inline (no redirect). Replace it then.

> **Note:** The `edit_profile_path`, `ring_maps_path`, and `ring_map_path` helpers do not exist yet. The view will raise `NoMethodError` if Branch 1 or 2 is hit before Phase 3. That is acceptable — the fallback branch will render.

---

## Routes

No new routes in this phase. The boilerplate's existing routes are unchanged.

---

## RSpec Tests

### `spec/requests/home_spec.rb`

Verify the landing page renders correctly:

```ruby
RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns 200" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "includes the app name from ENV" do
      get root_path
      expect(response.body).to include(ENV.fetch("APP_NAME", "CommunityRings Demo"))
    end

    it "includes the tagline from ENV" do
      get root_path
      expect(response.body).to include("Map your communities")
    end

    it "includes links to sign up and sign in" do
      get root_path
      expect(response.body).to include(sign_up_path)
      expect(response.body).to include(sign_in_path)
    end
  end
end
```

### `spec/requests/dashboard_spec.rb`

Update or add a test covering the fallback branch:

```ruby
RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to sign in" do
        get dashboard_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

---

## Manual Test Checklist

After completing Phase 1, verify the following manually in the browser:

- [ ] `rails db:seed && bin/dev` boots without errors
- [ ] `GET /` renders the landing page with the CommunityRings tagline
- [ ] The three explainer cards are visible
- [ ] Navbar shows "CommunityRings Demo" as the brand name
- [ ] Accent color (terracotta, `#a3501f`) is visible on the primary CTA button
- [ ] Sign up, sign in, and sign out flows still work
- [ ] After signing in, the dashboard renders the fallback "Setup is in progress" card without crashing
- [ ] Admin panel at `/admin` still loads for an admin user
- [ ] `GET /up` and `GET /up/llm` still return 200
- [ ] No JavaScript console errors on any page
