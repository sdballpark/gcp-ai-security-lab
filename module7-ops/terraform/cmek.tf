resource "google_kms_key_ring" "lab" {
  name     = "ai-lab-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "rag_data" {
  name            = "rag-data-key"
  key_ring        = google_kms_key_ring.lab.id
  rotation_period = "7776000s" # 90 days
}

# Cloud Storage encrypts with this key on the project's behalf, so its service agent needs access
data "google_storage_project_service_account" "gcs" {}

resource "google_kms_crypto_key_iam_member" "gcs_uses_key" {
  crypto_key_id = google_kms_crypto_key.rag_data.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_storage_bucket" "cmek" {
  name                        = "${var.project_id}-docs-cmek"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  encryption { default_kms_key_name = google_kms_crypto_key.rag_data.id }
  depends_on                  = [google_kms_crypto_key_iam_member.gcs_uses_key]
}

output "key_id" { value = google_kms_crypto_key.rag_data.id }
