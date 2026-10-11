variable "hostname" {
  description = "Fully qualified host name Grafana is served on, such as grafana.infra.example.com. Traefik routes it on the internal entrypoint, so it opens only over WireGuard."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.hostname))
    error_message = "hostname must be a lowercase fully qualified domain name."
  }
}

variable "vault_kv_path" {
  description = "Path of the Vault KV v2 engine the admin password is kept in; the platform gives it."
  type        = string
}

variable "datasources" {
  description = "Grafana data sources to provision, each pointing at a backend's Consul address (e.g. Mimir, Loki)."
  type = list(object({
    name       = string
    type       = string
    url        = string
    is_default = optional(bool, false)
  }))
  default = []
}

variable "admin_password" {
  description = "Grafana admin password. Null generates one, kept in Vault and returned by admin_secret; a consumer reads it to push dashboards and alerts."
  type        = string
  default     = null
  sensitive   = true
}

variable "namespace" {
  description = "Nomad namespace the job runs in."
  type        = string
  default     = "default"
}

variable "job_name" {
  description = "Name of the Nomad job, the Consul service and the Traefik router."
  type        = string
  default     = "grafana"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.job_name))
    error_message = "job_name must be lowercase letters, digits and -, starting with a letter."
  }
}

variable "datacenters" {
  description = "Nomad datacenters the job may run in."
  type        = list(string)
  default     = ["*"]
}

variable "image" {
  description = "Grafana container image, pinned by a fixed tag or a digest."
  type        = string
  default     = "grafana/grafana:11.4.0"
}

variable "http_port" {
  description = "Port Grafana serves on inside the platform; Traefik passes to it."
  type        = number
  default     = 3000
}

variable "anonymous_viewer" {
  description = "Let anyone who reaches Grafana (already behind WireGuard) read without a login; the admin still signs in to edit."
  type        = bool
  default     = true
}

variable "internal_host_network" {
  description = "Nomad host network Grafana binds to; Traefik reaches it there."
  type        = string
  default     = "default"
}

variable "traefik" {
  description = "Traefik entrypoint Grafana is published on and its certificate resolver. The defaults are the internal (WireGuard-only) entrypoint of the hashi platform."
  type = object({
    entrypoint   = optional(string, "internal")
    certresolver = optional(string, "dns")
  })
  default = {}
}

variable "resources" {
  description = "CPU (MHz) and memory (MB) for the Grafana task: memory is what it reserves (sized to its use), memory_max how far it may grow (Nomad memory oversubscription)."
  type = object({
    cpu        = optional(number, 500)
    memory     = optional(number, 128)
    memory_max = optional(number, 512)
  })
  default = {}
  validation {
    condition     = var.resources.memory_max >= var.resources.memory
    error_message = "resources.memory_max must be at least resources.memory."
  }
}

variable "dns_servers" {
  description = "DNS servers the Grafana job resolves through, such as the platform's Consul DNS, so a data source's URL can name a Consul service (mimir.service.consul) and be found wherever it runs. They must forward other names too. Empty: the node's resolvers."
  type        = list(string)
  default     = []
}

variable "mesh" {
  description = <<-EOT
    The Consul service mesh. enabled puts Grafana behind an Envoy sidecar (transparent
    proxy), as a client: it reaches its data sources as <name>.virtual.consul over mTLS, as
    their intentions allow — set their URLs to those names. Its HTTP port stays open for
    Traefik, which is outside the mesh.
  EOT
  type = object({
    enabled = optional(bool, false)
  })
  default = {}
}

variable "oidc" {
  description = <<-EOT
    Sign-in through an OIDC provider, such as Vault's on the platform (the hashistack sso
    output gives the URLs, scopes and admin group). Those whose groups claim holds
    admin_group are Admins; anyone else the provider lets through is refused. The client
    secret is kept in Vault with the admin credential. Null: only the admin password (and
    anonymous_viewer).
  EOT
  type = object({
    name          = optional(string, "Vault")
    client_id     = string
    client_secret = string
    auth_url      = string
    token_url     = string
    api_url       = string
    scopes        = optional(list(string), ["openid", "user", "groups"])
    admin_group   = optional(string, "platform-admins")
  })
  sensitive = true
  default   = null
}
