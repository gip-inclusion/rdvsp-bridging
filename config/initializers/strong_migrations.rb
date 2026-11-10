# Migrations run when the container starts, while RDV-SP and GoodJob use the tables: a migration waiting for a lock
# would make every query on that table queue behind it. Give up after 10 seconds instead, and retry a few times.
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.lock_timeout_retries = 3
