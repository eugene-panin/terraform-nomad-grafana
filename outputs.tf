output "job_id" {
  description = "ID of the Grafana job in Nomad."
  value       = nomad_job.grafana.id
}

output "url" {
  description = "URL Grafana is served on."
  value       = "https://${var.hostname}"
}

output "service_name" {
  description = "Consul service name of Grafana."
  value       = var.job_name
}

output "admin_secret" {
  description = "Vault KV name (under the mount) of the admin credential; a consumer reads it to push dashboards and alerts."
  value       = local.secret_name
}

output "admin_password" {
  description = "Grafana admin password."
  value       = local.admin_password
  sensitive   = true
}

output "data_volume" {
  description = "Name of the dynamic host volume holding Grafana's database."
  value       = nomad_dynamic_host_volume.data.name
}
