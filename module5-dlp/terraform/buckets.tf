locals {
  app_sa = "serviceAccount:store-assistant-sa@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_storage_bucket" "clean" {
  name                        = "${var.project_id}-docs-clean"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  labels = { module = "dlp", purpose = "rag-clean-corpus" }
}

resource "google_storage_bucket" "quarantine" {
  name                        = "${var.project_id}-docs-quarantine"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  labels = { module = "dlp", purpose = "rag-quarantine" }
}

# App reads the clean corpus only
resource "google_storage_bucket_iam_member" "app_reads_clean" {
  bucket = google_storage_bucket.clean.name
  role   = "roles/storage.objectViewer"
  member = local.app_sa
}
