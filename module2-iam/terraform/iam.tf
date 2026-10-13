resource "google_service_account" "store_assistant" {
  account_id   = "store-assistant-sa"
  display_name = "store-assistant runtime identity"
  description  = "Least-privilege identity for the store-assistant Cloud Run service"
}

# Read only, scoped to the docs bucket, not the project
resource "google_storage_bucket_iam_member" "docs_reader" {
  bucket = "${var.project_id}-docs"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.store_assistant.email}"
}

# Gemini calls on Vertex AI
resource "google_project_iam_member" "vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.store_assistant.email}"
}

output "store_assistant_sa" {
  value = google_service_account.store_assistant.email
}
