resource "google_compute_region_network_endpoint_group" "run_neg" {
  name                  = "store-assistant-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"
  cloud_run { service = "store-assistant" }
}

resource "google_compute_backend_service" "run_backend" {
  name                  = "store-assistant-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_security_policy.ai_app.id
  backend { group = google_compute_region_network_endpoint_group.run_neg.id }
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "lb" {
  name            = "store-assistant-urlmap"
  default_service = google_compute_backend_service.run_backend.id
}

resource "google_compute_target_http_proxy" "lb" {
  name    = "store-assistant-http-proxy"
  url_map = google_compute_url_map.lb.id
}

resource "google_compute_global_address" "lb" {
  name = "store-assistant-ip"
}

resource "google_compute_global_forwarding_rule" "lb" {
  name                  = "store-assistant-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.lb.id
  ip_address            = google_compute_global_address.lb.id
}

output "lb_ip" { value = google_compute_global_address.lb.address }
