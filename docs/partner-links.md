# Partner links: one account's admin without a password (design)

Status: agreed on 2026-11-17, branch `partner-links` (decision 44).

## Why

A partner's admin should manage their own account: connect their Pipedrive users, send each agent their CalDAV link,
pick the RDV activity type and the organisation, import beneficiaries, set the options. The admin is behind one HTTP
Basic password, ours, for every account. The team sends a link instead: it opens that one account, never another, and
the team sees whether and how often it served, and revokes it.

## Links

- `PartnerLink`: `account_id`, `label` (who it was sent to, required), `uses_count` (0), `last_used_at`,
  `revoked_at`, timestamps. Several per account.
- The URL is `/equipe/<token>`, the token `generates_token_for(:partner_access)`, like the agent's CalDAV link: nothing
  secret is stored and the team can copy a link again at any time. No expiry: a link serves until revoked.
- Revoking sets `revoked_at`; the link stays listed for the audit.

## Opening a link

1. `GET /equipe/<token>`, public layout: "Administrer « <account> »", what the page allows, and a "Continuer" button.
   A link preview (mail, chat) only reaches this page, so it neither counts nor opens anything.
2. `POST /equipe/<token>`: counts a use (`uses_count + 1`, `last_used_at`), resets the session, stores the link's id in
   it, redirects to the account's page.
3. Each request reloads the link from the session: revoked (or deleted with its account), the session is dropped and
   the page says to ask the team for a new link.
4. An unknown or revoked token renders the same message (404). The bridge's own log lines carry ids only; the request
   line shows the path with its token, as for the agents' links.

The session ends with the browser (Rails' cookie store, no expiry set); the partner opens the link again, which
counts another use. "Quitter" in the header (`DELETE /equipe`) clears the session, so the team can test a link and go
back to the HTTP Basic admin.

## What a link opens

`Admin::BaseController` accepts either a partner session or, without one, HTTP Basic as today. Controllers are closed to
partners unless they say otherwise (`open_to_partners`, with `except:`), and those look records up through the
session's scope (`accounts`: the link's account, or all of them for the team), so another account answers 404.

| Open to partners | Team only |
|---|---|
| account page and its options | accounts list (a partner is sent to their account), onboarding, Google |
| connecting a Pipedrive user | "Accès partenaire" (creating and revoking links) |
| connection page, its options, new password, agent link | "Reconstruire" |
| RDV-SP authorizations (removing), organisation, activity type | "Ignorer les RDV reçus avant…" |
| beneficiary import | "Transmettre quand même" |

The three troubleshooting actions stay ours: a partner releasing ignored RDVs would duplicate activities, as on
Massajobs' first sync. Their buttons are hidden from partners, and their routes answer them 404.

In the admin layout, a partner sees no "Comptes" button and no back link to the accounts, but "Quitter".

## The team's block

On the account page, "Accès partenaire" (team only): a label field and "Créer un lien"; then one row per link, newest
first: label, created on, "jamais ouvert" or "ouvert N fois, la dernière le …", the URL with "Copier" while active,
"Révoquer" (with a confirmation), or a "Révoqué le …" badge.

## Tests

Token: valid, unknown, revoked; the landing page doesn't count; "Continuer" counts and opens the account. A partner
session: their account's pages and actions work; another account's account, connection, RDV and nested pages answer
404; team-only routes answer 404; revoking ends a live session; "Quitter". HTTP Basic unchanged without a session. The
team's block: create, list with counts, revoke.
