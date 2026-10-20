# rdvsp-bridging

Lets people whose calendar lives in a third-party system (Pipedrive first) use **RDV Service Public** both ways —
their busy times block slots in RDV-SP, and RDVs booked in RDV-SP show up in their tool — **without any change to
RDV-SP**: the bridge impersonates the CalDAV server RDV-SP already knows how to sync with.

- How it works and conventions: [`CLAUDE.md`](CLAUDE.md)
- Decision log: [`DECISIONS.md`](DECISIONS.md)
- Deployment: [`docs/deploy-scaleway.md`](docs/deploy-scaleway.md) — running at https://novarw2u9ckv-rdvsp-bridging.functions.fnc.fr-par.scw.cloud
- End-to-end test with a real RDV-SP: [`script/e2e/`](script/e2e/README.md)

```bash
cp .env.example .env   # then fill the encryption keys (bin/rails db:encryption:init)
make install
make run               # http://localhost:3010/admin (admin / admin in development)
make test
make lint
```
