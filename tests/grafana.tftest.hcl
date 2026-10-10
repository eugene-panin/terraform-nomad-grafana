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
