# Module 2 IAM Findings

Date tested: 2026-10-13
Target: store-assistant on Cloud Run, project rb-ai-prod-sim-1013

## Remediation of F1-03
Created store-assistant-sa with two grants:
- roles/storage.objectViewer on the docs bucket only (not project level)
- roles/aiplatform.user at project level (Vertex AI offers no narrower scope for model calls)
Cloud Run revision store-assistant-00002 runs as store-assistant-sa. App answers correctly.

## Controls verified
C2-01 App identity cannot write to its RAG source.
Test: impersonated store-assistant-sa, attempted upload to the docs bucket.
Result: denied, storage.objects.create. A compromised app cannot poison its own retrieval data.
Impersonation grant (roles/iam.serviceAccountTokenCreator) removed after the test.

## F2-01 Default compute service account retains Editor (MEDIUM, residual)
4408388195-compute@developer.gserviceaccount.com still holds roles/editor.
The runtime no longer uses it, but Cloud Build does: source deploys build as this account.
Removing Editor now breaks the deploy pipeline.

### Options
A. Accept for now. No change; risk stays with the build path.
B. Create a dedicated build service account with only the roles a build needs, deploy with it, then remove Editor from the default account.
C. Build the image outside GCP and deploy a prebuilt image, so no in-project build identity is needed.

### Recommendation
B. It removes the broad grant without changing the developer workflow.
Decision owner: platform team. Not a contractor decision.

## Notes
F1-01 (PII exposure through retrieval) is unchanged by IAM work. Least privilege limits what a compromised app can do; it does not limit what a legitimate user can ask for.
Impersonation required the IAM Credentials API and took about 3 minutes to propagate after the grant.
