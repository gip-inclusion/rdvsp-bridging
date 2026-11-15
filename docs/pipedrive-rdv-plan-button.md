# "Prendre RDV" from a person in Pipedrive (design)

Status: agreed and built on 2026-11-13, branch `pipedrive-rdv-plan-button` (decision 37).

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

1. Verify the token; find the account by `companyId`; take the single id of `selectedIds`; take the clicking user's
   own RDV-SP authorization by `userId` (below). Without one, the agent authorizes first, then the flow goes on.
2. The person's RDV-SP usager, with that agent's token:
   - already transferred (`ImportedUsager`): its id;
   - otherwise, transferred now, with the import's rules, into the account's organisation
     (`accounts.rdvsp_organisation_id`: chosen in the admin, replaced by each import; without one, the authorizing
     agent's only organisation, then kept): read the person from Pipedrive (v1), load the organisation's usagers; one
     with the same e-mail or phone is used and recorded; a same-name usager without either is not (it may be someone
     else, whom RDV-SP would notify): the page says to book in RDV-SP directly; no match → `POST /api/v1/users` as the
     import does.
3. `POST /api/v1/rdv_plans` with `user: { id }` (never `external_id`: RDV-SP's lookup by it was broken until
   betagouv/rdv-service-public#6937), `dossier_url` = the person's page in Pipedrive (RDV-SP links it from the RDV),
   `return_url` = a bridge URL redirecting to that page (RDV-SP only accepts its host from the OAuth application's
   redirect URIs). The URL carries a signed account and person id, without expiry: the link stays on RDV-SP's RDV page.
4. Redirect the tab to the plan's `url`; the agent picks motif, slot, confirms.

## Each agent's authorization

An RDV plan belongs to the agent whose token created it (`planning_agent`), and RDV-SP lets only them open it
(`Agent::RdvPlanPolicy`). So each agent clicks with their own token, never the account's (decision 43):

- `rdvsp_authorizations.provider_user_id`: empty for the account's authorization (the import's, from the link staff
  send), the Pipedrive user id for an agent's (the button's). One of each per account and user.
- A click from a user without an authorization, or whose authorization is lost, shows a page saying why Pont RDV asks
  (once), with one button. It posts a signed request (account, user, person; 1 hour) that starts OAuth with the
  account's flow: same `state` in the session, same `/rdvsp/callback`, the only redirect URI RDV-SP registered. The
  session also carries the user and the person.
- The callback stores the agent's authorization (replacing and revoking their earlier one), puts the account, user and
  person in the session, and redirects to `/pipedrive/prendre-rdv/suite`, which goes on with step 2: the agent lands
  on the plan they asked for. Declining, or RDV-SP failing, says to click "Prendre RDV" again.
- RDV-SP allows several tokens per agent and application (Doorkeeper's `revoke_previous_authorization_code_token` is
  off), so an agent who also authorized the import keeps both.
- The usager transferred by a click is created in the clicking agent's name, in the account's organisation; RDV-SP
  refuses it (403) when the agent isn't in that organisation, and the page says to ask to be added.
- The account's admin page lists the agents' authorizations (RDV-SP e-mail, Pipedrive user, date, lost), each with
  "Retirer", which revokes the token at RDV-SP.

## Limits

- A person not transferred yet loads the whole organisation's usagers (100 per page) for that click.
- The RDV the plan creates comes back through CalDAV like any other; with `link_persons`, its activity is attached to
  the person (decision 39).

## Errors

Each case renders a page saying what to do: missing or invalid token (401), unknown company, no or lost RDV-SP
authorization of the agent (the authorization page), agent outside the organisation (403), no organisation (none
chosen and the agent has several), first or last name missing in Pipedrive, homonym, RDV-SP rejecting the usager,
RDV-SP or Pipedrive failing (502). Logs carry ids only.

## Tests

Token verification (valid, expired, wrong signature, company mismatch), transferred person, transfer on the fly (match
by e-mail, homonym, creation), RDV-SP errors, the return redirect, the installation callback; an agent's first click
through OAuth to the plan, with their token and not the account's, declined or lost authorizations, the admin list.
Then a real run on the test company.
