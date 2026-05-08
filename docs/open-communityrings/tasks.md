# CommunityRings Demo — Build Tasks

Tracks progress through all seven build phases. Mark each item `[x]` when complete.

Spec source: `docs/open-communityrings/CommunityRings_Demo_Spec_v1.md`
Phase specs: `docs/open-communityrings/phase-1-setup.md` through `phase-7-seed-data-readme.md`

---

## Phase 1 — Boilerplate Customizations
*Spec: `phase-1-setup.md`*

- [x] `.env.example` updated with `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION`
- [x] Local `.env` updated to match
- [x] Accent CSS variables added to `application.css` (terracotta `#a3501f`, hover, secondary, overlap)
- [x] `.btn-accent`, link colors, focus rings added to `application.css`
- [x] Navbar: brand reads `ENV.fetch("APP_NAME")` (not hardcoded)
- [x] Navbar: `Dashboard` link renamed to `My Map`
- [x] Navbar: `My Profile` link added (pointing to `profile_path`)
- [x] `home/index.html.erb` replaced (hero, three cards, screenshot placeholder, footer CTA)
- [x] `dashboard/show.html.erb` replaced with three-branch router (fallback branch only for now)
- [x] **RSpec:** `spec/requests/home_spec.rb` written and passing
- [x] **RSpec:** `spec/requests/dashboard_spec.rb` updated and passing
- [ ] **Manual tests:** All items in phase-1-setup.md checklist verified

---

## Phase 2 — Data Models & Migrations
*Spec: `phase-2-data-models.md`*

- [x] Migration: `create_profiles` (UUID PK, unique `user_id` index)
- [x] Migration: `create_ring_maps` (`generated_at` index)
- [x] Migration: `create_rings` (unique position+ring_map_id index)
- [x] Migration: `create_overlaps` (unique ring_map_id+ring_a_id+ring_b_id index)
- [x] Migration: `create_starter_initiatives`
- [x] `rails db:migrate` — all five migrations up
- [x] Model: `Profile` (validations, `belongs_to :user`, `has_many :ring_maps`)
- [x] Model: `RingMap` (validations, associations, `default_scope`)
- [x] Model: `Ring` (`RING_TYPES`, `SOURCES` constants, validations, associations, `default_scope`)
- [x] Model: `Overlap` (validations including custom `rings_must_differ` and `pair_unique_within_ring_map`)
- [x] Model: `StarterInitiative` (validations, `belongs_to :ring`)
- [x] `User` model: `has_one :profile`, `has_many :ring_maps, through: :profile`
- [x] `app/helpers/ring_helpers.rb` created (`ring_type_label`, `ring_type_badge`)
- [x] `RingHelpers` included in `ApplicationHelper`
- [x] Factory: `spec/factories/profiles.rb`
- [x] Factory: `spec/factories/ring_maps.rb`
- [x] Factory: `spec/factories/rings.rb` (with `:priority` and `:user_added` traits)
- [x] Factory: `spec/factories/overlaps.rb`
- [x] Factory: `spec/factories/starter_initiatives.rb`
- [x] **RSpec:** `spec/models/profile_spec.rb` — all examples passing
- [x] **RSpec:** `spec/models/ring_map_spec.rb` — all examples passing
- [x] **RSpec:** `spec/models/ring_spec.rb` — all examples passing
- [x] **RSpec:** `spec/models/overlap_spec.rb` — all examples passing
- [x] **RSpec:** `spec/models/starter_initiative_spec.rb` — all examples passing
- [ ] **Manual tests:** All items in phase-2-data-models.md checklist verified

---

## Phase 3 — Profile Feature
*Spec: `phase-3-profile.md`*

- [x] Routes: `resource :profile, only: [:show, :edit, :create, :update]`
- [x] `ProfilesController` created (show, edit, create, update; strong params; 404-safe)
- [x] `profiles/show.html.erb` — read-only view; blank fields show "Not provided"
- [x] `profiles/edit.html.erb` — Bootstrap form; floating labels; inline validation errors; taxonomy collapse
- [x] `shared/_ring_taxonomy.html.erb` — all 15 Ring types with one-sentence definitions
- [x] `profiles#show` redirects to `edit` when no profile exists
- [x] Dashboard Branch 1 ("Build your Profile") links correctly to `edit_profile_path`
- [x] Dashboard Branch 2 ("Run Ring Discovery") visible after profile is created
- [x] **RSpec:** `spec/requests/profiles_spec.rb` — all examples passing (auth, create, update, isolation)
- [ ] **Manual tests:** All items in phase-3-profile.md checklist verified

