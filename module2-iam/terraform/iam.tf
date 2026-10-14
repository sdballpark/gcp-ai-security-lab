resource "google_service_account" "store_assistant" {
  account_id   = "store-assistant-sa"
  display_name = "store-assistant runtime identity"
  description  = "Least-privilege identity for the store-assistant Cloud Run service"
}

# Read only, scoped to the docs bucket, not the project
# docs_reader removed 2026-10-14 (DF-01). The app reads docs-clean, granted in module5-dlp.

# Gemini calls on Vertex AI
resource "google_project_iam_member" "vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.store_assistant.email}"
}

output "store_assistant_sa" {
  value = google_service_account.store_assistant.email
}
