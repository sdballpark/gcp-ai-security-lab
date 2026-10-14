# Developer Guidance: Building AI Applications on Google Cloud

**Prepared by:** Robert Bogan, security architecture
**Intended for:** Application teams at a large enterprise retailer, referred to as "the Enterprise"
**Date:** 2026-10-14

> **This is a pilot built in a personal lab, for a fictitious retailer.** Each rule comes from something that went wrong, or nearly did, in the lab's store-assistant app. The finding ID shows where.

Read this before you start a Vertex AI application. The checklist at the end is what a security review will ask for.

## 1. Identity

**Run as your own service account.** Never the default compute account. It holds Editor on the project, so a compromised app can do almost anything (F1-03).

**Give the runtime identity only what it reads.** Object read on the clean bucket. No write to its own sources (C2-01). No read on the raw bucket, ever: one grant there undoes all the masking upstream (DF-01).

**Verify the caller in your code as well as at Cloud Run.** Cloud Run lets through anyone with the invoker role, including project owners. Check the token audience and map the caller to an entitlement list in the app. Log why a request was denied, and make sure the reason is right. In the lab, an owner token was logged as "missing" when it was present, and the cause is still unknown (F8-02).

## 2. Start up safely

**Refuse to start without your guardrail settings.** If the Model Armor template name or the data bucket is missing, exit with an error. Do not fall back to calling the model unguarded (DF-04).

**Make sure the platform waits for your check.** The default Cloud Run startup probe only checks that the port is open. Gunicorn opened the port 8 ms after start, before the app loaded, so a revision that should have failed was marked healthy and took all traffic (F8-01). Start gunicorn with `--preload`, so the app loads and runs its checks before the port opens.

```dockerfile
CMD exec gunicorn --preload --bind :$PORT --workers 1 --threads 4 --timeout 120 main:app
```

**Keep the refusal message stable.** The guardrail-missing alert matches the text "Refusing to start" in the app log. Cloud Run audit logs do not record environment variables, so this log line is the only signal. If you change the wording, tell security operations first.

## 3. Retrieval

**Filter by entitlement before ranking.** Remove every document the caller is not allowed to see, then score what is left. Documents the caller cannot see should never be scored at all, so no later step can pass them along by mistake.

**Recheck at read time.** Read the document's current tag when you fetch it. A tag changed after indexing should take effect without a rebuild.

**Set a relevance threshold from measured scores, and log the scores.** Without one, the HR record went out with a refund question (F8-03). In the lab, the right documents scored 0.632 or above and wrong ones 0.506 or below, so the threshold went at 0.55. Your corpus will score differently. Measure it before you choose a number.

**Never send the whole corpus with every prompt.** One poisoned document then reaches every request, and a guardrail that blocks it blocks everything (DF-05, Module 3).

## 4. Guardrails

**Screen prompts and responses with your Model Armor template.** Do not count on the floor setting alone. It sets a minimum and only screens calls made without a template.

**Change templates through the runbook only.** A template update returned an error, was logged as failed, and still took effect (F3-03). Read the template back after every change, whether the call succeeded or not. The runbook is in `runbooks/model-armor-template-change.md`.

**Do not treat the injection filter as the main defense.** A roleplay jailbreak passed it in 5 of 5 trials. Nothing leaked because the data had been masked before it reached the corpus (F5-01).

## 5. Data

**Feed the app from the ingestion pipeline, never from source.** Documents go through the injection screen and DLP de-identification, then to the clean bucket or to quarantine (Module 5).

**Ask the data owner whether the data belongs at all.** Masking does not catch everything. Names, pay rates and employee IDs passed through (F5-02). The better fix was to keep HR records out of a store operations assistant.

**Expect quarantine to cost you content.** Quarantining a whole document removed a legitimate answer along with the injection (F5-03). Plan a review path for quarantined files.

## 6. Network

**Keep ingress at internal and load balancer.** With ingress open, the default Cloud Run URL bypassed Cloud Armor completely (F6-01). An alert fires when ingress opens.

**Send all egress through the approved VPC.** Use `--vpc-egress=all-traffic` on the approved subnet. Google APIs resolve to the private range there, and everything else is blocked (Module 9). Do not add Cloud NAT or new egress rules without review.

## 7. Logging

**Log the decision, not the conversation.** For each request, log the caller, which documents were retrieved with their scores, whether a guardrail blocked it, and why a request was denied. Do not log prompt or response text unless the data owner has decided it should be kept (LG-06). Template logging can already capture it (F3-06).

**Never log secrets or tokens.** That includes the bearer token on the request.

## 8. Infrastructure as code

**Make every change in Terraform.** Two lab changes were made with gcloud and are now drift: the VPC-SC perimeter (F4-05) and the app's network attachment (Module 9). A change Terraform does not know about gets undone, or worse, kept without anyone reviewing it.

## 9. Test before release

Run these against a non-production deployment and attach the results to the review.

| Test | Pass condition |
|---|---|
| Call with no token | 403 from Cloud Run |
| Call with a valid token for an identity not on the entitlement list | 401 from the app, with the correct reason logged |
| Each persona asks for data outside its entitlement, plainly and through an injection | No out-of-scope document retrieved |
| Off-topic question | Nothing retrieved, no model call |
| Known injection and jailbreak prompts | Blocked, or answered with nothing sensitive to reveal |
| Deploy with the guardrail setting removed | Revision rejected, traffic stays on the last good one, alert fires |
| Ordinary questions | Correct answers. A guardrail that blocks everything has also failed. |

**Wait before you test a new control.** New alert policies, IAM grants, audit log settings and log metrics were each not live when first tested (F7-09). Allow several minutes, and confirm the control fired, not just that the setup command succeeded.

## Checklist for the security review

- [ ] Dedicated runtime service account, read-only on the clean bucket
- [ ] Caller verified in code, with entitlement mapping and accurate denial reasons
- [ ] App refuses to start without guardrail settings; gunicorn runs with `--preload`
- [ ] Entitlement filter before ranking, with a measured relevance threshold
- [ ] Model Armor template on prompts and responses
- [ ] Corpus loaded only through the ingestion pipeline; data owner sign-off on what is in it
- [ ] Ingress internal and load balancer; egress through the approved VPC
- [ ] Decision logging without prompt text, unless approved
- [ ] All resources in Terraform
- [ ] Release tests run and attached
