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

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `ring_discovery_v1` must return valid JSON with `rings`, or the response is not shown.
- `overlap_regeneration_v1` must return valid JSON with `overlaps`, or the response is not shown.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 14 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Accurate:** Every Overlap pairs two Rings that genuinely share people, places, or purposes according to their descriptions. Nothing is manufactured or attributed to Rings not in the list.
- **Useful:** Each cross_ring_idea is a specific, doable service idea that would strengthen both Rings at once, not a generic "connect the groups".
- **Steerable:** The language is plain, secular, and observational, with no religious phrasing, no assignments to the user, and no productivity jargon.
- **Accurate:** Every Ring, Overlap, and shared_element is grounded in the Profile. No invented communities, named people, or local businesses the user did not mention.
- **Useful:** Each cross_ring_idea is a specific, sensible service idea that plausibly strengthens both Rings at once, and the Starter Initiatives fit inside the stated weekly hours.
- **Steerable:** The voice is plain, secular, and owner-not-coach. It suggests rather than assigns, never scores the user, and avoids religious language and productivity jargon.

**Current status (October 2026):** the guardrail suite passes: 12/12 input attacks and 7/7 output attacks blocked, with no false positives (18/18 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## License

MIT — see [LICENSE](LICENSE)
