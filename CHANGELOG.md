# Changelog

## v0.1.0

- Grafana on a Nomad platform: one job, its database in a dynamic host volume the
  platform's backup copies by name (`meta.backup = "stop"`).
- Published by Traefik on the internal entrypoint (WireGuard-only), health-checked
  on `/api/health`.
- Provisions the given data sources (Mimir, Loki) pointing at their Consul
  addresses. Admin password generated and kept in Vault; a consumer reads it to
  push dashboards and alerts. Anonymous viewer on by default, analytics off.
