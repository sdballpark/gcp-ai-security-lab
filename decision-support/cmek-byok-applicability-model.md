# CMEK and BYOK Applicability Model for AI Workloads

**Prepared by:** Robert Bogan, security architecture

> **This is a pilot on a fictitious retailer, built in a personal lab.** It does not describe any real organization's environment.

## Summary

Customer-managed keys give the organization a lever it can pull: disable the key and the data becomes unreadable to everyone, the provider included. The lab proved that lever works and also that it is an outage switch. This model proposes where each key option fits in an AI workload. The rules are proposals; the organization's security and risk leadership sets the final policy.

## Key options

| Option | Who holds the key | When it fits | Tested in the lab |
|---|---|---|---|
| Google-managed (default) | Google | Configuration and low-sensitivity data | Yes, default on most resources |
| CMEK with Cloud KMS | Organization controls the key in Cloud KMS | Personal or regulated data at rest, or a need to revoke access or destroy data by destroying the key | Yes (Module 7) |
| CMEK with Cloud HSM | Same, with keys in hardware security modules | A regulation or contract requires hardware-protected keys | No |
| BYOK, imported key material | Key generated outside Google and imported into Cloud KMS | Policy requires the organization to generate key material itself | No |
| External key management (Cloud EKM) | Key stays in an external key manager | Policy forbids the provider holding the key at all | No |

## AI workload components

| Component | Stores data? | Applicability | Lab status |
|---|---|---|---|
| RAG source buckets: raw, clean, quarantine | Yes, including personal data in raw and quarantine | CMEK applies | CMEK tested on a separate bucket. Not applied to these (DF-06). |
| Model inference (Vertex AI, Gemini) | Request processing | A data retention and provider-terms question more than a CMEK question. Confirm retention terms with legal. | Not assessed |
| Vector stores and search indexes | Yes, persisted content | CMEK applies where supported. Confirm per service. | No vector store in this design |
| Log buckets | Yes, and may hold prompts or personal data | Cloud Logging supports CMEK on log buckets | Not configured. _Default bucket uses Google-managed encryption. |
| Security Command Center findings | Yes | CMEK can only be chosen at activation | Google-managed chosen at activation (Module 7) |
| Model Armor and DLP templates | Configuration only | Google-managed is reasonable | Not assessed |

## Proposed decision rules

1. Default to Google-managed encryption for configuration and low-sensitivity data.
2. Require CMEK with Cloud KMS for personal or regulated data stored by an AI workload: source documents, quarantine stores, persisted indexes, and any log bucket that holds prompts.
3. Use Cloud HSM, imported keys, or external key management only where a regulation, contract or policy requires it. Each adds cost and operating effort, and external key management adds a dependency: if the external manager is unreachable, the data is unreadable.
4. Decide the key before creating the resource. Some services accept CMEK only at creation or activation (SCC is one). For Cloud Storage, changing a bucket's default key affects new objects; existing objects keep their current encryption until rewritten.
5. Confirm CMEK support for each service against Google's current list before claiming coverage.

## Operating requirements for any customer-managed key

| Requirement | Why | Lab evidence |
|---|---|---|
| Alert on key disable and destroy | Disabling a key stops every dependent workload (F7-06) | Alert tested live, email in about 2 minutes, none on re-enable (AC-14) |
| Separate key administrators from data users | One person should not be able to both read the data and switch it off | Not implemented. One administrator in the lab. |
| Limit key use to the service that needs it | Only the storage service agent should encrypt and decrypt | Only the Cloud Storage service agent holds the key role (Module 7) |
| Rotate on a schedule | Limits exposure of any one key version | 90-day rotation set (Module 7) |
| Treat destruction as permanent | A destroyed key cannot be recovered once the scheduled period ends | Documented, not exercised |
| Test revocation outside production | Proves the lever works before it is needed | Disable made data unreadable (HTTP 400 KEY_DISABLED); re-enable restored it |

## Findings

### CK-01 RAG data is not under a customer-managed key (LOW, lab design)
The buckets the pipeline and app use rely on Google-managed encryption. CMEK was proven on a separate test bucket (DF-06).

### CK-02 Some encryption choices are fixed at creation (MEDIUM, design)
SCC findings encryption could only be chosen at activation. A key decision made late can mean recreating the resource. The key choice belongs in the intake review, before build.

### CK-03 No separation between key administration and data access (MEDIUM)
In the lab one administrator can read the data and disable the key. Disabling the key is now alerted (AC-14), which reduces but does not remove the risk.

## Not tested
Cloud HSM, imported key material, external key management, CMEK on log buckets, and CMEK on vector stores.

**Decision owner:** [Security leadership]
**Status:** Proposed, awaiting decision
