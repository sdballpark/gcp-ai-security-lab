# Module 7 Logging, Detections, and CMEK Findings

Date tested: 2026-10-13
Project: rb-ai-prod-sim-1013. Detections built as Cloud Logging log-based metrics on Admin Activity audit logs.

## Detections
| Metric | Purpose | Validation |
|---|---|---|
| cloudrun_ingress_opened | Cloud Run created or updated with ingress not restricted to internal and load balancer traffic. Reopens F6-01. | Backtest over 6h: 6 true positives (4 explicit ingress=all, 2 CreateService with ingress unset), 1 true negative (the 22:32 UTC fix). |
| modelarmor_guardrail_changed | Model Armor template or floor setting updated or deleted. | Not backtested. One UpdateFloorSetting event exists in the window. |
| kms_key_disabled_or_destroyed | KMS key version disabled or scheduled for destruction. | Backtest: matched the 23:18 UTC disable. Initial version also matched the re-enable; filter tuned to exclude ENABLED. |

## F7-01 Method name alone is not a usable detection for Cloud Run (INFO, design)
Ingress changes, deploys, and env var updates all log as ReplaceService. Alerting on the method would fire on every release.
Detection inspects protoPayload.request.service.metadata.annotations."run.googleapis.com/ingress".

## F7-02 Missing-field case must be handled explicitly (MEDIUM, detection quality)
Two CreateService events had no ingress annotation, which means public by default.
The filter uses NOT field="restricted value" so a missing field still matches. A != comparison risks missing the default-public case.

## F7-03 First KMS detection draft alerted on recovery actions (LOW, tuning)
Re-enabling a key matched the same rule as disabling it. Tuned to exclude state ENABLED. Alerts that fire on fixes get muted.

## F7-04 Metrics exist without alert policies (MEDIUM, gap)
No notification channel or alert policy is attached. Metrics count events but notify no one.
Next step: alert policy per metric, routed to the SIEM or an on-call channel.

## F7-05 Guardrail-removal path not covered (MEDIUM, gap)
Removing the MA_TEMPLATE env var from Cloud Run disables Model Armor enforcement (Module 3) and logs as a routine ReplaceService.
Needs a detection on the env var's absence in the service spec.

## CMEK test
Bucket rb-ai-prod-sim-1013-docs-cmek defaults to key rag-data-key (90-day rotation). Only the Cloud Storage service agent holds encrypter/decrypter on the key.
| Step | Result |
|---|---|
| Object written | Encrypted with rag-data-key/cryptoKeyVersions/1 |
| Read, key enabled | Succeeded |
| Read, key version disabled | Failed: HTTP 400 KEY_DISABLED |
| Read, key version re-enabled | Succeeded |

## F7-06 CMEK gives a revocable control and an outage lever (MEDIUM, design)
Disabling the key made data unreadable to everyone, the provider included. The same action by mistake takes every dependent workload down.
Recommendation: separate key administration from data access, alert on key state changes (kms_key_disabled_or_destroyed), and treat key destruction as irreversible crypto-shredding.

## CMEK applicability notes
Applies to data the AI workload stores: RAG source buckets, clean and quarantine buckets, log buckets, and any vector or search index that persists content.
Each service must be checked against Google's CMEK-supported services list before claiming coverage. Stateless model inference raises a data retention question, not a CMEK question.

## Controls verified
C7-01 Ingress-opening detection fires on real open-ingress deploys, including default-public, and not on the fix.
C7-02 Customer-managed key revocation renders stored data unreadable, and restoration is reversible.
C7-03 Key-state detection fires on disable, not on re-enable.

## Security Command Center (CSPM)
Activated Standard tier at organization level on aristotle.systems (896039580817), 2026-10-13.
Project-level activation for rb-ai-prod-sim-1013 (no parent organization) was not attempted; Google documentation describes project-level activation relative to a parent organization. The AI app projects are outside this SCC activation; only organization projects are scanned.
Role required in addition to Organization Admin: roles/securitycenter.admin, granted at organization level.
Encryption choice made at activation: Google-managed key. SCC findings data can use CMEK only if selected at activation, so this belongs in the CMEK applicability model as a pre-activation decision.
Initial state: no findings. First scan of a new organization can take hours. Findings review pending.

## F7-07 Workloads outside the organization are invisible to org-level CSPM (MEDIUM, coverage)
Projects created under a personal account, with no organization, cannot be enrolled in organization-level SCC.
Enterprise relevance: shadow projects created outside the corporate org escape posture monitoring entirely.
Recommendation: restrict project creation to the organization and inventory billing accounts for projects outside it.

