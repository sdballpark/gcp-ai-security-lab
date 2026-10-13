# Module 6 Network Exposure and Cloud Armor Findings

Date tested: 2026-10-13
Path: client -> external Application Load Balancer (EXTERNAL_MANAGED, HTTP) -> Cloud Armor -> serverless NEG -> Cloud Run -> Model Armor -> Gemini
Cloud Armor policy store-assistant-armor: SQLi and XSS preconfigured WAF, per-IP rate limit 10 per 60s, US-only geo rule, default allow. All in Terraform.

## Results
| Test | Path | Result | Stopped by |
|---|---|---|---|
| Benign question | Load balancer | 200, correct answer | Not blocked |
| SQL injection string | Load balancer | 403 HTML page | Cloud Armor at edge |
| DAN jailbreak | Load balancer | 200, masked label only | Nothing upstream; contained by DLP masking |
| 15 rapid requests | Load balancer | 10 x 200, then 5 x 429 | Cloud Armor rate limit |
| SQL injection string | Direct run.app URL | 200, reached the model | Nothing (bypass) |
| Benign question, after fix | Direct run.app URL | 404 | Cloud Run ingress restriction |
| Benign question, after fix | Load balancer | 200, correct answer | Not blocked |

## F6-01 Origin bypass of all edge controls (HIGH, remediated)
Cloud Run accepted traffic on its run.app URL, skipping the WAF, rate limit, and geo rule.
A SQL injection string blocked at the edge reached the model directly.
Remediation: Cloud Run ingress set to internal-and-cloud-load-balancing. Direct calls now return 404 with a valid token; load balancer path verified working.

## F6-02 WAF does not detect natural-language prompt injection (INFO, by design)
The DAN jailbreak passed Cloud Armor. Preconfigured WAF rules target web attack syntax, not plain English instructions.
Cloud Armor and Model Armor cover different layers. Neither substitutes for the other.

## F6-03 Load balancer serves HTTP only (MEDIUM, lab scope)
No TLS on the frontend. Identity tokens and prompts cross the internet in clear text between client and edge.
Production pattern: HTTPS frontend with a Google-managed certificate and an HTTP-to-HTTPS redirect.

## F6-04 Ingress restriction applied outside Terraform (LOW, configuration drift)
The ingress fix was applied with gcloud. A later deploy that resets ingress would silently reopen F6-01.
Recommendation: manage the Cloud Run service and its ingress setting in Terraform, and alert on ingress changes.

## Controls verified
C6-01 Edge WAF blocks SQL injection before Cloud Run, with no model cost incurred.
C6-02 Per-IP rate limit holds at the configured threshold (10 allowed, then 429).
C6-03 Origin reachable only through the load balancer.

## Not tested
Geo rule: all traffic originated in the US. Validating it requires a non-US source.
Rate limit precision under distributed load: single-client test only.
