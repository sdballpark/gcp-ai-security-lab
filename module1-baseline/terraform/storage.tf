resource "google_storage_bucket" "docs" {
  name                        = "${var.project_id}-docs"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  labels = {
    module  = "baseline"
    purpose = "rag-source-docs"
  }
}

output "docs_bucket" {
  value = google_storage_bucket.docs.name
}