---

## Phase 4 — AI Templates & Ring Discovery
*Spec: `phase-4-ring-discovery.md`*

- [x] `ring_discovery_v1` template seeded in `db/seeds.rb` (model: `gemini-2.5-flash`, tokens: 3500, temp: 0.5)
- [x] `overlap_regeneration_v1` template seeded in `db/seeds.rb` (model: `gemini-2.5-flash`, tokens: 1500, temp: 0.4)
- [x] `rails db:seed` — both templates visible in `/admin/ai_templates`
- [x] Routes: `resources :ring_maps, only: [:create, :show, :destroy]` with `regenerate_overlaps` member
- [x] `RingMapsController` created (create, show, destroy; `regenerate_overlaps` stub)
- [x] `RingMapsController#create` — calls `ring_discovery_v1`, parses JSON, persists in transaction (RingMap, Rings, Overlaps, Initiatives)
- [x] UUID canonicalization (smaller UUID → `ring_a_id`) in `persist_ring_map!`
- [x] `known_rings` length warning logged when > 600 chars
- [x] All four Gemini error classes rescued; `JSON::ParserError` rescued
- [x] `ring_maps/show.html.erb` — basic version (Ring list, Overlap list, Initiatives, raw toggle)
- [x] `ring_maps/_ring.html.erb` partial (basic)
- [x] `ring_maps/_overlap.html.erb` partial (basic)
- [x] `ring_maps/_starter_initiative.html.erb` partial (with `.next-step-cell` left border)
- [x] `ring_maps/parse_error.html.erb` — friendly retry view
- [x] `spec/support/ring_discovery_fixture.rb` — valid JSON fixture; included in `rails_helper.rb`
- [x] **RSpec:** `spec/requests/ring_maps_spec.rb` — all examples passing (success, errors, isolation)
- [ ] **Manual tests:** All items in phase-4-ring-discovery.md checklist verified (real Gemini call)

---

## Phase 5 — Ring Management (Turbo Streams)
*Spec: `phase-5-ring-management.md`*

- [x] Routes: nested `resources :rings, only: [:create]` under `ring_maps`
- [x] Routes: `resources :rings, only: [:edit, :update, :destroy]` with `toggle_priority` member
- [x] `RingsController` created (create, edit, update, destroy, toggle_priority)
- [x] Ownership enforced in `load_ring` (404 for wrong user, not 403)
- [x] `rings/create.turbo_stream.erb` — appends Ring to list, clears add-ring form
- [x] `rings/update.turbo_stream.erb` — updates Ring row in place
- [x] `rings/destroy.turbo_stream.erb` — removes Ring row; flash with "Regenerate overlaps" link
- [x] `rings/toggle_priority.turbo_stream.erb` — updates `ring-priority-:id` target only
- [x] `rings/_form.html.erb` — shared form partial for add and edit
- [x] `rings/edit.html.erb` — Turbo Frame wrapper for inline edit
- [x] `ring_maps/_ring.html.erb` updated — Edit link (Turbo Frame target), priority toggle button, delete link
- [x] `ring_maps/_ring_priority_cell.html.erb` partial — badge only, targeted by toggle stream
- [x] `ring_maps/show.html.erb` updated — "+ Add a Ring" collapse with `add-ring-frame` Turbo Frame
- [x] `priority_toggle_controller.js` Stimulus controller created (minimal placeholder)
- [x] All Turbo Streams use `update()` not `replace()` (per CLAUDE.md)
- [x] **RSpec:** `spec/requests/rings_spec.rb` — all examples passing (create, update, destroy, toggle, isolation)
- [ ] **Manual tests:** All items in phase-5-ring-management.md checklist verified

---

## Phase 6 — Full Ring Map View, SVG & Overlap Regeneration
*Spec: `phase-6-ring-map-view.md`*

