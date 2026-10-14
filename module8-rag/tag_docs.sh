#!/usr/bin/env bash
# Sets the audience tag on each clean document. The app denies any document
# without a tag. In production the document owner sets this at upload.
set -euo pipefail
B=gs://rb-ai-prod-sim-1013-docs-clean
gcloud storage objects update "$B/store-ops-policy.txt"  --custom-metadata=audience=all-staff
gcloud storage objects update "$B/hr-employee-record.txt" --custom-metadata=audience=hr
gcloud storage objects update "$B/refund-log.txt"         --custom-metadata=audience=payments
