# CLAUDE.md

Guidance for working in this repository.

## What this is

**rdvsp-bridges** lets people whose calendar lives in a third-party system (first: the Pipedrive CRM; later maybe
Salesforce, Google, Microsoft) use **RDV Service Public** (RDV-SP, `../rdv-service-public`) bidirectionally:

- their busy times in the provider block slots in RDV-SP;
- RDVs booked in RDV-SP appear in the provider (and, through the provider's own Google/Outlook sync, in their calendar).

We **cannot change RDV-SP** (no PR). Instead the bridge **impersonates a CalDAV server**. RDV-SP already lets any agent
connect "un agenda CalDAV" (Synchronisation → Connecter mon agenda via Caldav: URL + username + password, HTTP Basic).
The agent pastes credentials issued by the bridge; RDV-SP then:

- imports busy times: `Caldav::ImportAbsencesFromCaldavJob` (cron every 15 min + on each slot search involving the
  agent, debounced 1/min) → `ExternalCalendarEvent` → subtracted from opening hours (`plages d'ouverture`);
- exports RDVs: `Caldav::ExportRdvToCaldavJob` → `PUT <agenda>/<rdv-uuid>.ics`, `PUT` again on update, `DELETE` on removal.

Partner users must still be RDV-SP agents with opening hours defined in RDV-SP: providers only *subtract* busy times.

## The CalDAV client we must satisfy (Calendav gem 0.6, used by RDV-SP)

Exact requests, verified by reading the gem and RDV-SP code. **Any change here must keep them working**
(`spec/integration/calendav_compatibility_spec.rb` drives the real gem against the app).

1. `PROPFIND` Depth 0 on the configured URL (the calendar URL itself) for `current-user-principal`.
2. `PROPFIND` on the principal for `calendar-home-set`, then Depth 1 on the home: keeps resources whose `resourcetype`
   contains `caldav:calendar` and whose `supported-calendar-component-set` includes `VEVENT`.
3. `PROPFIND` Depth 0 on the agenda (`calendars.find`, with `sync-token` on first import).
4. Connection test: `PUT <agenda>/rdvsp-connection-test-<uuid>.ics` then `DELETE` it. Never forwarded to providers.
5. First import: `REPORT calendar-query` Depth 1. Next imports: `REPORT sync-collection` with the stored token.
   RDV-SP **ignores 507/pagination and does not recover from sync errors** → never fail a sync-token, never paginate.
6. RDV-SP drops imported events whose URL equals an RDV it exported, events without `DTEND`, and non-busy events
   (non-recurring: `TRANSP` ≠ `TRANSPARENT`; recurring: raw text must contain `TRANSP:OPAQUE`). We never emit RRULE.
7. The URL RDV-SP stores for an exported RDV is the `Location` header of the PUT response, or the PUT URL.

## Architecture

- Rails 8.1 (`--minimal`-ish), Ruby 4.0 (managed with **rv**), PostgreSQL, **GoodJob** (in-process, cron), gems from
  **gem.coop**.
- `Account`: one provider tenant (a Pipedrive company) with its encrypted API token and per-company options.
- `Connection`: one provider user ↔ one RDV-SP agent; owns the CalDAV credentials and exposes exactly one calendar.
- `BusyBlock`: local mirror of the provider's busy items, append-only change sequence + tombstones. Sync tokens are
  `<generation>-<sequence>`; unknown/old tokens get the full state (never an error).
- `Rdv`: an RDV pushed by RDV-SP (keyed by connection + href), written to the provider asynchronously.
- `app/caldav/`: provider-agnostic CalDAV server (XML parsing/rendering, ICS in/out).
- `app/providers/pipedrive/`: API client, activity → busy block mapping, RDV → activity writer, webhooks.
- No generic provider interface yet: extract it when a second provider exists.

See `DECISIONS.md` for the decision log (read it before changing behaviour).

## Commands

```bash
make install      # bundle + db:prepare (starts Postgres in Docker on 127.0.0.1:5442)
make run          # app on http://localhost:3010 (GoodJob runs in-process)
make test         # rspec
make lint         # rubocop + brakeman
make autocorrect  # rubocop -A
bin/rails "bridges:pipedrive:onboard[TOKEN]"    # create an account from a Pipedrive API token
bin/rails "bridges:connection:create[ACCOUNT_ID,PIPEDRIVE_USER_ID,agent@example.fr]"
```

Ruby runs through `rv run …` (the Makefile does it for you; `RUN=` to bypass).

## Conventions (aligned with rdv-insertion and rdv-service-public)

- RSpec + FactoryBot; RuboCop with rubocop-rails and rubocop-rspec (`.rubocop.yml`); `make lint` must pass.
- Double quotes, 120 columns, no `frozen_string_literal` magic comment.
- Lean models and controllers, concerns and POROs for domain logic, service objects (`BaseService`, `.call`,
  `success?`/`failure?`) for procedural logic with external calls.
- Comments only where the code is truly hard to understand; prefer framework-native solutions.
- Never store or log raw ICS bodies or provider subjects/notes: they can contain usager personal data.
- Do not reference AI tools in code, comments or commits. Atomic, one-line commit messages.

## Local secrets

`.env` (git-ignored) holds `PG*` variables for the Docker Postgres and `PIPEDRIVE_SANDBOX_API_TOKEN` (our Pipedrive
sandbox, company "PDI - Test instance"). Pipedrive returns `due_date`/`due_time` in **UTC**.
