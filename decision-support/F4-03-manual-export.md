# Decision Pack: Manual Export Under an Enforced Perimeter

**Source finding:** F4-03 (Module 4, VPC Service Controls)
**Prepared by:** Robert Bogan, security architecture
**Status:** Awaiting risk owner decision

## In plain terms

An employee who is allowed to read the customer export can download it to a laptop and upload it somewhere else. The service perimeter stops copies made between cloud services. It does not stop a person who already has access. This is how the control is designed, not a misconfiguration.

## 1. Risk register entry

| Field | Entry |
|---|---|
| ID | R-004 |
| Title | Authorized reader can export protected data by hand |
| Asset | Customer export bucket (synthetic loyalty data) |
| Threat | Insider misuse, or stolen credentials used from an unmanaged device |
| Evidence | Under enforcement, download to a local machine then upload to an outside project succeeded. Server-side copy was blocked with HTTP 403. |
| Likelihood | Medium. Requires valid read access. |
| Impact | High. Customer personal data exposed. |
| Inherent rating | Medium (F4-03) |
| Related | F4-04, ingress rule allows any source network |
| Risk owner | [Data owner] |
| Status | Open |

## 2. Options analysis

**Option A. Limit where access can come from.** Replace the ingress rule's open source setting with an access level that allows only corporate IP ranges, or managed devices. Device-based levels need Chrome Enterprise Premium licensing.
Effect: stolen credentials fail from outside approved networks. Also closes F4-04.
Limit: does nothing about an insider on a corporate device.

**Option B. Reduce readers and watch reads.** Review who holds read access to the bucket and remove anyone who does not need it. Turn on Data Access audit logs for Cloud Storage, which are off by default, and alert on bulk object reads.
Effect: fewer people can export, and a bulk export becomes visible.
Limit: detection is after the fact. Data Access logs add log storage cost.

**Option C. De-identify the data at rest.** Store a masked copy for most users, using the Module 5 de-identification templates. Limit the raw copy to a small group.
Effect: an export is worth much less.
Limit: breaks any use case that needs the raw values. The data owner must confirm which ones do.

**Option D. Accept the risk.** Document it and rely on existing HR and legal controls.
Effect: no cost or effort.
Limit: the gap stays open, including the stolen-credential path.

**Recommendation:** A and B together. C for any dataset where the data owner confirms raw values are not needed. No option fully removes insider risk, so the remaining exposure goes to the open-risk summary.

## 3. Pros and cons matrix

| Criterion | A. Access level | B. Readers and alerting | C. De-identify | D. Accept |
|---|---|---|---|---|
| Blocks stolen credentials | Yes | No | Partly | No |
| Reduces insider risk | No | Partly | Yes | No |
| Detects export | No | Yes | No | No |
| Effort | Low to medium | Low | Medium to high | None |
| Ongoing cost | License if device-based | Log volume | Pipeline upkeep | None |
| User impact | Remote users need approved network or device | Some lose access | Raw data restricted | None |

## 4. Decision log entry

| Field | Entry |
|---|---|
| ID | D-004 |
| Decision needed | How to treat manual export risk on the customer export bucket |
| Options presented | A, B, C, D (see options analysis) |
| Recommended | A and B, plus C where raw values are not required |
| Decided by | |
| Date | |
| Decision | |
| Rationale | |
| Conditions or follow-up | |

## 5. Exception list entry

| Field | Entry |
|---|---|
| ID | E-002 |
| Control | Perimeter ingress limited to approved access levels |
| Current state | Ingress rule allows any source network (F4-04). Set this way to restore administrator access during rollout. |
| Requested by | Security architecture |
| Approver | [Policy owner] |
| Proposed expiry | 30 days, or when Option A is in place, whichever comes first |
| Compensating control | Ingress limited to one named administrator identity and to the Storage service only |
| Status | Pending approval |

## 6. Open-risk summary

The perimeter now blocks the main exfiltration path: copying protected data to a project outside it. Two gaps remain. The ingress rule accepts any source network, so a stolen administrator credential would work from anywhere. Separately, anyone with read access can download data and move it by hand. The first gap closes with an access level. The second can be reduced but not removed. Least privilege and read alerting shrink it, and de-identification limits what an export contains. A decision on R-004 is pending with the data owner.

## 7. Recommended prioritization backlog

| Priority | Item | Closes | Effort | Needs approval from |
|---|---|---|---|---|
| 1 | Turn on Data Access logs for the bucket and add a bulk-read alert | Detection gap in R-004 | Low | Platform owner |
| 2 | Create a corporate access level and replace the open ingress source | F4-04, part of R-004 | Low to medium | Policy owner |
| 3 | Review and reduce read access on the bucket | Part of R-004 | Low | Data owner |
| 4 | Decide with the data owner which uses need raw values | Input to Option C | Low | Data owner |
| 5 | De-identify at rest where raw values are not needed | Part of R-004 | Medium to high | Data owner, privacy |
| 6 | Move perimeter, access policy and ingress rule into Terraform | F4-05 | Medium | Platform owner |
