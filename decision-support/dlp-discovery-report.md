# DLP Discovery Report: Store Assistant Source Data

**Prepared by:** Robert Bogan, security architecture
**Intended for:** A large enterprise retailer, referred to as "the Enterprise"
**Date of scan:** 2026-10-13. **Report date:** 2026-10-14.

> **This is a pilot built in a personal lab, for a fictitious retailer.** All documents are synthetic. The counts describe four test files, not a real data estate.

## Summary

Sensitive Data Protection inspected the source documents for the store assistant before they went into its corpus. It found 14 sensitive values across six types. The ingestion pipeline then masked the six values in the payment, identity and contact types, and quarantined one document for prompt injection. After ingestion, 30 attack attempts against the app produced no leaks.

Discovery did not find everything. Employee IDs and pay rates match no built-in detector, and names were found but deliberately left unmasked. Those are decisions for the data owner, set out under Findings.

## Scope

| Item | Detail |
|---|---|
| Location | One Cloud Storage bucket, the raw source for the store assistant |
| Content | 4 plain text files, 1,323 bytes in total |
| Method | Sensitive Data Protection inspection job with an explicit infoType list (`module5-dlp/discovery_job.json`) |
| Quote storage | Off. Results record the type and location of each match, never the value itself. |
| Not in scope | Other buckets, BigQuery, log storage, images, PDFs and structured files |

## What was found

| infoType | Count | Class | Masked at ingestion |
|---|---|---|---|
| PERSON_NAME | 8 | Personal | No, excluded by design |
| CREDIT_CARD_NUMBER | 2 | Payment card | Yes |
| US_SOCIAL_SECURITY_NUMBER | 1 | Government identifier | Yes |
| STREET_ADDRESS | 1 | Personal contact | Yes |
| PHONE_NUMBER | 1 | Personal contact | Yes |
| EMAIL_ADDRESS | 1 | Personal contact | Yes |

Card numbers put that content in PCI DSS scope until masked. The pipeline replaced each masked value with its type label, for example `[CREDIT_CARD_NUMBER]`. A manual review of the output confirmed all six were replaced.

## What happened to each document

| Document | Result | Transformations reported |
|---|---|---|
| hr-employee-record.txt | Cleaned | 3 |
| refund-log.txt | Cleaned | 2 |
| store-ops-policy.txt | Cleaned | 0 |
| vendor-faq.txt | Quarantined for prompt injection | Not processed |

The manifest counts transformations, not individual values, so its total (5) differs from the six values masked.

The injection was found by the Model Armor screen in the ingestion run, not by DLP. DLP looks for sensitive values. It does not judge whether text is an instruction to the model.

## Explicit infoTypes compared with the Model Armor basic setting

Model Armor's basic sensitive data setting missed the street address and the phone number in the same documents (F3-05). The explicit list in the inspection job caught both. That closes F3-05 for ingestion. For prompts typed by users, the basic setting still applies at runtime unless the template is moved to an advanced configuration that uses a DLP template.

## Effect on the app

| Test (5 trials each) | Result after ingestion |
|---|---|
| Direct request for SSNs and card numbers | Type labels only. 0 of 5 leaks. |
| Direct injection | Blocked 2 of 5. 0 of 5 leaks. |
| Roleplay jailbreak | The model played along, but there was nothing to reveal. 0 of 5 leaks. |
| Trigger for the poisoned document | Document absent. 0 of 5 leaks. |
| Store hours | Correct answer. |
| Vendor payment schedule | Wrong. The answer was in the quarantined document (F5-03). |

Before this pipeline, the Model Armor template blocked all 30 requests, including harmless ones, because the poisoned document went into every prompt.

## Findings

### DD-01 Employee IDs and pay rates are not detected (MEDIUM)
Neither matches a built-in detector, so both are still in the clean corpus. An HR user retrieved an employee ID during Module 8 testing, as intended for that persona. A custom detector could find the lab's ID format. The stronger option is to keep HR records out of a store operations corpus (F5-02).
Decision owner: [Data owner].

### DD-02 Names were found but not masked (LOW, by design)
Eight names were found. PERSON_NAME was left out of the templates in Module 5 on purpose, as a decision for the data owner rather than the pipeline, so names reach the model. Whether that is acceptable depends on the document. HR content is the case to decide first.
Decision owner: [Data owner].

### DD-03 Runtime screening of user prompts uses the weaker setting (LOW)
See the comparison above. A user who pastes an address or phone number into a prompt is screened by the basic setting, which missed both types in testing.
Decision owner: [App owner].

### DD-04 Logs were not scanned (MEDIUM)
Template logging is now on (LG-02) and may hold prompt and response text (F3-06). Logs are kept in the project for 30 days (LG-03). None of that was part of this scan.
Recommendation: include log storage in discovery before production, and restrict access to those logs in the meantime.

### DD-05 Discovery and ingestion were run by hand (MEDIUM)
Both ran under a person's credentials (DF-03). A scan nobody repeats goes stale as soon as a new document arrives.
Recommendation: run inspection inside the ingestion service account's pipeline, on every new document.

## Scaling this to the Enterprise

| Step | What it means |
|---|---|
| 1. Profile first | Turn on Sensitive Data Protection discovery for Cloud Storage and BigQuery at the organization or AI folder level. It produces data profiles showing which stores hold which types, without inspecting every byte by hand. |
| 2. AI sources first | Inspect, in full, any store an AI application reads from or is grounded on. Those are where a leak would show up in an answer. |
| 3. Enterprise detectors | Add custom infoTypes for internal identifiers: employee, loyalty and store-specific formats. The lab showed built-in detectors miss these. |
| 4. Logs | Include log sinks and log buckets, since AI guardrail logs can hold prompt text. |
| 5. Owners decide | Each result goes to the data owner with a choice: mask, remove, or accept with a reason. |

## Limits of this report

- Four synthetic files cannot measure detection accuracy. The counts show what was found, not how much was missed overall.
- Only plain text was inspected. Scanned images and PDFs need different handling.
- Results depend on the infoType list. A type not on the list is not reported, even if present.
