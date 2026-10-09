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
  description = "CPU (MHz) and memory (MB) for the Grafana task."
  type = object({
    cpu    = optional(number, 500)
    memory = optional(number, 512)
  })
  default = {}
}
