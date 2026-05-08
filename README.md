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

## Screenshot

[Screenshot of the Ring map view — the hand-drawn SVG cluster with amber overlap
regions, the Ring list, the Overlap card, and the Starter Initiatives section.
Replace this placeholder once the README is live in the repo.]

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

## Demo credentials

| Field | Value |
|---|---|
| Email | `demo@example.com` |
| Password | `password123` |
| Admin | yes |

After running `bin/setup` and `rails db:seed`, sign in with these credentials
to see a pre-populated Ring map without spending a Gemini API call.

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

## Quick Start

1. Clone this repo
2. Run `bin/setup`
3. Add your Gemini API key to `.env`
4. `rails db:seed`
5. `bin/rails server`
6. Visit http://localhost:3000 and sign in with `demo@example.com` / `password123`

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"Open Demo Starter"` | Displayed in the navbar and title |
| `APP_TAGLINE` | — | Shown in the footer |
| `APP_DESCRIPTION` | — | Shown on the landing page |
| `GEMINI_API_KEY` | (required) | Your Google Gemini API key — get one free at https://aistudio.google.com/app/apikey |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Gemini request timeout in seconds |

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini via `gemini-ai` gem |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## AI Safety Posture

**What this boilerplate enforces:**
- Per-user daily call cap (default: 50/day, set via `AI_CALLS_PER_USER_PER_DAY`)
- Pre-flight gatekeeper: input length limit, prompt injection patterns, profanity filter
- Hard output token cap per template
- Configurable request timeout (default: 15s)
- Full request log with status, tokens, duration, and cost estimate
- Fail-soft UI: errors render an inline alert, never crash the page
- AI disclaimer in the footer on every page

**Deliberately omitted (with rationale):**
- No PII scrubbing — demo apps have no production user data
- No content moderation API — Gemini's built-in safety filters are sufficient
- No automatic retries — avoids stacking costs on transient failures
- No RAG or vector DB — single-shot prompts only
- No streaming — synchronous calls keep the code simple

See `app/services/ai_gatekeeper.rb` and `app/services/ai_budget_checker.rb` to extend.

## License

MIT — see [LICENSE](LICENSE)
