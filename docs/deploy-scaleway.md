# Deploying on Scaleway

## Current deployment (2026-10-20)

- Project **nova**, Serverless Container **`rdvsp-bridging`** in namespace `nova` (1 instance, 1 GB, 560 mVCPU,
  HTTPS only, startup/liveness probes on `/up`).
- URL: <https://novarw2u9ckv-rdvsp-bridging.functions.fnc.fr-par.scw.cloud> (no custom domain yet).
- Image: `rg.fr-par.scw.cloud/nova-container-registry/rdvsp-bridging:latest`.
- Database `rdvsp_bridging` (user `rdvsp_bridging`, `permission=all` on that database only) on the shared
  **`proto-db`** instance (PostgreSQL 16).
- Secrets are Scaleway *secret* environment variables; the only other copy is the git-ignored `.env.scaleway` on
  Louis-Jean's machine (keep it somewhere safe: the encryption keys can't be recovered from Scaleway).
- Deploys: `make deploy` locally (`scw registry login`, `SCW_REGISTRY=rg.fr-par.scw.cloud/nova-container-registry`), or
  the CI `deploy` job on every push to `main` once the repository has `SCW_ACCESS_KEY` / `SCW_SECRET_KEY`
  (`SCW_ORG_ID`, `SCW_PROJECT_ID`, `SCW_REGISTRY` are already set).
- No e-mail yet (no TEM domain in nova): alerts are only logged until `SMTP_*` and `ALERT_EMAIL` are set.

The rest of this page is the generic procedure.

Target (decided 2026-10-19): **Serverless Container** (min 1 instance: Pipedrive webhooks and the GoodJob cron run
in the web process) + **Managed Database for PostgreSQL**. Everything is configured through environment variables.

## 1. Database

- Create a Managed PostgreSQL instance (PostgreSQL 16 or 17, smallest node is plenty) and a database
  `rdvsp_bridging`.
- `DATABASE_URL=postgres://USER:PASSWORD@HOST:PORT/rdvsp_bridging?sslmode=require`
- Migrations run at container start (`bin/docker-entrypoint` → `db:prepare`).

## 2. Image

Serverless Containers run **linux/amd64**:

```bash
docker build --platform linux/amd64 -t rg.fr-par.scw.cloud/<namespace>/rdvsp-bridging:$(git rev-parse --short HEAD) .
docker login rg.fr-par.scw.cloud -u nologin --password-stdin <<< "$SCW_SECRET_KEY"
docker push rg.fr-par.scw.cloud/<namespace>/rdvsp-bridging:<tag>
```

## 3. Container

- Port: `8080` (Scaleway sets `PORT`, which is reserved), min scale **1**, max scale 1 for now (GoodJob runs in-process; more instances are
  fine for jobs but not needed).
- Health check: `GET /up`.
- Custom domain with HTTPS (e.g. `rdvsp-bridging.inclusion.gouv.fr`). TLS ends at Scaleway; the app assumes SSL.

### Environment variables

| Variable | Notes |
|---|---|
| `DATABASE_URL` | see above |
| `SECRET_KEY_BASE` | `openssl rand -hex 64` |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `..._DETERMINISTIC_KEY`, `..._KEY_DERIVATION_SALT` | `bin/rails db:encryption:init`; **losing them loses every stored Pipedrive token** |
| `BRIDGE_BASE_URL` | public `https://…` URL; the only host accepted in production, the base of every URL shown or registered, and enables Pipedrive webhook subscription at onboarding |
| `ADMIN_PASSWORD` | HTTP basic auth for `/admin` (user `admin`) |
| `ALERT_EMAIL` | our address for sync alerts |
| `MAIL_FROM` | sender address (default `ne-pas-repondre@inclusion.gouv.fr`) |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Scaleway TEM: `smtp.tem.scaleway.com`, `587`, project ID, secret key |
| `SENTRY_DSN` (optional) | `send_default_pii` is off: request bodies can contain usager data |
| `RAILS_LOG_LEVEL` (optional) | default `info` |

Secrets go in the container's **secret** environment variables, not plain ones.

## 4. Onboarding after deploy

1. `/admin` → "Connecter un compte Pipedrive" with an admin API token (creates the "RDV Service Public" activity
   type and the webhook, since `BRIDGE_BASE_URL` is https).
2. Account page → "Connecter un utilisateur Pipedrive" → credentials page (password shown once).
3. In RDV-SP, as that agent: *Synchronisation d’agenda → Connecter mon agenda via Caldav*, paste the URL,
   username and password, pick the "Pipedrive – …" calendar.
4. Check the connection page: "Dernier passage de RDV-SP" should update within 15 minutes.
