# Pont RDV's pages on the itou theme (design)

Status: agreed on 2026-11-15 from a mockup reviewed on mobile, branch `itou-theme-ui`.

## Why

The admin and the public pages were bare HTML with a few inline styles: hard to read on a phone, and the public pages
(seen by partners: the RDV-SP authorization, the messages of the "Prendre RDV" button) didn't look like a service of
the Plateforme de l'inclusion. The platform's products share a theme, `gip-inclusion/itou-theme` (Bootstrap 5.3,
Marianne, Remix Icon), which les-emplois vendors from a release tag.

## The theme

- `vendor/assets/itou-theme/` holds the files of a release tag's `dist/` that the pages need: `stylesheets/app.css`,
  Marianne (`woff2` and `woff`), Remix Icon (`woff2` and `woff`), the images `app.css` references, and the two logos
  of the public header. `VERSION` names the tag (first: `v3.6.3`). Propshaft serves them and rewrites the CSS's
  relative `url()`s. The legacy `eot`/`ttf`/`svg` icon fonts are left out, so precompiling warns about those three.
- `bin/update-itou-theme VERSION` downloads the tag's archive from GitHub and replaces the folder. No Node.
- None of the theme's JavaScript (Bootstrap's dropdowns, modals, offcanvas): no page needs it.
- `app/assets/stylesheets/pont-rdv.css`: the few rules of our own (headers, brand, stats, list rows, public band,
  footer), on top of the theme.
- `app/assets/javascripts/copy.js`: "Copier" buttons next to read-only fields (Clipboard API, otherwise the field's text
  is selected).

## Layouts

- **Admin** (`layouts/admin`): a header with a pictogram and "Pont RDV / Administration", and a "Comptes" button.
  Flash messages are theme alerts. Each page has a title bar (`s-title-02`): a back link (`c-prevstep`) when the page
  has a parent, the `h1` with a state badge, and the page's main action as a primary button (`c-title__cta`). The
  content sits in `c-box` blocks, on two columns from `xl` (lists and RDV-SP on the left, settings on the right), one
  column below.
- **Public** (`layouts/public`): a header with the République française block, the Plateforme de l'inclusion logo, and
  "Pont RDV" after a vertical rule; a grey band with one centered `c-box`; a footer "Pont RDV · Plateforme de
  l'inclusion". `shared/message` shows a check icon for a success (2xx) and a warning icon otherwise.

## Pages

- **Comptes**: main action "Connecter un compte Pipedrive" (and the Google one when configured). One row per account:
  name, provider and domain, an "OK" or "En erreur depuis le …" badge, the error under the name, last read and number
  of connections.
- **Compte**: main action "Connecter un utilisateur Pipedrive". Blocks:
  - Connexions: one row per connection, its agent and a badge (below);
  - RDV Service Public: who authorized and when, the organisation with "Changer", the "Importer des bénéficiaires" and
    "Retirer l'autorisation" buttons, the authorization link with "Copier", the list of imports with a state badge;
  - Pipedrive: domain, activity type **by name** (with "Changer"; the name is read from Pipedrive's activity types on
    each display, and the key is shown when Pipedrive fails), live updates (webhook);
  - Options: switches with their help text under the label, the alert e-mail, "Enregistrer".
- **Connexion**:
  - État: four figures (last RDV-SP visit, last rebuild, busy times, failed RDVs) and "Reconstruire";
  - RDV reçus: counts as badges, the note on ignored RDVs in an info alert with "Ignorer les RDV reçus avant…", then
    one row per RDV (start, RDV-SP number, received at, state badge, "Transmettre quand même" on ignored ones);
  - Identifiants CalDAV: URL and username with "Copier"; the password once, in an alert, right after it's generated;
  - Options.
- **Small forms** (activity type, organisation, import, ignored RDVs, new account, new connection): one block of at most
  8 columns, a sentence saying what the choice does, a primary button and "Annuler".
- **Autoriser Pont RDV** and **messages**: the current texts, in the public layout; the authorization lists the three
  things it implies before its button.

Connection badge: "RDV-SP jamais venu" (warning) before RDV-SP's first visit; "RDV-SP ne passe plus" (danger) when a
silence alert went out since its last visit (`silence_alerted_at` after `last_seen_at`); otherwise "Synchronisée"
(success). Account badge: "OK" (success) or "En erreur depuis le …" (danger). RDV badge colors: transmitted = success,
ignored = info, pending = warning, failed = danger, cancelled = neutral.

## Not in this change

The static error pages (`public/*.html`), the mailers, dark mode, and any text change beyond splitting long option
labels into a label and a help text.

## Checking it

Request specs keep checking the texts; one more checks that both layouts load the theme. The pages are checked by hand
on a phone through the tailnet, with the app bound to `0.0.0.0`.
