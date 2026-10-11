mock_provider "consul" {}
mock_provider "nomad" {}
mock_provider "random" {}
mock_provider "vault" {}

variables {
  hostname      = "grafana.infra.example.com"
  vault_kv_path = "secret"
  datasources = [
    { name = "Mimir", type = "prometheus", url = "http://10.77.0.1:9009/prometheus", is_default = true },
    { name = "Loki", type = "loki", url = "http://10.77.0.1:3100" },
  ]
}

run "it_serves_on_the_internal_entrypoint" {
  command = apply

  assert {
    condition     = output.url == "https://grafana.infra.example.com"
    error_message = "Grafana is not served on its hostname."
  }

  assert {
    condition     = strcontains(nomad_job.grafana.jobspec, "traefik.http.routers.grafana.entrypoints=internal")
    error_message = "Grafana must be on the internal (WireGuard-only) entrypoint."
  }

  assert {
    condition     = output.admin_secret == "default/grafana/admin"
    error_message = "The admin credential is not at the expected Vault name."
  }
}

run "it_provisions_the_datasources" {
  command = apply

  assert {
    condition     = strcontains(nomad_job.grafana.jobspec, "http://10.77.0.1:9009/prometheus")
    error_message = "The Mimir data source is not provisioned."
  }

  assert {
    condition     = strcontains(nomad_job.grafana.jobspec, "http://10.77.0.1:3100")
    error_message = "The Loki data source is not provisioned."
  }
}

run "the_datasources_by_their_consul_names" {
  command = apply

  variables {
    datasources = [
      { name = "Mimir", type = "prometheus", url = "http://mimir.service.consul:9009/prometheus", is_default = true },
      { name = "Loki", type = "loki", url = "http://loki.service.consul:3100" },
    ]
    dns_servers = ["10.77.0.1"]
  }

  assert {
    condition = (
      strcontains(nomad_job.grafana.jobspec, "servers = [\"10.77.0.1\"]")
      && strcontains(nomad_job.grafana.jobspec, "http://mimir.service.consul:9009/prometheus")
      && strcontains(nomad_job.grafana.jobspec, "http://loki.service.consul:3100")
    )
    error_message = "Grafana must resolve through the given DNS and reach its data sources by their Consul names."
  }
}

run "memory_is_reserved_by_use_and_may_grow" {
  command = apply

  assert {
    condition     = strcontains(nomad_job.grafana.jobspec, "memory     = 128") && strcontains(nomad_job.grafana.jobspec, "memory_max = 512")
    error_message = "The task must reserve its usual memory and be allowed to grow to memory_max."
  }
}

run "it_joins_the_mesh_as_a_client" {
  command = apply

  variables {
    mesh = { enabled = true }
  }

  assert {
    condition = (
      strcontains(nomad_job.grafana.jobspec, "transparent_proxy")
      && strcontains(nomad_job.grafana.jobspec, "exclude_inbound_ports = [\"3000\",\"9102\"]")
      && strcontains(nomad_job.grafana.jobspec, "tags = [\"mesh-sidecar\"]")
      && strcontains(nomad_job.grafana.jobspec, "name     = \"grafana-envoy\"")
      && jsondecode(consul_config_entry.defaults[0].config_json).Protocol == "http"
    )
    error_message = "In the mesh Grafana must sit behind an Envoy sidecar with its own tags, keep its port open for Traefik, and expose Envoy's metrics."
  }
}

run "out_of_the_mesh_by_default" {
  command = apply

  assert {
    condition     = !strcontains(nomad_job.grafana.jobspec, "connect {") && length(consul_config_entry.defaults) == 0
    error_message = "Without mesh.enabled there is no sidecar."
  }
}

run "envoy_passes_to_the_port_inside_the_group" {
  command = apply

  variables {
    mesh = { enabled = true }
  }

  assert {
    condition     = strcontains(nomad_job.grafana.jobspec, "local_service_port = 3000")
    error_message = "With a dynamic port, Envoy must be told the port inside the group."
  }
}

run "it_signs_people_in_through_oidc" {
  command = apply

  variables {
    anonymous_viewer = false
    oidc = {
      client_id     = "grafana-client"
      client_secret = "s3cret"
      auth_url      = "https://vault.example.com/ui/vault/identity/oidc/provider/platform/authorize"
      token_url     = "https://vault.example.com/v1/identity/oidc/provider/platform/token"
      api_url       = "https://vault.example.com/v1/identity/oidc/provider/platform/userinfo"
    }
  }

  assert {
    condition = (
      strcontains(nomad_job.grafana.jobspec, "GF_AUTH_GENERIC_OAUTH_CLIENT_ID           = \"grafana-client\"")
      && strcontains(nomad_job.grafana.jobspec, "contains(groups[*], 'platform-admins') && 'Admin' || ''")
      && strcontains(nomad_job.grafana.jobspec, "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET={{ .Data.data.oidc_client_secret }}")
      && !strcontains(nomad_job.grafana.jobspec, "s3cret")
      && strcontains(nomad_job.grafana.jobspec, "GF_AUTH_ANONYMOUS_ENABLED            = \"false\"")
    )
    error_message = "Grafana must sign people in through the provider, make its admin group Admins, and read the client secret from Vault, never from the jobspec."
  }
}
