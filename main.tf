locals {
  secret_name    = "${var.namespace}/${var.job_name}/admin"
  volume_name    = "${var.job_name}-data"
  admin_password = coalesce(var.admin_password, random_password.admin.result)
  # The OIDC client's secret, when Grafana signs people in through a provider,
  # is kept with the admin credential: the job reads only its own secret.
  admin_secret = merge(
    { username = "admin", password = local.admin_password },
    var.oidc == null ? {} : { oidc_client_secret = var.oidc.client_secret },
  )
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
    # Without the secret (the job reads it from Vault), so the jobspec is not secret.
    oidc             = var.oidc == null ? null : nonsensitive({ for k, v in var.oidc : k => v if k != "client_secret" })
    datasources_yaml = local.datasources_yaml
    resources        = var.resources
    dns_servers      = var.dns_servers
    mesh             = var.mesh
  })

  purge_on_destroy = true

  depends_on = [vault_kv_secret_v2.admin]
}

# In the mesh: what Consul's L7 features see. Grafana is only a client there
# (Traefik reaches it from outside), so no service is allowed to it.
resource "consul_config_entry" "defaults" {
  count = var.mesh.enabled ? 1 : 0

  kind = "service-defaults"
  name = var.job_name
  config_json = jsonencode({
    # As Consul stores it (with the empty blocks it fills in), so a plan sees no drift.
    Protocol         = "http"
    Expose           = {}
    MeshGateway      = {}
    TransparentProxy = {}
  })
}
