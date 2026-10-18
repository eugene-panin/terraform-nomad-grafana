# terraform-nomad-grafana

Grafana on a Nomad platform that has Consul, Vault and Traefik — such as
[hashi](https://github.com/eugene-panin/damstack-hashi). The
[damstack-grafana](https://github.com/eugene-panin/damstack-grafana) stack wires
it.

The observability UI: one Nomad job, its database in a host volume, published by
Traefik on the **internal** entrypoint (behind WireGuard, like the platform's
other admin pages). It provisions the data sources you give it (Mimir, Loki),
each pointing at a backend's Consul address. The admin password is generated and
kept in Vault; a consumer app reads it to push its own dashboards and alerts.

## Inputs

| Name | Default | What |
| --- | --- | --- |
| `hostname` | — | FQDN Grafana is served on |
| `vault_kv_path` | — | Vault KV v2 mount the platform gives |
| `datasources` | `[]` | `[{name, type, url, is_default}]`, e.g. Mimir and Loki |
| `dns_servers` | `[]` | DNS servers the job resolves through (e.g. Consul DNS), for data source URLs naming Consul services; empty — the node's |
| `admin_password` | generated | Grafana admin password |
| `job_name` | `grafana` | Nomad job, Consul service, Traefik router |
| `namespace` | `default` | Nomad namespace |
| `datacenters` | `["*"]` | Nomad datacenters |
| `image` | `grafana/grafana:11.4.0` | image, pinned |
| `http_port` | `3000` | port Traefik passes to |
| `anonymous_viewer` | `true` | read without a login (already behind WireGuard) |
| `internal_host_network` | `default` | host network it binds to |
| `traefik` | internal, no resolver | `{entrypoint, certresolver}`; no resolver takes the entrypoint's certificate |
| `resources` | `{500, 512}` | `{cpu, memory}` |

## Outputs

`job_id`, `url`, `service_name`, `admin_secret` (Vault name), `admin_password`
(sensitive), `data_volume`.

## Development

```sh
make lint
make module-tests
```

## Service mesh

With `mesh.enabled`, Grafana gets an Envoy sidecar (transparent proxy) and joins
the mesh as a client: point the data sources at `mimir.virtual.consul` and
`loki.virtual.consul`, and allow `grafana` in their intentions. Its HTTP port
stays open for Traefik, which is outside the mesh.

## Sign-in through an OIDC provider

With `oidc`, Grafana signs people in through a provider (Vault's, on a hashistack
platform with `sso`): `auth_url`, `token_url`, `api_url` from its `sso` output, a
client made for Grafana with the redirect URI `https://<hostname>/login/generic_oauth`.
Those whose `groups` claim holds `admin_group` are Admins; anyone else is refused.
Turn `anonymous_viewer` off with it.
