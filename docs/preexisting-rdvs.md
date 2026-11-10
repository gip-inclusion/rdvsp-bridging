# RDVs that existed before the connection (design)

Status: agreed on 2026-11-10, built on branch `ignore-preexisting-rdvs`.

## Why

When an agent saves their CalDAV settings, RDV-SP checks the connection, then `MassExportEventToCaldavJob` PUTs every
RDV of theirs starting from two weeks ago (and again, as updates, on every later save). Partners who used to copy
their RDVs into their own calendar by hand then get every one of them twice. That happened with the first partner on
2026-11-10: 27 RDVs arrived within one second and became 27 duplicate activities; a genuinely new RDV, booked right
after the setup, arrived alone 2½ minutes later.

The sync is for RDVs booked **after** the agent connects. The ICS can't tell us when an RDV was booked (no `CREATED`,
`DTSTAMP` is the export time, `SEQUENCE` is always 0), so the bridge infers it.

## Rule

An RDV is classified once, at the first PUT of its href, and never again except by an admin. It is **ignored** when:

- **the start-up window is open**: each connection test (`rdvsp-connection-test-*` PUT) opens it for 60 s; every
  never-seen RDV received while it is open pushes its end to 60 s later, so it closes after 60 s without one; it
  never stays open more than 15 min after the test;
- **or its RDV-SP id is at or below the connection's watermark**: the highest RDV-SP id among its ignored RDVs (taken
  from the "Voir sur …/admin/organisations/<org>/rdvs/<id>" link, before `Contexte :`). RDV ids come from one global
  sequence, so an RDV booked after the setup is always above it. This catches what a window can't: bulk-export
  retries hours later (RDV-SP retries a failed PUT for about 17 h), and RDVs older than two weeks that are PUT for the
  first time when someone touches them.

Ignored RDVs are stored and answered exactly like the others (RDV-SP sees no difference), but nothing about them
reaches the provider: no payload kept, no job for updates, cancellations or deletions. Every PUT of an ignored RDV
raises the watermark. If an ignored RDV still has a provider activity (applied after the fact), the push job removes it
and forgets its id; it never creates one.

Not in this version: re-opening the window when RDV-SP's first full import (`calendar-query`) arrives late, to cover a
bulk export delayed by RDV-SP's queue. The admin warning and the after-the-fact action cover that case for now.

## Paths

| Path | Behaviour |
|---|---|
| First PUT | Answered as today (201, ETag). Classified; ignored → no payload, no job, watermark raised. |
| Later PUT | Answered as today. Ignored → times and ETag updated, watermark raised, no job. Otherwise as today. |
| `STATUS:CANCELLED` / DELETE | As today; ignored → no job. |
| Settings re-saved | New 60 s window; the re-sent RDVs are known, so nothing changes. An RDV booked in that minute is ignored. |
| Disconnect, reconnect | Disconnect cancels everything as today. On reconnect, known RDVs keep their class (pushed ones are pushed again); RDVs booked while disconnected are ignored. |
| Existing connections | New columns empty: window closed, no watermark, same behaviour as before until their next connection test. |
| Google | Same receive/cancel code; `Google::PushRdv` gets the same removal path. |

## Pipedrive answers for deleted activities (verified 2026-11-10)

`GET` returns the activity with `is_deleted: true`; `DELETE` answers **400** "Activity is already deleted"; `PATCH`
answers **403** "Cannot update a deleted activity." (our client read 403 as a refused token). `PushRdv` now re-fetches
the activity when a `PATCH` or `DELETE` fails: deleted means gone (recreate, or nothing to delete), anything else is
raised as before.

## Data

- `rdvs.ignored_at`: the classification. A column rather than a `state` value, because every receive rewrites `state`
  (the push status). An ignored RDV with nothing to remove is `synced`.
- `rdvs.rdvsp_id`: parsed from the link; not personal data; survives the payload being cleared.
- `connections.baseline_started_at`, `connections.baseline_until`, `connections.baseline_max_rdvsp_id`: last
  connection test, window end, watermark. The window and the watermark are updated in single SQL statements: the bulk
  export arrives as concurrent requests.

## Admin

Connection page, "Rendez-vous" section:

- last connection test, window end, watermark; counts of RDVs transmitted, ignored, failed, cancelled;
- how many existing RDVs were ignored after the last connection test (zero after a first setup means the agent had no
  RDV, or the bulk export came late; after a re-save it is normal). Not a warning, since a re-save would raise it
  every time;
- the latest RDVs (received at, starts at, status, RDV-SP id; never subject, description or location) with
  "Transmettre quand même" on ignored ones: the flag is cleared and the RDV is pushed at RDV-SP's next PUT of it (we
  keep no payload for ignored RDVs);
- "Ignorer les RDV reçus avant…": a cut-off (default: the window end, or 60 s after the first RDV received when no test
  was recorded), a preview, then apply: mark ignored and remove their activities. This is how the first partner's
  connection is fixed: no console on the container, and the repo is public, so no data migration with prod ids.

Account page: an "Ignorés" column per connection.

## Product answers (2026-11-10)

1. An ignored RDV moved or cancelled later stays as the agent copied it: their copy is theirs to keep up to date.
2. An agent added later to an RDV that already existed: ignored (below the watermark).
3. An RDV booked in the minute after a settings re-save is ignored; it can be released.
4. A never-seen RDV that starts in the past is not ignored for that reason alone.
5. Releasing waits for RDV-SP's next PUT rather than keeping payloads of ignored RDVs.
6. Onboarding tells agents to wait a minute after the setup before booking a test RDV.
7. Disconnecting still removes every pushed activity, past ones included.
