# AI Control Matrix

**Scope:** Store operations RAG assistant on Cloud Run, using Gemini 2.5 Flash on Vertex AI and documents in Cloud Storage.
**Prepared by:** Robert Bogan, security architecture

> **This is a pilot on a fictitious retailer, built in a personal lab.** It does not describe any real organization's environment. All data is synthetic. The Dev and Prod columns show how the matrix would be completed in a real engagement, where each control is assessed in each environment before go-live.

## Summary

The matrix lists 16 controls. In the lab, 9 are tested and working. 5 work but have open gaps. 1 showed as active in the console but did nothing when tested. 1 is identified but not built. Open items feed the risk register and backlog in the decision packs.

## Controls

| ID | Control | OWASP LLM | Service | Lab evidence | Lab | Dev | Prod | Open item |
|---|---|---|---|---|---|---|---|---|
| AC-01 | Dedicated least-privilege identity for the AI app | LLM04 | IAM | Module 2. Dedicated account replaced default Editor. Write-denial test passed. | Verified, gap open | Not assessed | Not assessed | DF-01 the account still holds read on the raw, unmasked bucket. Three grants, not two. |
| AC-02 | Prompt and response screening by template | LLM01, LLM02 | Model Armor | Module 3. Attack leaks fell from 17 of 20 to 0 of 20. | Verified, gap open | Not assessed | Not assessed | F5-01 direct jailbreak attempts passed the filter. AC-04 prevented the leak. |
| AC-03 | Org-wide guardrail baseline through floor settings | LLM01 | Model Armor | Module 3, F3-02 revised. No effect on traffic. Blocked changes to a non-conformant template until it was brought into line. | Partly working | Not assessed | Not assessed | Existing non-conformant templates are not flagged. F3-03 a rejected update still changed the template. |
| AC-04 | PII masking before documents reach the model | LLM02 | Sensitive Data Protection | Module 5, C5-01. A direct PII request returned type labels only. 0 of 30 leaks overall. | Verified | Not assessed | Not assessed | |
| AC-05 | Quarantine of documents carrying prompt injection | LLM01, LLM04 | Sensitive Data Protection, ingestion pipeline | Module 5. The poisoned vendor file was quarantined and its instruction no longer reached the model. | Verified, gap open | Not assessed | Not assessed | F5-03 whole-file quarantine also removed the payment schedule, so the vendor question was answered wrong. Recommended: chunk-level quarantine with human review. |
| AC-06 | Service perimeter on Storage and Vertex AI | LLM02 | VPC Service Controls | Module 4. Cross-project copy blocked, HTTP 403. | Verified, gap open | Not assessed | Not assessed | F4-03 manual export, F4-04 open ingress source |
| AC-07 | Dry run before perimeter enforcement | | VPC Service Controls | Module 4. Dry run caught an administrator lockout. | Verified | Not assessed | Not assessed | |
| AC-08 | Web attack filtering at the edge | | Cloud Armor | Module 6. SQL injection blocked at the load balancer. | Verified | Not assessed | Not assessed | |
| AC-09 | Per-client rate limit | LLM10 | Cloud Armor | Module 6. 10 requests per minute per IP, then HTTP 429. | Verified | Not assessed | Not assessed | Limit is per IP, not per user or token |
| AC-10 | App reachable only through the load balancer | | Cloud Run ingress | Module 6. Default URL bypassed the edge until ingress was restricted. | Verified | Not assessed | Not assessed | |
| AC-11 | Customer-managed key on RAG source data | | Cloud KMS | Module 7. Disabling the key made data unreadable. Re-enabling restored it. | Verified | Not assessed | Not assessed | F7-06 key disable is also an outage lever |
| AC-12 | Detection: ingress opened on Cloud Run | | Cloud Logging, Monitoring alert | Module 7. Backtest matched 6 open deploys. Live test: email about 1 minute after ingress opened, none for the restore. | Verified | Not assessed | Not assessed | |
| AC-13 | Detection: guardrail template or floor setting changed | LLM01 | Cloud Logging, Monitoring alert | Module 7. Live test: alert fired on a template update the audit log recorded as failed (F3-03). | Verified | Not assessed | Not assessed | |
| AC-14 | Detection: KMS key disabled or destroyed | | Cloud Logging, Monitoring alert | Module 7. Live test: email 2 minutes after disable, none for the re-enable. | Verified | Not assessed | Not assessed | |
| AC-15 | Posture monitoring | | Security Command Center Standard | Module 7, SCC findings report. An open SSH rule went undetected for over 2 hours. | Not detecting | Not assessed | Not assessed | F7-08 misconfiguration scanner not available at this tier. F7-07 app project sits outside the organization. |
| AC-16 | Detection: guardrail removed from the service config | LLM01 | Cloud Logging | Module 7, F7-05 | Not built | Not assessed | Not assessed | Removing the env var disables Model Armor and logs as a routine deploy |

## OWASP LLM Top 10 categories with no control

| ID | Category | Reason |
|---|---|---|
| LLM03 | Supply Chain | Terraform providers are locked. App Python dependencies are not pinned. |
| LLM05 | Improper Output Handling | Nothing downstream renders or runs the output. |
| LLM06 | Excessive Agency | The app has no tools or actions. |
| LLM07 | System Prompt Leakage | Attempted, not measured on its own. |
| LLM08 | Vector and Embedding Weaknesses | No vector store in this design. |
| LLM09 | Misinformation | Not tested. |

## NIST AI RMF alignment

| Function | Lab coverage |
|---|---|
| Map | Use case and data defined. Risks planted on purpose: PII in documents and an injected vendor file. |
| Measure | Attack harness run against every configuration. Detections backtested against real audit events. |
| Manage | Controls AC-01 to AC-16. Decision pack for F4-03 with options and a backlog. |
| Govern | Not covered. See the note below. |

**Mapping depth.** This pilot maps to the four AI RMF functions. A full engagement would map each control to AI RMF subcategories and to the NIST Generative AI Profile (NIST AI 600-1). It would also cross-reference the organization's existing control framework, such as NIST SP 800-53, so AI controls are tested and audited alongside existing ones. Which framework, version and profile to use is agreed with the organization before mapping starts.

**Why Govern is marked "not covered."** Governance is about who decides: who owns each risk, who approves exceptions, and which policies apply. Those decisions belong to the organization's own leadership, not to a lab or an outside assessor. This matrix gives decision-makers what they need. The decisions stay with them.

## Environment note

The Module 6 load balancer and Cloud Armor policy were removed after testing to stop charges. The Terraform stays in the repo, so the controls can be rebuilt and retested.
