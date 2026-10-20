# End-to-end test against a real RDV Service Public

These scripts run **inside an RDV-SP checkout** (`bin/rails runner`) and drive RDV-SP's own CalDAV code
(`Agents::CaldavSyncController#caldav_config_error`, `Caldav::ImportAbsencesFromCaldavJob`,
`Caldav::ExportRdvToCaldavJob`, `CreneauxSearch::Calculator`) against a running bridge.

Validated on 2026-10-19 against `betagouv/rdv-service-public@production` (8a20a75, 2026-10-14).

```bash
# 1. RDV-SP: clone, Postgres 16 + Redis, seed
git clone --depth 1 https://github.com/betagouv/rdv-service-public rdvsp && cd rdvsp
docker compose -p rdvsp-e2e -f <rdvsp-bridging>/script/e2e/docker-compose.rdvsp.yml up -d
cp .env.sample .env  # then set POSTGRES_HOST=127.0.0.1 POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres PGPORT=5443
rv run bundle install && rv run bin/rails db:create db:schema:load db:seed

# 2. Bridge: run it, onboard the sandbox, write the CalDAV credentials of a connection to creds.json
#    ({"url": "...calendar/", "username": "...", "password": "..."})

# 3. RDV-SP side
rv run bin/rails runner <rdvsp-bridging>/script/e2e/rdvsp_setup.rb creds.json ctx.json   # connect + import + slots
rv run bin/rails runner <rdvsp-bridging>/script/e2e/rdvsp_probe_days.rb ctx.json         # slots over two weeks
rv run bin/rails runner <rdvsp-bridging>/script/e2e/rdvsp_rdv.rb ctx.json create rdv-id.txt
rv run bin/rails runner <rdvsp-bridging>/script/e2e/rdvsp_rdv.rb ctx.json move rdv-id.txt
rv run bin/rails runner <rdvsp-bridging>/script/e2e/rdvsp_rdv.rb ctx.json import rdv-id.txt
rv run bin/rails runner <rdvsp-bridging>/script/e2e/rdvsp_rdv.rb ctx.json cancel rdv-id.txt
```

Expected: Pipedrive meetings remove the matching slots; the RDV appears in Pipedrive (dedicated activity type,
moved and then deleted with RDV-SP), and is never re-imported as busy.
