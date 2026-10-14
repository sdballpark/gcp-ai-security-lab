# AI Platform Architecture Risk Review: Store Assistant

**Prepared by:** Robert Bogan, security architecture
**Intended for:** A large enterprise retailer, referred to as "the Enterprise"
**Date:** 2026-10-14

> **This is a pilot built in a personal lab, for a fictitious retailer.** It reviews the lab application, not any real organization's system.

## Scope and method

The subject is the store-assistant application as it stood on 2026-10-14 after Modules 1 to 9. Every risk below comes from a test in this repository, and each one points to the finding that holds the evidence. Where a risk was found and then fixed, it is listed under "Closed" with the retest that proved the fix.

Ratings use the scale from the module findings (HIGH, MEDIUM, LOW). They would map to the Enterprise's own risk matrix, which is not assumed here.

This review recommends. Risk acceptance, exceptions and go-live decisions belong to the Enterprise's named owners. Bracketed roles such as [Platform owner] stand in for their titles.

## Architecture as built

| Layer | What is in place | Evidence |
|---|---|---|
| Users | Two test personas (store staff, HR) call the app with Google ID tokens. Token access expires 2026-10-16. | Module 8 |
| Entry | Cloud Run service, ingress limited to internal and load balancer traffic, authentication required. The load balancer and Cloud Armor policy were torn down after testing; the Terraform is kept. | Modules 6 and 8 |
| Application | Python on gunicorn with --preload. Verifies the token audience, maps the caller to entitlements, filters documents before ranking, drops matches below a relevance score of 0.55, and refuses to start if its guardrail or data settings are missing. | Module 8 |
| Runtime identity | store-assistant-sa: Vertex AI user at project level, object read on the clean bucket only. | Modules 2 and 8, DF-01 |
| Model | Gemini 2.5 Flash on Vertex AI, us-central1. Embeddings from text-embedding-005. | Modules 1 and 8 |
| Guardrails | Model Armor template on prompts and responses. Floor setting in inspect-and-block mode. Template logging on. | Module 3, LG-02 |
| Data | Raw bucket, then an ingestion run (injection screen, DLP de-identification), then a clean bucket or quarantine. | Module 5 |
| Network | Egress for all traffic goes through ai-app-vpc. Google APIs resolve to private.googleapis.com. All other egress is denied. | Module 9 |
| Keys | Customer-managed key tested on a dedicated bucket, with an alert on disable or destroy. | Module 7 |
| Detection | Five email alerts: ingress opened, key disabled or destroyed, guardrail changed, guardrail setting missing, bulk sensitive reads. Data Access logs on for Cloud Storage and Vertex AI. | Module 7 |
| Perimeter | VPC Service Controls tested in dry run and then enforced, on a separate project inside an organization. | Module 4 |

## Trust boundaries

1. Caller to Cloud Run. Cloud Run checks that the token is valid and that the caller holds the invoker role. The app then checks the audience and the entitlement list. These are two separate gates, and F8-02 shows they do not agree.
2. App to model. Every prompt and response passes the Model Armor template. The floor setting is a second check on calls made without a template.
3. Source documents to corpus. Nothing reaches the clean bucket without the injection screen and de-identification.
4. Workload to network. The only reachable destination is the private range for Google APIs.
5. Project to organization. The app project has no parent organization (AR-01). This boundary does not exist yet.

## Open risks

