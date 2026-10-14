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
