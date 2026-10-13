# Module 4 VPC Service Controls Findings

Date tested: 2026-10-13
Organization: aristotle.systems (896039580817), Cloud Identity Free. Access policy 450720476584.
Perimeter sensitive_perimeter protects project ai-org-perimeter. Restricted services: storage.googleapis.com, aiplatform.googleapis.com.
Outside project ai-org-outside-1013 acts as the exfiltration destination.
Test data: synthetic customer export in gs://ai-org-perimeter-1013-sensitive.

## Baseline (no perimeter)
Server-side copy from the sensitive bucket to the outside project succeeded. IAM permitted it because the identity could read the source and write the destination.

## Dry-run phase
Perimeter created in dry-run. The same copy still succeeded and produced three would-deny records:
| Method | Violation reason | Meaning |
|---|---|---|
| storage.objects.create | RESOURCES_NOT_IN_SAME_SERVICE_PERIMETER | The exfiltration copy |
| storage.objects.get (x2) | NO_MATCHING_ACCESS_LEVEL | The administrator's own read from the internet |
Enforcing at that point would have blocked the exfiltration and locked out the administrator.

Remediation in dry-run: ingress rule allowing user:admin@aristotle.systems to storage.googleapis.com only.
Retest in dry-run: read produced no violation; the exfiltration copy still logged RESOURCES_NOT_IN_SAME_SERVICE_PERIMETER.

## Enforced phase
| Test | Result |
|---|---|
| Legitimate read by admin | Allowed |
| Server-side copy to outside project | Blocked, HTTP 403, prohibited by organization's policy, with a VPC-SC unique identifier |
| Download to local machine, then upload to outside project | Succeeded |

## F4-01 Without a perimeter, IAM does not prevent cross-project exfiltration (HIGH)
Any identity with read on the source and write anywhere else can move data out. Remediated for service-to-service movement by the enforced perimeter.

## F4-02 Enforcing without dry-run would have caused an access outage (MEDIUM, rollout)
The dry-run showed legitimate administrator access would be denied (NO_MATCHING_ACCESS_LEVEL).
Recommendation: always run a perimeter in dry-run, review violation logs, add scoped ingress and egress rules, then enforce.

## F4-03 Perimeter does not stop an authorized reader exporting by hand (MEDIUM, residual)
Downloading to a local machine and uploading elsewhere succeeded under enforcement.
VPC-SC limits service-level movement and use of credentials from outside approved contexts. It does not govern what an authorized user does with data they can read.
### Options
A. Replace the ingress rule's accessLevel "*" with an access level limited to corporate IP ranges or managed devices, so stolen credentials fail from outside those contexts.
B. Reduce who can read the bucket, and alert on bulk reads.
C. Keep sensitive data de-identified at rest (Module 5 pattern) so an export has less value.
### Recommendation
A and B together. C where the use case allows.

## F4-04 Ingress rule allows any source network (MEDIUM)
sources accessLevel "*" was used to unblock the administrator in this lab. In production it should reference a real access level.

## F4-05 Perimeter configured with gcloud, not Terraform (LOW, IaC gap)
Terraform in this lab authenticates as a different identity via Application Default Credentials. Perimeter, access policy, and ingress rule should be moved into Terraform with a dedicated deployment identity.

## Controls verified
C4-01 Dry-run identifies would-be denials before enforcement, including legitimate access.
C4-02 Enforced perimeter blocks cross-perimeter service copies of protected data.
C4-03 Scoped ingress rule preserves approved access under enforcement.
