locals {
  secret_name    = "${var.namespace}/${var.job_name}/admin"
  volume_name    = "${var.job_name}-data"
  admin_password = coalesce(var.admin_password, random_password.admin.result)
  admin_secret   = { username = "admin", password = local.admin_password }
  secret_version = parseint(substr(sha256(jsonencode(local.admin_secret)), 0, 8), 16)

  datasources_yaml = yamlencode({
    apiVersion = 1
    datasources = [
      for d in var.datasources : {
        name      = d.name
        type      = d.type
        access    = "proxy"
        url       = d.url
        isDefault = d.is_default
      }
    ]
  })
}

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "admin" {
  mount                = var.vault_kv_path
  name                 = local.secret_name
  data_json_wo         = jsonencode(local.admin_secret)
  data_json_wo_version = local.secret_version
}

resource "nomad_dynamic_host_volume" "data" {
  name      = local.volume_name
  namespace = var.namespace
  plugin_id = "mkdir"

  parameters = {
    mode = "0700"
    uid  = "472"
    gid  = "472"
  }

  capability {
    access_mode     = "single-node-writer"
    attachment_mode = "file-system"
  }
}

resource "nomad_job" "grafana" {
  jobspec = templatefile("${path.module}/templates/grafana.nomad.hcl.tftpl", {
    job_name         = var.job_name
    namespace        = var.namespace
    datacenters      = var.datacenters
    volume_name      = nomad_dynamic_host_volume.data.name
    secret_path      = "${var.vault_kv_path}/data/${local.secret_name}"
    secret_version   = local.secret_version
    internal_network = var.internal_host_network
    traefik          = var.traefik
    hostname         = var.hostname
    image            = var.image
    http_port        = var.http_port
    anonymous_viewer = var.anonymous_viewer
    datasources_yaml = local.datasources_yaml
    resources        = var.resources
    dns_servers      = var.dns_servers
  })

  purge_on_destroy = true

  depends_on = [vault_kv_secret_v2.admin]
}
