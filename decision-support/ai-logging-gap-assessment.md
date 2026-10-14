# AI Logging Gap Assessment

**Prepared by:** Robert Bogan, security architecture

> **This is a pilot on a fictitious retailer, built in a personal lab.** It does not describe any real organization's environment.

## Summary

Configuration changes are logged, and the three most damaging ones raise an email alert within about two minutes. When first checked, data access was not logged at all, so nobody could say who read the RAG source documents or who called the model, and Model Armor screening results were not logged either. Both were fixed the same day (LG-01, LG-02), and two more alerts were added: guardrail removal and bulk reads of sensitive data. What remains is mostly about where logs go: they stay in the project for 30 days and are not sent anywhere else.

## What was checked (2026-10-14)

| Check | Method | Result |
|---|---|---|
| Data Access audit logging | Project IAM policy, auditConfigs | None configured |
| Log export | Log sinks | Only the built-in _Required and _Default. No export. |
| Retention | _Default log bucket | 30 days |
| Model Armor template logging | Template metadata | Only data residency set at first. Screening and operation logging enabled 2026-10-14; first entry logged at 20:47:43. |
| Application log content | App source code and recent Cloud Run entries | Prompts arrive in a POST body and the app has no logging calls. Prompts are not logged. |
| Alert routing | Live tests on real events (Module 7) | Three alerts, email within 1 to 2 minutes. Five after the same-day fixes. |

## Questions the logs can and cannot answer

| Question | Answerable today? | Why |
|---|---|---|
| Who changed a guardrail, a key, or the ingress setting? | Yes, with an alert | Admin Activity logs, Module 7 alerts |
| Did a change happen even though it reported failure? | Yes | The alert matches on method, not status (F3-03) |
| Who read the customer export or the RAG source documents? | Yes, since 2026-10-14 | Data Access logs on for Cloud Storage. Bulk reads of the raw and quarantine buckets raise an alert (LG-01 resolved). |
| Who called the model, and how often? | Probably, since 2026-10-14 | Vertex AI Data Access logs are on. Not yet confirmed that model calls appear in them. |
| Which prompts did Model Armor block? | Yes, since 2026-10-14 | Floor and template screening logs are on (LG-02 resolved) |
| Did someone try to copy data out of the perimeter? | In the logs, with no alert | VPC-SC violation entries (Module 4) |
| What did a given user ask? | Partly | The Module 8 app logs the caller and the documents used, not the question text (LG-06) |
| What happened 60 days ago? | No | 30-day retention, no export |

## Findings

### LG-01 Data access is not logged (HIGH)
Data Access audit logs are off for Cloud Storage and Vertex AI. Reads of sensitive data and calls to the model leave no record. The bulk-read alert recommended for R-004 cannot be built until these logs are on. Turning them on adds log volume and cost, so scope them to sensitive buckets and AI services first.

**Resolved 2026-10-14.** DATA_READ logs turned on for Cloud Storage and Vertex AI, with a bulk-read alert on the raw and quarantine buckets (module7-ops/terraform/audit.tf). A read 42 seconds after the change was not logged; later reads were. Ten reads raised an email. The threshold was raised to more than 10 entries because each read writes two (F7-11).

### LG-02 Model Armor screening results are not logged (MEDIUM)
The template does not log its screening operations. A blocked attack leaves no guardrail record, so attack trends cannot be measured or alerted on. This may also explain part of F3-02, where no Model Armor logs appeared. That result should be retested with logging on.

**Resolved 2026-10-14.** Template screening and operation logging enabled and read back; a template screening call produced a log entry naming the template. The F3-02 retest found the root cause: the floor was inspect-only.

### LG-03 Logs stay in the project for 30 days (MEDIUM)
No log sink sends data to a SIEM or to longer storage. Investigations older than 30 days are not possible, and AI events cannot be correlated with other security sources.

### LG-04 Guardrail removal from the service is not detected (MEDIUM)
Removing the Model Armor setting from the Cloud Run service turns enforcement off and logs as a routine deploy (F7-05). No detection exists yet.
Update: the Module 8 app refuses to start without the setting, so removal now blocks the deploy.

**Resolved 2026-10-14.** An alert on the app's refusal log line fired on a live test and named the rejected revision. Cloud Run audit logs could not be used, because they do not record environment variables (F7-10).

### LG-05 Attack and exfiltration signals are logged but not alerted (MEDIUM)
VPC-SC violation entries are recorded with no alert. DLP quarantine events and Cloud Armor blocks were not assessed: the Cloud Armor module was removed after testing, and quarantine logging was not checked.

### LG-06 Prompts are not logged, by default rather than by decision (LOW)
The /ask endpoint takes the question in a POST body, and the app has no logging calls, so nothing records what was asked. That avoids storing personal data a user might type, but leaves no record for an abuse investigation. Either choice can be defended. It should be made with privacy, not left as a default.
Update: the Module 8 app logs the caller, entitlements and retrieved document names for each request, without the question text.

### LG-07 Organization-level gaps carry over (MEDIUM)
The AI application project sits outside the organization (F7-07), and organization posture scanning is not detecting (F7-08).

## Recommended backlog

| Priority | Item | Closes | Effort | Needs approval from |
|---|---|---|---|---|
| 1 | Turn on Data Access logs (DATA_READ) for sensitive buckets and Vertex AI | LG-01 | Done 2026-10-14 | Platform owner |
| 2 | Turn on Model Armor screening logs, then retest F3-02 | LG-02 | Done 2026-10-14 | Platform owner |
| 3 | Add a log sink to the SIEM, with retention set by policy | LG-03 | Medium | Security operations |
| 4 | Alert on VPC-SC violations. Bulk-read alert done 2026-10-14. | LG-05, R-004 | Low | Security operations |
| 5 | Build the guardrail-removal detection | LG-04 | Done 2026-10-14 | Security operations |
| 6 | Decide prompt logging and retention with privacy | LG-06 | Low | Privacy, data owner |

**Decision owner:** [Security leadership]
**Status:** Awaiting decision
