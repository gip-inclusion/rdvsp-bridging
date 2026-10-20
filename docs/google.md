# Google Calendar provider (spike)

Same idea as Pipedrive: RDV-SP talks CalDAV (Basic auth) to the bridge; the bridge mirrors the Google calendar's busy
times and writes RDVs as Google events. It closes the gap that RDV-SP's CalDAV client cannot use Google's own CalDAV
server (Google requires OAuth, RDV-SP only does Basic auth).

Why the Calendar REST API rather than proxying Google's CalDAV: no XML href rewriting, and only start/end times ever
reach RDV-SP (a passthrough would hand RDV-SP every event's title and description).

## What it does

- Account = one Google user (OAuth refresh token, scopes `openid email calendar.events`); its primary calendar is
  connected automatically.
- Busy: confirmed or tentative events, not `transparent`, not declined by the user, not working-location/birthday,
  timed (all-day only with the connection's toggle). Recurring events are expanded by Google (`singleEvents`).
- Incremental refresh with `updatedMin` + `showDeleted` (deletions arrive as `status: cancelled`), hourly rebuild of
  the 6-month window, same cron as Pipedrive. No push notifications (watch channels) yet.
- RDVs become opaque events tagged with a private extended property (`rdvsp_bridging_rdv`), excluded from busy times.
  Same content rules as Pipedrive (`RdvContent`).

## Trying it live

1. Google Cloud console → new project → enable **Google Calendar API**.
2. OAuth consent screen: **Internal** if the testers are in our Google Workspace (no verification needed); otherwise
   External + test users. Caveat: in *Testing* status, refresh tokens **expire after 7 days**; production use of the
   `calendar.events` (sensitive) scope requires Google's verification.
3. Credentials → OAuth client ID → Web application → redirect URI
   `http://localhost:3010/admin/google/callback` (and the Scaleway one, `https://<domain>/admin/google/callback`).
4. Put `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` in `.env` (or the container's secrets), restart, then
   `/admin` → "Connecter un agenda Google". The credentials page shows the CalDAV URL/username/password for RDV-SP.
