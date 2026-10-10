# Changelog

## v0.1.0

- Grafana on a Nomad platform: one job, its database in a dynamic host volume the
  platform's backup copies by name (`meta.backup = "stop"`).
- Published by Traefik on the internal entrypoint (WireGuard-only), health-checked
  on `/api/health`.
- Provisions the given data sources (Mimir, Loki) pointing at their Consul
  addresses. Admin password generated and kept in Vault; a consumer reads it to
  push dashboards and alerts. Anonymous viewer on by default, analytics off.

## v0.1.1

- `dns_servers`: the job resolves through them, such as the platform's Consul
  DNS, so data source URLs can name Consul services (`mimir.service.consul`,
  `loki.service.consul`) and be found wherever they run.

## v0.1.2

- The task reserves 128 MB, sized to its use, and may grow to 512 MB:
  `resources.memory_max` (Nomad memory oversubscription, which the platform
  turns on). It reserved more than it used before.
