# AI Use-Case Risk Assessment

**Prepared by:** Robert Bogan, security architecture
**Intended for:** A large enterprise retailer, referred to as "the Enterprise"

> **This is a pilot built in a personal lab, for a fictitious retailer.** The example column describes the lab application, not any real organization's system.

## Assumptions and caveats

This template was written without access to the Enterprise's environment, policies or people. Confirm or correct these assumptions before first use.

**Profile of the Enterprise**

1. **Size and shape.** Tens of billions in annual revenue, more than 10,000 locations, multiple distribution centers, operations in more than one country, and a retail media business that uses first-party customer data.
2. **How AI arrives.** Google Cloud with Vertex AI is the main platform for AI built in-house. AI also arrives through vendor products, such as planning platforms and in-store systems with AI features. This form covers both. The platform section is written for Google Cloud.
3. **Maturity.** The Enterprise describes itself as early in its AI adoption. General review processes exist: architecture review, privacy review, and a third-party security risk program. An AI-specific intake may be new. This form is meant to feed the existing processes, not replace them.
4. **Data classes.** Customer personal data including loyalty and purchase history, payment card data within PCI DSS scope, employee data, and confidential supplier terms.
5. **Regulation.** PCI DSS and US state privacy laws apply, including rights to opt out of targeted advertising and rules on automated decisions about people. Laws in other countries of operation may also apply. Legal confirms which apply to each use case. Nothing in this form is legal advice.
6. **Cloud structure.** Workloads run in a Google Cloud organization with folders and projects. Some AI projects may predate organization-level controls or sit outside the organization entirely (lab finding F7-07).
7. **Posture and detection tooling.** The Security Command Center tier, any third-party CSPM, and the SIEM are unknown. No detector is assumed active until tested (lab finding F7-08).
8. **Risk scale and framework.** The Enterprise has its own risk matrix and control framework, neither of which is assumed here. Ratings use a simple scale that would map to the Enterprise's.
9. **Board reporting.** Security leadership reports cyber risk to the board on a regular cycle. Outputs in section 10 are written so they can feed that reporting.

**Roles and authority**

10. **Who decides.** The assessor prepares the record and recommends. Risk acceptance, policy exceptions and go-live decisions belong to the Enterprise's named owners.
11. **Tier criteria are proposed.** The rules in section 9 are a starting proposal. The Enterprise's security and risk leadership sets the final criteria.
12. **Role names are placeholders.** Bracketed roles such as [Data owner] stand in for the Enterprise's actual titles.

**Providers and vendors**

13. **Provider and vendor terms.** How a provider or vendor handles prompts, responses and Enterprise data depends on the contract. Legal and third-party risk confirm the terms. This form records the answer and does not assume it.

## How to use this form

The project team completes sections 1 through 7. Security architecture reviews them, applies the tiering rules in section 9, marks which follow-on assessments section 6 triggers, and records the outputs in section 10. Approvals come from the reviewers named in section 11.

## 1. Use case

| Field | What to provide | Example: store operations assistant |
|---|---|---|
| Name and purpose | What the system does, in one sentence | Answers store staff questions about policies, hours and vendor terms |
| Business owner | Accountable person or role | [Store operations lead] |
| Users | Internal staff, customers, partners, public | Internal store staff |
| Role in decisions | Informs a person, or acts or decides on its own | Informs a person |
| Decisions about people | Does output affect a customer or employee outcome, such as pricing, eligibility, scheduling or discipline? | No |
| Target go-live | Date or quarter | Not applicable, lab |

## 2. Model, provider and sourcing

| Field | What to provide | Example |
|---|---|---|
| Built or bought | Built in-house on the Enterprise cloud, a vendor product with AI, or an AI feature added to an existing product. Bought AI also goes to third-party risk review. | Built in-house |
| Model and version | Provider, model, version. For vendor products, what the vendor discloses. | Gemini 2.5 Flash |
| Hosting | Service and region, or vendor hosting location | Vertex AI, us-central1, called from Cloud Run |
| Grounding sources | Where retrieved content comes from | Documents in a Cloud Storage bucket |
| Tools or actions | Anything the model can trigger: APIs, writes, orders, messages, tickets | None |
| Fine-tuning or training | Whether Enterprise data trains or tunes a model, the Enterprise's or the vendor's | None |
| Provider or vendor data terms | Retention, training use and data location under contract, confirmed by legal | Not applicable, lab |

## 3. Data

| Field | What to provide | Example |
|---|---|---|
| Data in prompts and sources | Classes present: customer PII, loyalty or purchase history, employee PII, payment data, confidential business data | Employee PII, payment card data (test numbers), vendor terms |
| Data owner | Accountable person or role for each class | [HR data owner], [Payments data owner] |
| Need for each class | Why the use case needs it. Could it work without it, or with masked values? | Employee PII and card data are not needed. Masked in Module 5. |
| Prompt and response logging | What is stored, where, for how long. Logged prompts that contain PII are a new sensitive data store. | Cloud Logging, default retention |
| Data leaving the country or region | Yes or no, and where. The Enterprise operates in more than one country, so this needs a real answer. | No |

