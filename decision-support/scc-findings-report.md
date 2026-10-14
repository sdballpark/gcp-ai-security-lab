# SCC Findings Report: AI Workloads

**Prepared by:** Robert Bogan, security architecture

> **This is a pilot on a fictitious retailer, built in a personal lab.** It does not describe any real organization's environment.

## Coverage statement

This section comes first. A findings count means nothing until the reader knows what was being scanned.

| Item | State |
|---|---|
| Tier | Security Command Center Standard, organization aristotle.systems, activated 2026-10-13 |
| Data residency, encryption | Not enabled. Google-managed key. |
| Services enabled | Vulnerability Assessment, Compliance Manager |
| AI Protection | Disabled |
| Security Health Analytics | Not listed among available services. API reports DISABLED. Enabling it returns FAILED_PRECONDITION. |
| Premium only | Event Threat Detection, Container, VM and Cloud Run Threat Detection, Web Security Scanner, DSPM, others |
| Projects in scope | Organization projects only: ai-org-perimeter, ai-org-outside-1013 |
| Out of scope | rb-ai-prod-sim-1013, which hosts the AI application. It has no parent organization (F7-07). |

## Findings returned

Zero active findings as of 2026-10-14, 18:00 UTC.

## Detection test

A known misconfiguration was created on purpose to check whether a zero result could be trusted.

| Step | Result |
|---|---|
| Canary created, 16:05 UTC | Firewall rule allowing TCP 22 from 0.0.0.0/0, on an empty network in ai-org-outside-1013 |
| Expected | An open SSH port finding |
| Checked at 18:00 UTC | Not detected |
| Cause | Security Health Analytics not available at this tier as activated |
| Canary deleted, 18:09 UTC | Rule and network removed. Total exposure window 2 hours 4 minutes, no VMs attached. |

## F7-07 AI workloads sit outside the scanned organization (MEDIUM, coverage)
Recorded in Module 7. The project running the AI application has no parent organization, so no organization-level SCC setting reaches it. No tier upgrade fixes this. The project has to move into the organization first.

## F7-08 SCC active, but misconfiguration scanning is not available (HIGH, coverage)
The console shows SCC as active. A firewall rule opening SSH to the internet went undetected for over two hours. The zero-findings result reflected a scanner that was not running, not a clean environment.

## Options

**A. Upgrade to Premium.** Adds Security Health Analytics and the threat detection services. Usage-based pricing, or a fixed subscription.

**B. Stay on Standard and cover the gap with other controls.** Preventive organization policies where a constraint exists, plus log-based detections for specific risky changes such as a firewall rule opened to the internet (the Module 7 pattern).

**C. Third-party CSPM** such as Wiz, Orca or Sysdig.

## Recommendation

1. Move AI projects into the organization first. Without that, none of the options sees them.
2. For a production AI platform, choose A or C. B covers only the changes someone thought to write a detection for.
3. Whatever tool is chosen, run a canary for each detector class before reporting zero findings, and repeat it after any tier or configuration change.
4. Follow-up: evaluate AI Protection once the AI projects are inside the organization.

**Decision owner:** [Security leadership]
**Status:** Awaiting decision
