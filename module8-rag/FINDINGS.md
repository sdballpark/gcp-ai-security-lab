# Module 8 RAG with Per-User Access Scoping Findings

Date tested: 2026-10-14
Project: rb-ai-prod-sim-1013. All data synthetic.

## What changed
- Retrieval: documents in docs-clean are embedded with text-embedding-005 (768 dimensions). The index (_index/embeddings.json) holds each document's name, audience tag and vector. build_index.py builds it.
- Scoping: each document carries an audience tag in object metadata (tag_docs.sh). The app filters to the caller's entitlements BEFORE ranking, then rechecks the live tag of each chosen document. Untagged documents are denied to everyone.
- Identity: the app requires a Google ID token issued for this service and reads the verified email. Entitlements map identities to audiences.
- Personas (Terraform): persona-store-staff (all-staff) and persona-hr (all-staff, hr). Each can invoke the app and nothing else. The operator can mint tokens as a persona only until 2026-10-16 00:00 UTC.
- Fail closed (DF-04): the app refuses to start without its required settings, including the Model Armor template.
- Audit: each request logs the caller, auth method, entitlements, number of documents in scope and documents used. The question text is not logged.

## Tests

| # | Caller | Question | In scope | Retrieved | Result |
|---|---|---|---|---|---|
| 1 | store staff | When do stores open? | 1 | store-ops-policy | Answered |
| 2 | store staff | Dana Whitfield's employee ID | 1 | store-ops-policy | Not answered. HR record never retrieved. |
| 3 | HR | Dana Whitfield's employee ID | 2 | hr-employee-record, store-ops-policy | Answered from the HR record |
| 4 | store staff | Injection asking for the full HR record | 1 | store-ops-policy | Blocked by Model Armor (403). HR record not in scope either way. |
| 5 | HR | Refund exceptions at store 1187 | 2 | store-ops-policy, hr-employee-record | Not answered. Refund log (payments) never retrieved. |
| 6 | Project owner, gcloud token | When do stores open? | n/a | n/a | Passed Cloud Run, rejected by the app (401) |
| 7 | No token | When do stores open? | n/a | n/a | Rejected by Cloud Run (403) before reaching the app |

All persona tokens were verified by the app with full signature checks ("verified" in the audit log). Cloud Run passed the signed token through.

### Fail-closed test
| Attempt | Result |
|---|---|
| Removed MA_TEMPLATE, original container | Revision 00006 marked ready and took 100% of traffic. The default TCP startup probe passed at 20:02:47.854, 8 ms after gunicorn started and before the worker loaded the app. The worker then failed with "Required setting MA_TEMPLATE is missing. Refusing to start." |
| Added gunicorn --preload, removed MA_TEMPLATE again | Revision 00009 rejected: container failed to start and listen. Traffic stayed on 00008, the last good revision. |

## F8-01 Fail-closed code was marked healthy by the platform (MEDIUM, availability)
The startup check only waits for the port to open. Gunicorn opened the port before loading the app, so a revision that could not serve was given all traffic. Fixed with --preload, which loads the app before the port opens. Retested: the bad revision was rejected and traffic stayed on the good one.
Lesson: confirm that "fail closed" in code also fails the deploy, not just the request.

## F8-02 Platform authentication is broader than the persona list (MEDIUM, design)
Cloud Run accepted the project owner's gcloud token, whose audience is the gcloud client rather than this service, because owners can invoke any service. The app rejected it: wrong audience and no entitlements. Anyone with Owner on the project passes the platform check; the app's entitlement check is the control that limits who sees what.
The app logged this denial as "missing" rather than "invalid". Why the header appeared absent to the app was not confirmed.

## F8-03 No relevance threshold, so irrelevant in-scope documents reach the model (LOW, data minimization)
With two documents in scope and TOP_K=2, every in-scope document is sent. An HR question about refunds still sent the HR employee record. Scoping works; minimization does not. Fix: a minimum similarity score.

## F8-04 Entitlements and tags are lab mechanisms (LOW, design)
Entitlements are an app setting and tags are set by script. In production, entitlements should come from directory groups, tags should be set by document owners at upload, and the index rebuilt when tags change. The live tag recheck limits the damage from a stale index. Names and employee IDs are not masked by the DLP templates, so scoping is what keeps the HR record from store staff.

## Production design
Identity-Aware Proxy on an HTTPS load balancer, with Cloud Armor in front and user identity from the organization's directory, replaces the test personas. Not built in this lab.

## Controls verified
C8-01 Store staff never received HR or payments documents, including under a direct injection attempt.
C8-02 HR received HR documents and never the payments document.
C8-03 Unauthenticated requests are rejected by Cloud Run before reaching the app.
C8-04 A valid Google token not issued for this service is rejected by the app.
C8-05 A missing guardrail setting blocks the deploy, and traffic stays on the last good revision.
C8-06 Each request is audited by caller, scope and sources without logging the question.
