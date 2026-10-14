# LG-01: Data Access read logs for Cloud Storage and Vertex AI, and a bulk-read
# alert on the buckets that hold unmasked or quarantined data (R-004 backlog item 1).

resource "google_project_iam_audit_config" "storage_reads" {
  project = local.alert_project
  service = "storage.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
}

resource "google_project_iam_audit_config" "vertex_reads" {
  project = local.alert_project
  service = "aiplatform.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
}

resource "google_logging_metric" "sensitive_object_reads" {
  project     = local.alert_project
  name        = "sensitive_object_reads"
  description = "Object reads from the raw and quarantine buckets, from Data Access logs."
  filter      = <<-EOT
    logName:"cloudaudit.googleapis.com%2Fdata_access" AND protoPayload.serviceName="storage.googleapis.com"
    AND protoPayload.methodName="storage.objects.get"
    AND resource.labels.bucket_name=("rb-ai-prod-sim-1013-docs" OR "rb-ai-prod-sim-1013-docs-quarantine")
  EOT
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "bulk_sensitive_reads" {
  project      = local.alert_project
  display_name = "Bulk reads from sensitive buckets"
  combiner     = "OR"
  severity     = "ERROR"

  conditions {
    display_name = "More than 10 object-read log entries in 5 minutes"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.sensitive_object_reads.name}\" AND resource.type=\"gcs_bucket\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  notification_channels = [google_monitoring_notification_channel.security_email.id]

  documentation {
    content   = "More than 10 object-read log entries from the raw or quarantine bucket within 5 minutes. Each read through gcloud writes two entries (metadata and content), so this is roughly more than 5 objects. A normal ingestion run reads 3 to 4 objects, 6 to 8 entries. Check the Data Access log for who read them, from where, and whether the reader should have access (R-004, DF-02)."
    mime_type = "text/markdown"
  }
}
