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

## v0.1.3

- `mesh`: Grafana can join the Consul service mesh as a client — an Envoy
  sidecar with the transparent proxy, so it reaches data sources named
  `<name>.virtual.consul` over mTLS, as their intentions allow. Its port stays
  open for Traefik; the sidecar carries its own tags so Traefik's router is not
  duplicated. Envoy's metrics are a `<job_name>-envoy` service tagged for Alloy.

## v0.1.4

- The mesh's config entries are written as Consul stores them (the empty
  blocks it fills into service-defaults; Type and Precedence on each intention
  source), so a plan no longer rewrites them on every apply.

## v0.1.5

- Envoy passes the mesh's traffic to the port inside the group
  (`local_service_port`), not to the dynamic host port the service is
  registered with, where nothing listens.

## v0.1.6

- `oidc`: Grafana can sign people in through an OIDC provider, such as Vault's
  on the platform: those in its admin group are Admins, anyone else is refused.
  The client secret is kept in Vault with the admin credential and read by the
  job; it never reaches the jobspec.
