# AI Logging Gap Assessment

**Prepared by:** Robert Bogan, security architecture

> **This is a pilot on a fictitious retailer, built in a personal lab.** It does not describe any real organization's environment.

## Summary

Configuration changes are logged, and the three most damaging ones now raise an email alert within about two minutes. Data access is not logged at all, so nobody can say who read the RAG source documents or who called the model. Model Armor screening results are not logged either, so a blocked attack leaves no guardrail record. Logs stay in the project for 30 days and are not sent anywhere else.

## What was checked (2026-10-14)

| Check | Method | Result |
|---|---|---|
| Data Access audit logging | Project IAM policy, auditConfigs | None configured |
| Log export | Log sinks | Only the built-in _Required and _Default. No export. |
| Retention | _Default log bucket | 30 days |
| Model Armor template logging | Template metadata | Only data residency set. Screening and template operation logging not enabled. |
| Application log content | App source code and recent Cloud Run entries | Prompts arrive in a POST body and the app has no logging calls. Prompts are not logged. |
| Alert routing | Live tests on real events (Module 7) | Three alerts, email within 1 to 2 minutes |

## Questions the logs can and cannot answer

| Question | Answerable today? | Why |
|---|---|---|
| Who changed a guardrail, a key, or the ingress setting? | Yes, with an alert | Admin Activity logs, Module 7 alerts |
| Did a change happen even though it reported failure? | Yes | The alert matches on method, not status (F3-03) |
| Who read the customer export or the RAG source documents? | No | Data Access logs are off |
| Who called the model, and how often? | No | Vertex AI Data Access logs are off |
| Which prompts did Model Armor block? | No | The template does not log screening results |
| Did someone try to copy data out of the perimeter? | In the logs, with no alert | VPC-SC violation entries (Module 4) |
| What did a given user ask? | No | Prompts are not logged, and the app has no user login |
| What happened 60 days ago? | No | 30-day retention, no export |

## Findings

### LG-01 Data access is not logged (HIGH)
Data Access audit logs are off for Cloud Storage and Vertex AI. Reads of sensitive data and calls to the model leave no record. The bulk-read alert recommended for R-004 cannot be built until these logs are on. Turning them on adds log volume and cost, so scope them to sensitive buckets and AI services first.

### LG-02 Model Armor screening results are not logged (MEDIUM)
The template does not log its screening operations. A blocked attack leaves no guardrail record, so attack trends cannot be measured or alerted on. This may also explain part of F3-02, where no Model Armor logs appeared. That result should be retested with logging on.

### LG-03 Logs stay in the project for 30 days (MEDIUM)
No log sink sends data to a SIEM or to longer storage. Investigations older than 30 days are not possible, and AI events cannot be correlated with other security sources.

### LG-04 Guardrail removal from the service is not detected (MEDIUM)
Removing the Model Armor setting from the Cloud Run service turns enforcement off and logs as a routine deploy (F7-05). No detection exists yet.

### LG-05 Attack and exfiltration signals are logged but not alerted (MEDIUM)
VPC-SC violation entries are recorded with no alert. DLP quarantine events and Cloud Armor blocks were not assessed: the Cloud Armor module was removed after testing, and quarantine logging was not checked.

### LG-06 Prompts are not logged, by default rather than by decision (LOW)
The /ask endpoint takes the question in a POST body, and the app has no logging calls, so nothing records what was asked. That avoids storing personal data a user might type, but leaves no record for an abuse investigation. Either choice can be defended. It should be made with privacy, not left as a default.

### LG-07 Organization-level gaps carry over (MEDIUM)
The AI application project sits outside the organization (F7-07), and organization posture scanning is not detecting (F7-08).

## Recommended backlog

| Priority | Item | Closes | Effort | Needs approval from |
|---|---|---|---|---|
| 1 | Turn on Data Access logs (DATA_READ) for sensitive buckets and Vertex AI | LG-01 | Low, plus log cost | Platform owner |
| 2 | Turn on Model Armor screening logs, then retest F3-02 | LG-02 | Low | Platform owner |
| 3 | Add a log sink to the SIEM, with retention set by policy | LG-03 | Medium | Security operations |
| 4 | Alert on VPC-SC violations and on bulk reads | LG-05, R-004 | Low | Security operations |
| 5 | Build the guardrail-removal detection | LG-04 | Low | Security operations |
| 6 | Decide prompt logging and retention with privacy | LG-06 | Low | Privacy, data owner |

**Decision owner:** [Security leadership]
**Status:** Awaiting decision
