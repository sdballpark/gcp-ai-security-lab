locals {
  pii_types = ["US_SOCIAL_SECURITY_NUMBER", "CREDIT_CARD_NUMBER", "EMAIL_ADDRESS", "PHONE_NUMBER", "STREET_ADDRESS"]
}

resource "google_data_loss_prevention_inspect_template" "rag_pii" {
  parent       = "projects/${var.project_id}/locations/global"
  template_id  = "rag-pii-inspect"
  display_name = "RAG ingestion PII inspection"
  description  = "PII detectors for documents entering the RAG corpus. PERSON_NAME excluded by design; data owner decision."

  inspect_config {
    min_likelihood = "POSSIBLE"
    dynamic "info_types" {
      for_each = local.pii_types
      content { name = info_types.value }
    }
  }
}

resource "google_data_loss_prevention_deidentify_template" "rag_mask" {
  parent       = "projects/${var.project_id}/locations/global"
  template_id  = "rag-pii-deidentify"
  display_name = "RAG ingestion PII masking"
  description  = "Replaces detected PII with its type label, e.g. [US_SOCIAL_SECURITY_NUMBER]."

  deidentify_config {
    info_type_transformations {
      transformations {
        dynamic "info_types" {
          for_each = local.pii_types
          content { name = info_types.value }
        }
        primitive_transformation {
          replace_with_info_type_config = true
        }
      }
    }
  }
}

output "inspect_template" { value = google_data_loss_prevention_inspect_template.rag_pii.id }
output "deidentify_template" { value = google_data_loss_prevention_deidentify_template.rag_mask.id }