## 4. Privacy and legal

| Field | What to provide | Example |
|---|---|---|
| Notice | Are users or affected people told that AI is involved? | Not applicable, lab |
| Advertising and personalization | Is customer data used for advertising, targeting or personalization? If yes, opt-out rights under state privacy laws apply. | No |
| Automated decisions | Does the system make or materially shape a decision about a person without human review? | No |
| Customer data rights | Can personal data in sources, prompts or logs be found and deleted on request? | Not assessed |
| PCI DSS scope | Does any card data enter the AI system or its logs? | Yes, test numbers in sources. Masked before reaching the model. |

## 5. Exposure

| Field | What to provide | Example |
|---|---|---|
| Reachable from | Internet, corporate network, store network, internal services only | Internet, through a load balancer |
| Authentication | How users prove identity | None in the lab. Required before any real use. |
| Abuse limits | Rate limits, quotas, cost caps | 10 requests per minute per IP at the edge |

## 6. Google Cloud platform and follow-on assessments

For use cases built on the Enterprise cloud. Each answer tells security architecture which deeper assessments the use case needs.

| Field | What to provide | Triggers | Example |
|---|---|---|---|
| Project and organization | Project ID, and whether it sits inside the Enterprise organization | SCC coverage check | Outside any organization (F7-07) |
| Runtime identity | Service account the app runs as, and its roles | AI IAM risk assessment | Dedicated account, two grants after the DF-01 fix |
| Service perimeter | Inside a VPC Service Controls perimeter? | VPC-SC feasibility and dry run | Tested separately (Module 4) |
| Network path | Public URL, load balancer, private access only | Network exposure assessment | Load balancer, ingress restricted (Module 6) |
| Sensitive data handling | Inspection and masking before data reaches the model | DLP discovery | Yes (Module 5) |
| Guardrails | Model Armor or equivalent on prompts and responses | Model Armor testing | Template enforcement (Module 3) |
| Encryption keys | Does stored data need a customer-managed key? | CMEK applicability | Yes, tested (Module 7) |
| Logging and detection | Which audit logs are on, and what alerts exist | Logging gap assessment | Detections built, no alert routing (F7-04) |

## 7. Threats to consider

Mark each as applies, does not apply, or unknown. Unknown counts as applies for tiering.

| OWASP LLM | Threat | Example |
|---|---|---|
| LLM01 | Prompt injection, typed by a user or hidden in a source document | Applies. Tested in Modules 3 and 5. |
| LLM02 | Sensitive data disclosed in responses | Applies. Tested in Modules 1, 3 and 5. |
| LLM03 | Supply chain: vendor models, components or data the Enterprise does not control | Partly. App dependencies are not pinned. |
| LLM04 | Poisoned source documents | Applies. Tested in Modules 2 and 5. |
| LLM05 | Output passed to another system that renders or runs it | Does not apply |
| LLM06 | Model takes actions beyond what was intended | Does not apply. No tools. |
| LLM10 | Runaway usage or cost | Applies. Rate limit tested in Module 6. |

## 8. Planned controls

List the controls from the AI control matrix this use case relies on, and the status of each.

| Example | AC-01, AC-02, AC-04, AC-05, AC-06, AC-08 to AC-11 |
|---|---|

## 9. Risk tier (proposed criteria)

The tier comes from the answers above by rule, not by judgment, so two assessors reach the same result. These criteria are a proposal for the Enterprise's security and risk leadership to set.

| Tier | Rule | Reviews required |
|---|---|---|
| 1 | Internal users only, no sensitive data, no tools or actions, built in-house | Security architecture |
| 2 | Sensitive data present, or external users, or a vendor product processes Enterprise data | Tier 1, plus privacy, the data owner, and third-party risk for vendor products |
| 3 | Sensitive data and external users together, or any tools or actions, or customer data used for advertising or personalization, or decisions about people made without human review | Tier 2, plus legal, the architecture review board, and adversarial testing before go-live |

**Tier 1 is meant to be fast.** With AI being adopted across many locations and functions, low-risk use cases should clear intake in days. A slow path for everything pushes teams to work around the process.

**Example result:** Tier 2. Employee PII and payment data are present. Users are internal. The model takes no actions.

## 10. Outputs

| Output | Entries |
|---|---|
| Risk register entries raised | Example: R-004 (manual export) |
| Exceptions needed | Example: E-002 (open ingress source) |
| Follow-on assessments triggered | From section 6 |
| Open risks for the decision owner | Example: no user authentication, posture scanning not active (F7-08) |

Open risks are written in plain terms so they can roll into the regular cyber risk reporting to leadership and the board.

## 11. Review and approval

| Role | Name | Decision | Date |
|---|---|---|---|
| Security architecture (prepared by) | | Reviewed, not an approval | |
| Privacy | | | |
| Data owner | | | |
| Third-party risk (vendor products) | | | |
| Legal (Tier 3) | | | |
| Architecture review board (Tier 3) | | | |
| Business owner (accepts residual risk) | | | |
