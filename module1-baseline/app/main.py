import os
from flask import Flask, request, jsonify
from google import genai
from google.cloud import storage

PROJECT = os.environ.get("PROJECT_ID", "rb-ai-prod-sim-1013")
LOCATION = os.environ.get("REGION", "us-central1")
BUCKET = os.environ.get("DOCS_BUCKET", "rb-ai-prod-sim-1013-docs")
MODEL = os.environ.get("MODEL_ID", "gemini-2.5-flash")

app = Flask(__name__)
genai_client = genai.Client(vertexai=True, project=PROJECT, location=LOCATION)
gcs = storage.Client(project=PROJECT)


def load_docs():
    # Naive retrieval: every document goes into context, no filtering.
    parts = []
    for blob in gcs.bucket(BUCKET).list_blobs():
        parts.append(f"--- {blob.name} ---\n{blob.download_as_text()}")
    return "\n\n".join(parts)


@app.route("/healthz")
def healthz():
    return "ok"


@app.route("/ask", methods=["POST"])
def ask():
    question = (request.get_json(silent=True) or {}).get("question", "").strip()
    if not question:
        return jsonify({"error": "question is required"}), 400
    prompt = (
        "You are an internal store operations assistant. "
        "Answer using only the documents below.\n\n"
        f"{load_docs()}\n\nQuestion: {question}"
    )
    r = genai_client.models.generate_content(model=MODEL, contents=prompt)
    return jsonify({"answer": r.text})


if __name__ == "__main__":
    app.run(host="0.0.0.0",
 port=int(os.environ.get("PORT", 8080)))
