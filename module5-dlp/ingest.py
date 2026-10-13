import json, subprocess, urllib.request
P = "rb-ai-prod-sim-1013"
RAW, CLEAN, QUAR = f"gs://{P}-docs", f"gs://{P}-docs-clean", f"gs://{P}-docs-quarantine"
MA = f"https://modelarmor.us-central1.rep.googleapis.com/v1/projects/{P}/locations/us-central1/templates/store-assistant-ma:sanitizeUserPrompt"
DLP = f"https://dlp.googleapis.com/v2/projects/{P}/locations/global/content:deidentify"
TOKEN = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()

def post(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={
        "Authorization": f"Bearer {TOKEN}", "x-goog-user-project": P, "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=60))

def sh(*args, stdin=None):
    return subprocess.run(args, input=stdin, capture_output=True, text=True, check=True).stdout

manifest = []
for uri in sh("gcloud", "storage", "ls", RAW).split():
    name = uri.rsplit("/", 1)[-1]
    text = sh("gcloud", "storage", "cat", uri)
    ma = post(MA, {"userPromptData": {"text": text}})
    pi = ma["sanitizationResult"]["filterResults"]["pi_and_jailbreak"]["piAndJailbreakFilterResult"]["matchState"]
    if pi == "MATCH_FOUND":
        sh("gcloud", "storage", "cp", uri, f"{QUAR}/{name}")
        manifest.append({"file": name, "action": "QUARANTINED", "reason": "prompt injection"})
        print(f"QUARANTINE  {name}")
        continue
    d = post(DLP, {"item": {"value": text},
        "inspectTemplateName": f"projects/{P}/locations/global/inspectTemplates/rag-pii-inspect",
        "deidentifyTemplateName": f"projects/{P}/locations/global/deidentifyTemplates/rag-pii-deidentify"})
    masked = d["item"]["value"]
    sh("gcloud", "storage", "cp", "-", f"{CLEAN}/{name}", stdin=masked)
    n = sum(len(t.get("results", [])) for t in d.get("overview", {}).get("transformationSummaries", []))
    manifest.append({"file": name, "action": "CLEANED", "transformations": n})
    print(f"CLEAN       {name}  ({n} masked)")

json.dump(manifest, open("ingest_manifest.json", "w"), indent=1)
print("saved ingest_manifest.json")
