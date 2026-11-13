# Importing a partner's beneficiaries as RDV-SP usagers (design)

Status: agreed and built on 2026-11-12, branch `rdvsp-usager-import` (decision 36).

## Why

A partner keeps its beneficiaries in its own tool (Pipedrive). Its agents book them in RDV-SP, where each usager must be
typed in by hand. The bridge should transfer them from the source to RDV-SP, and, with its own OAuth application at
RDV-SP, prepare the use of RDV plans later. RDV-SP has no usager import in its UI, but its API creates usagers
(`POST /api/v1/users`) on behalf of an agent who authorized an OAuth application. Until now the bridge held no RDV-SP
credential at all.

## Authorization

RDV-SP registers OAuth applications by hand (`scripts/create_oauth_application.rb`), with
`grants_autonomous_signup` off: one on the demo instance, redirecting to `http://localhost:3010/rdvsp/callback`, one in
production, redirecting to `https://pont-rdv.inclusion.gouv.fr/rdvsp/callback`. Doorkeeper, `authorization_code` only,
a single `write` scope, access tokens of 2 hours with refresh tokens. Configuration: `RDVSP_URL`,
`RDVSP_OAUTH_CLIENT_ID`, `RDVSP_OAUTH_CLIENT_SECRET`; the feature is hidden while any of them is missing.

The admin is behind the staff password, so the partner's agent can't click a button there. Instead:

1. On the account's admin page, staff create an **authorization link**: `/rdvsp/authorize/<token>`, where the token is
   the account's `signed_id` (purpose `rdvsp_authorization`, 7 days). Staff send it to an agent of the partner.
2. That public page says which partner asks for what ("Pont RDV pourra créer des usagers dans RDV Service Public en
   votre nom") with one button. It stores a random `state` and the account id in the session, then redirects to
   `<RDVSP_URL>/oauth/authorize`. Link-preview bots only ever see the page.
3. `/rdvsp/callback` checks the `state`, exchanges the code, calls `GET /api/v1/agents/me`, and stores on the account
   the tokens (encrypted, like the Pipedrive token), their expiry, the agent's RDV-SP id and e-mail, and the time.
   The agent sees "C'est fait, vous pouvez fermer cette page".

The token acts as that agent, with all their rights; RDV-SP logs every call against them. It belongs to the account,
not to a connection: the import is the partner's, whichever of its agents authorizes it. A new authorization replaces
the previous one. Staff can withdraw it ("Retirer"): the bridge revokes the token at RDV-SP (`POST /oauth/revoke`) and
forgets it.

The client refreshes the access token when it is about to expire, or on a 401, and saves the new refresh token before
using the new access token (Doorkeeper revokes the old one). A refused refresh (`invalid_grant`) marks the
authorization as lost on the admin page; staff then send a new link.

## Import

On the account's admin page, once authorized:

1. **Settings.** The RDV-SP organisation (`GET /api/v1/organisations`, those of the authorizing agent); the Pipedrive
   field and value that mark a beneficiary (a select of the options of every set or single-option person field, e.g.
   a "contact type" field → its "beneficiary" option); "actif depuis" (default: January 1st of last year). A person is
   active when their last activity, next activity or creation is on or after that date (`last_activity_date` is only
   in Pipedrive's v1 API: `update_time` was bumped on every person of the first partner by a bulk edit).
2. **Preview**, computed in the request, nothing written. Counts only, no names:
   - beneficiaries selected;
   - set aside for lack of a first or last name (RDV-SP requires both);
   - already in the organisation: same e-mail (case-insensitive), same phone (last nine digits) or same full name
     (case- and accent-insensitive) as one of its usagers (`GET /api/v1/organisations/:id/users`, 100 per page). This
     protects the usagers agents have already created by hand; a homonym is set aside rather than duplicated;
   - already imported by the bridge;
   - to create.
3. **Import**: an `UsagerImport` row (settings, state, counts) and `ImportUsagersJob`, one at a time per account. The
   job recomputes the plan, then creates each usager with first name, last name, primary e-mail, primary phone, and
   `external_reference: { external_id: "pipedrive-<company id>-<person id>", external_url: <person page in Pipedrive> }`.
   RDV-SP keeps that reference unique per application and territory, which guards against duplicates on its side too.
   The company id is there because Pipedrive numbers persons per company and all partners share the bridge's
   application: two partners in one territory would otherwise collide, and RDV-SP looks references up by application
   only (`POST /api/v1/rdv_plans`). The plan
   adds each person to create to its index, so two Pipedrive persons with the same e-mail don't both get created.
4. **Results.** `ImportedUsager` keeps the Pipedrive person id ↔ RDV-SP usager id (and organisation): no personal
   data.
   When RDV-SP rejects only the e-mail and/or the phone (422), the usager is created again without them. Other
   rejections are counted by attribute name, never by value. An `external_id` already taken counts as already imported.
   The account page lists the imports with their state and counts. Running it again creates only the new ones.

Logs and errors carry counts and ids only, never names, e-mails or phones.

## Not in this version

- No continuous sync: new beneficiaries arrive when staff run the import again. Usagers already created are never
  updated.
- Only one field option marks a beneficiary: a legacy field holding the same option isn't read.
- No link between an RDV pushed by RDV-SP and the imported usager's Pipedrive person: that needs RDV-SP to send the
  usager's id or external reference (RDV Plans have one).

## Tests

WebMock for RDV-SP and Pipedrive: the authorization flow (state, expired or tampered link, refusal at RDV-SP), token
refresh (ahead of expiry, on 401, refused), the plan's categories, the job (creation, retry without contact fields,
taken `external_id`, idempotent re-run), the admin preview. A manual run against the demo instance and the Pipedrive
sandbox before production.
