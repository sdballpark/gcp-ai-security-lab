"""Builds the retrieval index for Module 8. Run by an operator after ingestion.
Each entry holds the document name, its audience tag and its embedding.
Untagged documents are indexed with audience None, which the app denies to everyone."""
import json
from google import genai
from google.genai import types
from google.cloud import storage

PROJECT = "rb-ai-prod-sim-1013"
BUCKET = f"{PROJECT}-docs-clean"
INDEX_PATH = "_index/embeddings.json"
MODEL = "text-embedding-005"

client = genai.Client(vertexai=True, project=PROJECT, location="us-central1")
bucket = storage.Client(project=PROJECT).bucket(BUCKET)

entries = []
for blob in bucket.list_blobs():
    if blob.name.startswith("_index/"):
        continue
    text = blob.download_as_text()
    audience = (blob.metadata or {}).get("audience")
    emb = client.models.embed_content(
        model=MODEL, contents=[text],
        config=types.EmbedContentConfig(task_type="RETRIEVAL_DOCUMENT")).embeddings[0].values
    entries.append({"name": blob.name, "audience": audience, "embedding": list(emb)})
    print(f"{blob.name}: audience={audience or 'UNTAGGED, denied to all'} dims={len(emb)}")

bucket.blob(INDEX_PATH).upload_from_string(
    json.dumps({"model": MODEL, "entries": entries}), content_type="application/json")
print(f"Wrote gs://{BUCKET}/{INDEX_PATH} with {len(entries)} entries")