## F7-08 SCC active, but misconfiguration scanning is not available (HIGH, coverage)
Date tested: 2026-10-14. Zero findings after activation. A canary firewall rule allowing TCP 22 from 0.0.0.0/0 was created at 16:05 UTC on an empty network in ai-org-outside-1013 and was not detected by 18:00 UTC.
Security Health Analytics: effectiveEnablementState DISABLED, intendedEnablementState INHERITED. Not listed among available services in the console. Enabling through the API returned FAILED_PRECONDITION. Tier confirmed as Standard on the Setup details page.
Canary deleted at 18:09 UTC.
Lesson: a zero-findings result is only meaningful after a canary proves the detector fires. The SCC v1 findings API is retired; v2 with --location=global is required.
Full write-up: decision-support/scc-findings-report.md

## F7-04 closed: alert policies attached and tested (2026-10-14)
alerts.tf adds an email channel and three log-match alert policies, each with a 5-minute rate limit.

| Alert | Event (UTC) | Email (UTC) | Email on the fix? |
|---|---|---|---|
| KMS key disabled | Disable 18:53:14 | 18:55 | No. Re-enable at 19:00:15 sent nothing. |
| Model Armor template changed | Rejected update 19:04:28, audit code 3 | 19:06 | Successful fix at 19:07:08 fell inside the rate limit |
| Cloud Run ingress opened | Open 19:08:25 | 19:09 | No. Restore at 19:15:29 sent nothing. |

## F7-09 A new alert policy is not live right after creation (LOW, testing)
The key was disabled 45 seconds after the policy was created. The audit entry was logged and matched the filter, but no alert fired. The same test 12 minutes later alerted in about 2 minutes.
Wait a few minutes after deploying alert policies before testing them. A miss right after terraform apply does not prove the filter is broken.

## F7-05 closed: guardrail-removal alert (2026-10-14)
The first draft filtered Cloud Run audit logs for deploys missing MA_TEMPLATE. It matched every deploy (F7-10). The detection now matches the app's own refusal line instead: `resource.type="cloud_run_revision" AND textPayload:"Refusing to start"`. This works because the Module 8 app refuses to start without the setting.

Backtest: matched only revisions 00006 (one line at 20:06 UTC) and 00009 (16 lines from 20:10:19), the two deploys made without the setting.

| Step | Time (UTC) | Result |
|---|---|---|
| Alert created | 20:57:38 | |
| MA_TEMPLATE removed | 21:03:00 | Revision 00012 rejected. Traffic stayed on 00011. |
| Email | 21:05 | Named revision 00012 |
| Setting restored | | Revision 00013 serving |

## F7-10 Cloud Run audit logs do not record environment variables (INFO, design)
The container spec in the ReplaceService audit entry holds the image and resources only. A filter on an environment variable's absence therefore matches every deploy. A guardrail held in an environment variable cannot be monitored from the audit trail. The app has to report it.

## Data Access logs and bulk-read alert (audit.tf, 2026-10-14)
- DATA_READ audit logs on for storage.googleapis.com and aiplatform.googleapis.com.
- Log-based metric sensitive_object_reads: storage.objects.get on the raw and quarantine buckets.
- Alert bulk_sensitive_reads: more than 10 entries in 5 minutes.

| Step | Time (UTC) | Result |
|---|---|---|
| Read 42 seconds after the audit config was applied | 21:08:48 | Not logged |
| Alert creation | | Failed: the new metric was not yet visible to Monitoring. Applied at 21:18:39 after waiting. |
| Ten object reads | 21:24:00 to 21:24:27 | 20 objects.get entries and 10 getStorageLayout |
| Email | 21:28 | Value 20, threshold 5 |
| Threshold raised to 10 | 21:30:05 | |

## F7-11 One read is not one log entry (LOW, tuning)
Each `gcloud storage cat` wrote two objects.get entries. A threshold of 5 assumed one entry per read, and would have fired on a normal ingestion run (6 to 8 entries). Raised to more than 10, about five objects. Count entries per action for each client before setting a threshold.

## A control is not live when the API says it is
Four times in this lab, a change reported success and the control did not work yet:

| Control | Tested after | Result |
|---|---|---|
| Alert policy | 45 seconds | No alert (F7-09) |
| Impersonation grant | 90 seconds | Denied |
| Data Access audit logging | 42 seconds | Read not logged |
| Log-based metric used by an alert | Immediately | Metric not visible to the alert, for up to 10 minutes |

Wait, then confirm the control fired. A pass recorded seconds after `terraform apply` proves nothing, and neither does a miss.

## Alerts now active
| Alert | Detects |
|---|---|
| cloudrun_ingress_opened | Ingress opened beyond internal and load balancer |
| kms_key_disabled_or_destroyed | Key version disabled or scheduled for destruction |
| modelarmor_guardrail_changed | Template or floor setting updated or deleted, whether the call succeeded or not |
| guardrail_setting_missing | App refused to start because a guardrail setting was missing |
| bulk_sensitive_reads | More than 10 object reads from the raw or quarantine bucket in 5 minutes |

## Controls verified (2026-10-14)
C7-04 Guardrail removal from the deploy raises an email naming the rejected revision.
C7-05 Bulk reads of sensitive buckets raise an email within about 4 minutes.
