# Module 9 Private Access Findings

Date tested: 2026-10-14
Project: rb-ai-prod-sim-1013. All Terraform in `terraform/network.tf`.

## What was built
- VPC ai-app-vpc with one subnet, ai-app-run-subnet (10.10.0.0/26), Private Google Access on.
- Private Cloud DNS zone for googleapis.com: an A record for private.googleapis.com (199.36.153.8/30) and a CNAME sending every *.googleapis.com name to it.
- Firewall: egress allowed on TCP 443 to 199.36.153.8/30 (priority 1000). All other egress denied (priority 65000).
- No Cloud NAT. Nothing in the subnet has a route to the internet.
- Applied 21:32:46 UTC, 7 resources.

## Test method
Two Cloud Run jobs ran the same script as store-assistant-sa, using the google-cloud-cli slim image. Each resolved three names and made one HTTPS request to each.
- egress-test-open: default Cloud Run networking.
- egress-test-private: all traffic through ai-app-vpc.

## Results

| Destination | Default networking | Through ai-app-vpc |
|---|---|---|
| us-central1-aiplatform.googleapis.com | Public address, HTTP 404 | 199.36.153.8, HTTP 404 |
| storage.googleapis.com | Public address, HTTP 400 | 199.36.153.11, HTTP 400 |
| example.com | Public address, HTTP 200 | Public address resolved, connection blocked (000) |

The 404 and 400 codes are expected: the script called each API root without a valid request. What matters is that the connection was made, and over which addresses.

## App moved onto the private path
At 21:41:43 UTC the store-assistant service was moved onto ai-app-vpc with all-traffic egress (revision 00014). Persona tests afterwards:

| Caller | Question | Retrieved | Answer |
|---|---|---|---|
| HR | Dana Whitfield's employee ID | hr-employee-record | E-48213 |
| Store staff | What time do stores open? | store-ops-policy | 8:00 AM |

Vertex AI, Model Armor and Cloud Storage calls all worked over the private range. To run these tests from a workstation, ingress was opened at 21:41:59 and restored to internal-and-cloud-load-balancing at 21:42:25.

## F9-01 DNS still resolves any public name (MEDIUM, exfiltration channel)
Inside the VPC, example.com resolved to its public address even though the connection was blocked. Name lookups for any domain still leave the network through Google's resolver. Data encoded into lookups for a domain an attacker controls would reach that attacker's DNS server. This was not exploited in testing. The successful lookup shows the path exists.
Recommendation: a Cloud DNS response policy that answers only for approved names and returns nothing for the rest.

## F9-02 The app's network attachment was made with gcloud (LOW, configuration drift)
The VPC, DNS and firewall are in Terraform. The setting that puts the Cloud Run service on that network is not. A redeploy from a definition without it would move the app back to default networking with open egress, and nothing would flag it.
Recommendation: manage the Cloud Run service in Terraform (same gap as F6-04), and alert on deploys that drop the network setting.

## Controls verified
C9-01 Google APIs resolve to the private range from inside the VPC and are reachable on it.
C9-02 Connections to non-Google internet destinations are blocked.
C9-03 The app works unchanged on the private path, including model calls and scoped retrieval.

## Cleanup
The two test jobs remain in the project and should be deleted when the lab is torn down.
