# AI IAM Model for the Organization

**Prepared by:** Robert Bogan, security architecture
**Intended for:** A large enterprise retailer, referred to as "the Enterprise"
**Date:** 2026-10-14

> **This is a pilot built in a personal lab, for a fictitious retailer.** The model scales up what was tested on one application. It is a proposal, not a description of any real organization's access.

## Assumptions

1. The Enterprise runs Google Cloud under one organization with folders, and workforce identities come from a corporate identity provider as Google groups.
2. Terraform applies changes through a deployment identity, not a person's account.
3. Role names below are Google predefined roles. The Enterprise may have custom roles that replace some of them; map them before adoption.
4. Group names in brackets are placeholders.

## What the lab showed at one-application scale

| Lesson | Evidence |
|---|---|
| An app that runs as the default compute account inherits Editor on the whole project. | F1-03 |
| Removing Editor from the default account broke builds, because Cloud Build still used it. | F2-01 |
| A runtime identity with read on the raw bucket can bypass de-identification entirely. | DF-01 |
| Legacy bucket bindings give project Viewers read on every object. | DF-02 |
| Cloud Run invoker and the app's own entitlement list are separate gates, and project owners pass the first one. | F8-02 |
| Time-limited grants with IAM conditions worked for test personas and the impersonation grant. | Module 8 |
| A new grant took between 90 seconds and 3 minutes to work. | Modules 2 and 8 |

## Principles

1. People get access through groups. No individual user appears in a policy outside break-glass.
2. Each AI application runs as its own service account. The default compute account runs nothing.
3. No service account keys. Workloads use their attached identity; people use impersonation.
4. The identity that deploys an app is not the identity the app runs as, and neither one is a person.
5. Grants go on the narrowest resource that supports them: a bucket, a key, a service. Project level only where the service offers nothing narrower.
6. Access to change guardrails is held apart from access to read the data those guardrails protect.
7. Elevated human access is requested, time-limited by an IAM condition, and expires on its own.
8. Basic roles (Owner, Editor, Viewer) are not granted on AI projects.

## Resource layout

```
Organization
└── AI folder                    floor setting, organization policies
    ├── ai-shared
    │   ├── ai-security-logs     log sinks, Data Access logs, alerting
    │   └── ai-keys              KMS keys for AI data
    ├── ai-nonprod
    │   └── <app>-dev projects
    └── ai-prod
        └── <app>-prod projects
```

Keys and logs live outside the application projects, so an application owner cannot disable the key or delete the logs that record their own actions.

## Human roles

| Group | Scope | Roles | Can do | Cannot do |
|---|---|---|---|---|
| [ai-platform-admins] | AI folder | roles/modelarmor.floorSettingsAdmin, roles/resourcemanager.folderIamAdmin, roles/resourcemanager.projectCreator | Set the guardrail baseline for every AI project. Create projects. | Read application data. |
| [ai-app-<name>-developers] | App dev project | roles/run.developer, roles/aiplatform.user | Deploy and test in dev. | Touch prod. Change the floor setting. |
| [ai-app-<name>-operators] | App prod project | roles/run.viewer, roles/logging.viewer | Watch the service and its logs. | Deploy. Read the corpus. |
| [ai-guardrail-owners] | App projects | roles/modelarmor.admin | Change templates through the runbook. | Deploy the app. Read the corpus. |
| [ai-data-owners-<domain>] | Source buckets | roles/storage.objectViewer on the raw bucket, by request and time-limited | Review raw source data and quarantined documents. | Change the app or guardrails. |
| [ai-security-ops] | ai-security-logs | roles/logging.privateLogViewer | Read Data Access logs and guardrail logs for investigation. | Change the workload. |
| [ai-key-custodians] | ai-keys | roles/cloudkms.admin | Rotate, disable or destroy keys. | Decrypt data. |
| [ai-app-<name>-users] | App Cloud Run service | roles/run.invoker | Call the app. What they retrieve is decided by the app's entitlement check. | Call any other app. |

## Service identities per application

| Identity | Grants | Purpose |
|---|---|---|
| Runtime | roles/aiplatform.user on the project (Vertex AI has no narrower scope for model calls). roles/storage.objectViewer on the clean bucket only. | Answer questions from de-identified content. Cannot write to its own source (C2-01). |
| Ingestion | Read on the raw bucket. Create on the clean and quarantine buckets. roles/dlp.user and roles/modelarmor.user. | Screen and de-identify documents. Replaces the person running ingestion today (DF-03). |
| Build | Only what a build needs: Artifact Registry write and build logs. | Replaces the default compute account for Cloud Build (F2-01 option B). |
| Deploy | roles/run.admin on the app project. roles/iam.serviceAccountUser on the runtime identity only. | Terraform deploys. Can attach the runtime identity and nothing else. |
| Service agents | Whatever Google assigns. The Vertex AI service agent also needs roles/modelarmor.user for floor setting screening. | Leave in place. Do not grant extra roles to them. |

## Separation of duties

| Must stay apart | Why |
|---|---|
| Key administration and data access | Disabling a key is an outage lever (F7-06). The person who can pull it should not be the person reading the data. |
| Guardrail change and app deploy | A developer who can weaken the template and ship the app has no second check. The guardrail-change alert assumes these are different people. |
| Raw data read and app runtime | DF-01 showed one grant can undo the whole de-identification pipeline. |
| Floor setting and app projects | The floor sets the minimum. App teams should not be able to lower it for themselves. |

## Organization policies that hold the model in place

| Constraint | Effect |
|---|---|
| iam.automaticIamGrantsForDefaultServiceAccounts | New projects stop giving the default compute account Editor. Existing projects still need F2-01 fixed. |
| iam.disableServiceAccountKeyCreation | No downloadable keys. |
| iam.allowedPolicyMemberDomains | Only Enterprise identities can be granted access. |
| storage.uniformBucketLevelAccess | Access through IAM only, no object ACLs. Legacy bucket role bindings still need removing in Terraform (DF-02). |
| run.allowedIngress | Blocks public ingress on Cloud Run, which closes the F6-01 bypass at the organization level. |

Project creation is limited to [ai-platform-admins] for the AI folder. That keeps new AI work out of personal projects with no organization (F7-07).

## Elevation and expiry

Elevated access, such as a data owner reading raw documents, is granted with an IAM condition that ends it at a set time. The lab used this for test personas and the impersonation grant. After any grant, wait and test the access before reporting it in place. In the lab, grants took between 90 seconds and 3 minutes.

## Review

1. Quarterly, list who holds each role on the AI folder and compare against the groups above. Anything granted to a person directly is a finding.
2. Review IAM recommender output for the runtime and ingestion identities. Unused permissions come off.
3. After any incident or exception, check whether a grant was added outside Terraform.

## Open questions for the Enterprise

1. Which identity provider groups already exist, and who owns membership?
2. Is there an existing privileged access process this should plug into rather than replace?
3. Who is the decision owner for the floor setting across the organization?
