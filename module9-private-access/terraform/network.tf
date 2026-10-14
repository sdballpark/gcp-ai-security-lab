# Module 9: private access pattern for the AI app.
# Cloud Run sends all outbound traffic into this subnet. Google APIs resolve to the
# private VIP and are reachable; everything else is denied. There is no Cloud NAT,
# so the subnet has no internet path even before the firewall.

locals {
  project = "rb-ai-prod-sim-1013"
  region  = "us-central1"
}

resource "google_compute_network" "ai" {
  project                 = local.project
  name                    = "ai-app-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "run" {
  project                  = local.project
  name                     = "ai-app-run-subnet"
  region                   = local.region
  network                  = google_compute_network.ai.id
  ip_cidr_range            = "10.10.0.0/26"
  private_ip_google_access = true
}

resource "google_dns_managed_zone" "googleapis" {
  project     = local.project
  name        = "googleapis-private"
  dns_name    = "googleapis.com."
  visibility  = "private"
  description = "Resolves Google APIs to the private VIP inside ai-app-vpc"
  private_visibility_config {
    networks {
      network_url = google_compute_network.ai.id
    }
  }
}

resource "google_dns_record_set" "private_vip" {
  project      = local.project
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "private.googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
}

resource "google_dns_record_set" "wildcard" {
  project      = local.project
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["private.googleapis.com."]
}

resource "google_compute_firewall" "allow_google_apis" {
  project            = local.project
  name               = "ai-app-allow-google-apis"
  network            = google_compute_network.ai.id
  direction          = "EGRESS"
  priority           = 1000
  destination_ranges = ["199.36.153.8/30"]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "deny_all_egress" {
  project            = local.project
  name               = "ai-app-deny-all-egress"
  network            = google_compute_network.ai.id
  direction          = "EGRESS"
  priority           = 65000
  destination_ranges = ["0.0.0.0/0"]
  deny {
    protocol = "all"
  }
}