- [x] SVG CSS added to `application.css` (`.ring-shape`, `.overlap-lens`, `.ring-label`, `.initiative-card`)
- [x] Overlap list CSS added (`.overlap-connector`, `.overlap-connector-line`, `.overlap-connector-dot`)
- [x] `ring_map_controller.js` Stimulus controller created (force layout, jitter, lens, tooltips)
- [x] SVG controller listens for `ring:added`, `ring:updated`, `ring:removed`, `overlap:replaced`
- [x] Bootstrap tooltips created/disposed in `connect()`/`disconnect()` using `window.bootstrap`
- [x] Jitter is deterministic per Ring UUID (stable across re-renders)
- [x] `ring_maps/show.html.erb` replaced with full seven-section layout
- [x] SVG container has correct `data-controller`, `data-ring-map-rings-value`, `data-ring-map-overlaps-value`
- [x] Overlap partial updated with connector line + amber dot CSS layout
- [x] `RingMapsController#regenerate_overlaps` fully implemented (calls Gemini, replaces overlaps in transaction, updates timestamps)
- [x] Dashboard Branch 3 updated to render Ring map inline (not redirect)
- [x] **RSpec:** Overlap regeneration tests added to `spec/requests/ring_maps_spec.rb` and passing
- [x] **RSpec:** `spec/system/discovery_flow_spec.rb` created and passing
- [ ] **Manual tests:** All items in phase-6-ring-map-view.md checklist verified

---

## Phase 7 — Seed Data & README
*Spec: `phase-7-seed-data-readme.md`*

- [x] Domain seeds appended to `db/seeds.rb` (6 Rings, 3 Overlaps, 2 Initiatives for demo user)
- [x] Seed guard: `unless demo_user.profile` — re-running `db:seed` is safe
- [ ] `rails db:seed` — no errors; 6 rings, 3 overlaps, 2 initiatives created
- [ ] Signing in as `demo@example.com` shows populated Ring map without a Gemini call
- [ ] `rails db:seed` run twice — no duplicate records
- [x] README: app name, tagline, one-paragraph description added
- [x] README: screenshot placeholder added
- [x] README: "Why I built this" section added
- [x] README: "Editable AI prompts" section added
- [x] README: demo credentials table (`demo@example.com` / `password123`) added
- [ ] **RSpec:** `bundle exec rspec` — full suite passes
- [ ] **Manual tests:** All items in phase-7-seed-data-readme.md checklist verified

---

## Cross-Cutting Checks (after Phase 7)

- [x] No hardcoded "CommunityRings Demo" strings in views (all via `ENV.fetch("APP_NAME")`)
- [x] No `turbo_stream.replace()` calls anywhere (all must be `turbo_stream.update()`)
- [x] No `onclick=""`, `addEventListener`, or `<script>` tags in views
- [ ] No real Gemini API calls in test suite (`bundle exec rspec --format documentation` — scan for API hits)
- [ ] Admin panel at `/admin` still loads; both AI templates visible and testable
- [ ] `GET /up/llm` returns 200
- [ ] No JavaScript console errors on any page in development
- [x] `rails db:migrate:status` — no pending migrations
- [ ] `bundle exec rubocop` (if configured) — no offenses blocking merge

---

## Phase 8 — Pre-Publish Security Check
*Prompt: `docs/prompts/pre-publish-security-check.md`*

Run the security review prompt in full before pushing to a public GitHub repo.

- [ ] Hardcoded secrets scan — no API keys, passwords, or tokens in any tracked file
- [ ] `.gitignore` covers `.env`, `config/master.key`, `*.key`, `config/credentials.yml.enc`, `log/`, `tmp/`
- [ ] `.env.example` — all values are placeholders, no real credentials
- [ ] `config/database.yml` — production block uses `ENV.fetch(...)`, no hardcoded credentials
- [ ] `db/seeds.rb` — no credentials beyond the documented `demo@example.com` / `password123`
- [ ] `config/environments/production.rb` — no hardcoded secrets
- [ ] `Gemfile` — only gem source is `https://rubygems.org`; no private git sources
- [ ] `README` — no internal URLs, server names, real email addresses, or internal team names
- [ ] `log/` and `tmp/` — no tracked files with sensitive content
- [ ] Git history reviewed — no commit messages suggesting a secret was ever committed
