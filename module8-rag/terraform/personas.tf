# Module 8: test personas for per-user retrieval scoping.
# Each persona can invoke the app and nothing else. The operator can mint
# tokens as a persona only until the expiry below.

locals {
  project  = "rb-ai-prod-sim-1013"
  region   = "us-central1"
  service  = "store-assistant"
  operator = "user:robert.bogan3@gmail.com"
  personas = {
    "persona-store-staff" = "Test persona: store staff (all-staff)"
    "persona-hr"          = "Test persona: HR (all-staff, hr)"
  }
}

resource "google_service_account" "persona" {
  for_each     = local.personas
  project      = local.project
  account_id   = each.key
  display_name = each.value
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = local.personas
  project  = local.project
  location = local.region
  name     = local.service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.persona[each.key].email}"
}

resource "google_service_account_iam_member" "operator_can_test_as" {
  for_each           = local.personas
  service_account_id = google_service_account.persona[each.key].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.operator
  condition {
    title      = "module8-test-window"
    expression = "request.time < timestamp('2026-10-16T00:00:00Z')"
  }
}

output "persona_emails" {
  value = { for k, v in google_service_account.persona : k => v.email }
}
