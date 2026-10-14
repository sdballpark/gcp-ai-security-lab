# Closes F7-04: detections existed as log-based metrics but notified no one.
# Log-match alerts fire on each matching audit entry, rate limited per policy.

locals {
  alert_project = "rb-ai-prod-sim-1013"

  detections = {
    cloudrun_ingress_opened = {
      display  = "Cloud Run ingress opened to the internet"
      severity = "ERROR"
      filter   = <<-EOT
        logName:"cloudaudit.googleapis.com%2Factivity" AND protoPayload.serviceName="run.googleapis.com"
        AND (protoPayload.methodName="google.cloud.run.v1.Services.ReplaceService" OR protoPayload.methodName="google.cloud.run.v1.Services.CreateService")
        AND NOT protoPayload.request.service.metadata.annotations."run.googleapis.com/ingress"="internal-and-cloud-load-balancing"
        AND NOT protoPayload.request.service.metadata.annotations."run.googleapis.com/ingress"="internal"
      EOT
      doc      = "A Cloud Run service was created or updated with ingress not limited to internal and load balancer traffic. The default URL then bypasses Cloud Armor (F6-01). Check who deployed it and restore ingress to internal-and-cloud-load-balancing."
    }

    kms_key_disabled_or_destroyed = {
      display  = "KMS key version disabled or scheduled for destruction"
      severity = "CRITICAL"
      filter   = <<-EOT
        logName:"cloudaudit.googleapis.com%2Factivity" AND protoPayload.serviceName="cloudkms.googleapis.com"
        AND ((protoPayload.methodName="UpdateCryptoKeyVersion" AND NOT protoPayload.request.cryptoKeyVersion.state="ENABLED")
        OR protoPayload.methodName="DestroyCryptoKeyVersion")
      EOT
      doc      = "A KMS key version was disabled or scheduled for destruction. Data encrypted with it becomes unreadable to every workload (F7-06). Confirm the change was approved. Destruction cannot be undone once the scheduled period ends."
    }

    modelarmor_guardrail_changed = {
      display  = "Model Armor template or floor setting changed"
      severity = "WARNING"
      filter   = <<-EOT
        logName:"cloudaudit.googleapis.com%2Factivity" AND protoPayload.serviceName="modelarmor.googleapis.com"
        AND (protoPayload.methodName:"UpdateFloorSetting" OR protoPayload.methodName:"UpdateTemplate"
        OR protoPayload.methodName:"DeleteTemplate")
      EOT
      doc      = "A Model Armor template or floor setting was changed or deleted. Confirm the change was approved, then confirm enforcement still blocks test prompts. The console status alone is not proof (F3-02)."
    }
  }
}

resource "google_monitoring_notification_channel" "security_email" {
  project      = local.alert_project
  display_name = "Security alerts (lab)"
  type         = "email"
  labels = {
    email_address = "robert.bogan3@gmail.com"
  }
}

resource "google_monitoring_alert_policy" "detection" {
  for_each = local.detections

  project      = local.alert_project
  display_name = each.value.display
  combiner     = "OR"
  severity     = each.value.severity

  conditions {
    display_name = each.value.display
    condition_matched_log {
      filter = each.value.filter
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "1800s"
  }

  notification_channels = [google_monitoring_notification_channel.security_email.id]

  documentation {
    content   = each.value.doc
    mime_type = "text/markdown"
  }
}
