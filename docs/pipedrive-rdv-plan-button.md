# "Prendre RDV" from a person in Pipedrive (design)

Status: agreed on 2026-11-13 (decision 37).

## Why

A partner's agents work from the person's page in Pipedrive. Booking an RDV in RDV-SP means finding the usager there,
or typing them in. RDV-SP's RDV plans (`POST /api/v1/rdv_plans`) take a usager and return a URL where the agent picks
the motif and the slot; the bridge already holds an OAuth token for the partner (`docs/rdvsp-usager-import.md`).

## Pipedrive side

A **private app** in Pipedrive's Developer Hub, with one link action:

- name "Prendre RDV", location "Person details", URL `<BRIDGE_BASE_URL>/pipedrive/prendre-rdv`, "JWT secret" left
  empty: Pipedrive then signs with the app's client secret (a dedicated secret was reported ignored);
- OAuth callback `<BRIDGE_BASE_URL>/pipedrive/app/callback`, the smallest scope. The callback exchanges the code to
  complete the installation and forgets the tokens: the bridge keeps using the account's API token.

Configuration: `PIPEDRIVE_APP_CLIENT_ID`, `PIPEDRIVE_APP_CLIENT_SECRET`; the routes answer 404 without them or without
RDV-SP's.

A click opens a new tab on the action URL with `resource=person&view=details&userId&companyId&selectedIds=<person id>`
and `token`, a JWT (HS256) carrying `userId` and `companyId`. The bridge trusts the token's `companyId`, not the query's.

## Flow

1. Verify the token; find the account by `companyId`; take the single id of `selectedIds`.
2. The person's RDV-SP usager:
   - already transferred (`ImportedUsager`): its id;
   - otherwise, transferred now, with the import's rules, into the organisation of the account's last finished
     import: read the person from Pipedrive (v1), load the organisation's usagers; one with the same e-mail or phone is
     used and recorded; a same-name usager without either is not (it may be someone else, whom RDV-SP would notify):
     the page says to book in RDV-SP directly; no match → `POST /api/v1/users` as the import does.
3. `POST /api/v1/rdv_plans` with `user: { id }` (never `external_id`: RDV-SP's lookup by it was broken until
   betagouv/rdv-service-public#6937), `dossier_url` = the person's page in Pipedrive (RDV-SP links it from the RDV),
   `return_url` = a bridge URL redirecting to that page (RDV-SP only accepts its host from the OAuth application's
   redirect URIs). The URL carries a signed account and person id, without expiry: the link stays on RDV-SP's RDV page.
4. Redirect the tab to the plan's `url`; the agent picks motif, slot, confirms.

## Limits

- An RDV plan belongs to the agent whose token created it, and RDV-SP lets only them open it: only the agent who
  authorized the bridge can use the button. Next step: each agent authorizes the bridge at their first click.
- A person not transferred yet loads the whole organisation's usagers (100 per page) for that click.
- The RDV the plan creates comes back through CalDAV like any other; nothing links it to the Pipedrive person yet.

## Errors

Each case renders a page saying what to do: missing or invalid token (401), unknown company, no or lost RDV-SP
authorization, no import yet (no organisation), first or last name missing in Pipedrive, homonym, RDV-SP rejecting the
usager, RDV-SP or Pipedrive failing (502). Logs carry ids only.

## Tests

Token verification (valid, expired, wrong signature, company mismatch), transferred person, transfer on the fly (match
by e-mail, homonym, creation), RDV-SP errors, the return redirect, the installation callback. Then a real run on the
test company.