| ID | Rating | Risk | Evidence | Recommendation | Owner |
|---|---|---|---|---|---|
| AR-01 | HIGH | The app project sits outside any organization. Organization policies, the VPC-SC perimeter and organization-level posture scanning do not reach it. | F7-07. The Module 4 perimeter protects a different project. | Move AI projects into the organization under a folder with the AI baseline applied. Put them in a perimeter, dry run first (F4-02). | [Cloud platform owner] |
| AR-02 | HIGH | Posture scanning reports zero findings because the misconfiguration scanner is not available at the current tier. | F7-08, SCC findings report canary | Decide on a posture tool, then prove it with a planted misconfiguration before relying on it. | [Security operations lead] |
| AR-03 | MEDIUM | Inside the VPC, DNS still resolves any public name. Connections are blocked, but lookups are a possible exfiltration channel. Not exploited in testing. | Module 9 egress test | Add a DNS response policy that answers only for approved names. | [Network owner] |
| AR-04 | MEDIUM | The default compute service account holds Editor. Cloud Build still uses it. | F2-01 | Give builds their own service account, then remove Editor (F2-01 option B). | [Platform team] |
| AR-05 | MEDIUM | Project Viewers can read raw, unmasked documents through legacy bucket bindings. | DF-02 | Remove the legacy bindings in Terraform. Grant raw-bucket read to the ingestion identity only. | [Data owner] |
| AR-06 | MEDIUM | Ingestion runs by hand under a person's credentials. | DF-03 | Run ingestion as its own service account on a schedule or trigger. | [Platform team] |
| AR-07 | MEDIUM | Cloud Run accepts any identity with the invoker role, which includes project owners. The app denied the owner, but logged the denial as "missing" rather than "invalid". The cause is not confirmed. | F8-02 | Limit invoker to the user groups that need it. Fix and test the denial reason so the log can be trusted for investigation. | [App owner] |
| AR-08 | MEDIUM | The injection filter passed a roleplay jailbreak in 5 of 5 trials. No data leaked, only because the data was masked first. | F5-01 | Keep masking upstream as the primary control. Test a lower confidence threshold than MEDIUM_AND_ABOVE against harmless traffic before changing it. | [App owner] |
| AR-09 | MEDIUM | Names, pay rates and employee IDs are not masked. HR records sit in a store operations corpus. | F5-02, DLP discovery report | The data owner decides whether HR content belongs in this assistant. If it stays, add custom detectors. | [Data owner] |
| AR-10 | MEDIUM | A Model Armor template update that returned an error and was logged as failed still took effect. Reproduced twice. | F3-03 | Follow the template change runbook: read the template back after every change, success or failure. The guardrail alert already matches on the method rather than the result. | [App owner] |
| AR-11 | MEDIUM | Template logging may copy prompt and response text, including HR content, into Cloud Logging, where logs stay in the project for 30 days. | F3-06, LG-02, LG-03 | Check what the entries hold. Restrict who can read them and set retention before production. | [Security operations lead] |
| AR-12 | MEDIUM | Disabling the customer-managed key makes stored data unreadable to everyone. The same action by mistake is an outage. | F7-06, CMEK applicability model | Separate key administration from data access. Keep the key-state alert. | [Key custodian] |
| AR-13 | MEDIUM | Entitlements and document tags are lab mechanisms: a mapping in the app and object metadata. | F8-04 | Source entitlements from the Enterprise identity provider groups. Assign tags at ingestion under data owner control. | [App owner] |
| AR-14 | LOW | The VPC network attachment on the service was made with gcloud, so Terraform does not know about it. The perimeter in Module 4 has the same problem. | Module 9, F4-05 | Bring both into Terraform. | [Platform team] |
| AR-15 | LOW | Quarantining a whole document also removes its legitimate content. The vendor payment answer was lost. | F5-03 | Screen at passage level for automated ingestion, with human review for anything quarantined. | [App owner] |
| AR-16 | LOW | New controls take time to become live. A new alert, impersonation grant, audit log setting and log metric each failed when tested too soon. | F7-09, Module 7 audit log test | Build a wait and a read-back into every control test. A pass taken seconds after a change proves nothing. | [Security operations lead] |

## Closed during the pilot

| Finding | Problem | Fix | Retest |
|---|---|---|---|
| F1-03 | App ran as the default compute account with Editor. | Dedicated runtime service account. | Write to the source bucket denied. |
| DF-01 | App identity could read the raw, unmasked bucket. | Grant removed in Terraform. | Read denied as the app identity. |
| F6-01 | The default Cloud Run URL bypassed Cloud Armor. | Ingress limited to internal and load balancer traffic. | Direct call returned 404; the load balancer path still worked. Alert fires when ingress is reopened. |
| F3-02 | Floor setting was inspect-only: it flagged an attack and let it through. | Switched to inspect-and-block and read back. | Attack blocked. Harmless prompt answered. |
| LG-02 | Model Armor screening results were not logged. | Template logging on. | Screening call logged with the template name and the match. |
| DF-04, F8-01 | App started without its guardrail settings, and the startup probe marked a broken revision healthy. | Fail-closed check plus --preload. | Bad revision rejected. Traffic stayed on the last good one. |
| F7-05 | Removing the guardrail setting from the service was not detected. | Alert on the app's refusal log line. | Email named the rejected revision. |
| DF-05, F8-03 | Every document went into every prompt, then retrieval sent unrelated documents. | Entitlement filter before ranking, then a 0.55 relevance threshold set from measured scores. | Store staff never retrieved HR documents. An off-topic question retrieved nothing and made no model call. |
| LG-01 | Data access was not logged. | Data Access logs for Cloud Storage and Vertex AI, plus a bulk-read alert. | Ten reads produced an email. Threshold tuned above a normal ingestion run. |
| Module 9 | The workload could reach any internet address. | VPC egress with private Google access and a default deny. | example.com connection blocked. Vertex AI and Cloud Storage reached over the private range. |

## Not reviewed

- Provider handling of prompts and responses. That depends on contract terms, which Legal and third-party risk confirm.
- AI that arrives inside vendor products. The use-case risk assessment template covers intake for those.
- Load, cost and availability under real traffic.
- Model quality beyond the answers checked in testing.

## Recommended order

1. AR-01 and AR-02. Until AI projects sit inside the organization, the controls set there do not apply to them, and the posture scanner would not report on them even if they did.
2. AR-05, AR-09 and AR-11, together. They decide who can see unmasked data, and whether it should be there.
3. AR-04 and AR-06. Both remove standing broad access held by people or default accounts.
4. AR-07 and AR-13 before any production user population.
5. The rest through the normal backlog.
