import base64
import json
import math
import os
import time

from flask import Flask, jsonify, request
from google import genai
from google.auth.transport import requests as google_requests
from google.cloud import storage
from google.genai import types
from google.oauth2 import id_token


def required(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required setting {name} is missing. Refusing to start.")
    return value


# Fail closed: no default falls back to the raw bucket or to running without a guardrail (DF-04).
PROJECT = required("PROJECT_ID")
LOCATION = required("REGION")
BUCKET = required("DOCS_BUCKET")
MODEL = required("MODEL_ID")
MA_TEMPLATE = required("MA_TEMPLATE")
TOKEN_AUDIENCES = json.loads(required("TOKEN_AUDIENCES"))
ENTITLEMENTS = json.loads(required("ENTITLEMENTS"))
EMBED_MODEL = os.environ.get("EMBED_MODEL", "text-embedding-005")
INDEX_PATH = os.environ.get("INDEX_PATH", "_index/embeddings.json")
TOP_K = int(os.environ.get("TOP_K", "2"))
MIN_SCORE = float(os.environ.get("MIN_SCORE", "0.55"))

app = Flask(__name__)
genai_client = genai.Client(vertexai=True, project=PROJECT, location=LOCATION)
bucket = storage.Client(project=PROJECT).bucket(BUCKET)
token_request = google_requests.Request()
_index = None


def log(**fields):
    print(json.dumps(fields), flush=True)


def caller_identity():
    """Returns (email, method). Tries full signature verification first. If Cloud Run
    has already verified the token and removed its signature, accepts the claims only
    when the audience is this service and the token has not expired."""
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return None, "missing"
    token = header[len("Bearer "):]
    for audience in TOKEN_AUDIENCES:
        try:
            claims = id_token.verify_oauth2_token(token, token_request, audience=audience)
            if claims.get("email_verified") and claims.get("email"):
                return claims["email"], "verified"
        except ValueError:
            pass
    parts = token.split(".")
    if len(parts) == 3 and parts[2] == "SIGNATURE_REMOVED_BY_GOOGLE":
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
        if payload.get("aud") in TOKEN_AUDIENCES and payload.get("exp", 0) > time.time() \
                and payload.get("email_verified") and payload.get("email"):
            return payload["email"], "platform"
    return None, "invalid"


def load_index():
    global _index
    if _index is None:
        _index = json.loads(bucket.blob(INDEX_PATH).download_as_text())["entries"]
    return _index


def embed(text):
    r = genai_client.models.embed_content(
        model=EMBED_MODEL, contents=[text],
        config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"))
    return r.embeddings[0].values


def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    return dot / (math.sqrt(sum(x * x for x in a)) * math.sqrt(sum(y * y for y in b)))


def retrieve(question, allowed):
    """Filters to the caller's entitled documents BEFORE ranking, then rechecks each
    chosen document's live tag in case it changed after the index was built."""
    in_scope = [e for e in load_index() if e.get("audience") in allowed]
    if not in_scope:
        return [], 0, []
    q = embed(question)
    scored = sorted(((cosine(q, e["embedding"]), e) for e in in_scope), key=lambda p: p[0], reverse=True)
    scores = [[e["name"], round(sc, 3)] for sc, e in scored]
    # Relevance floor (F8-03): an in-scope document still has to be relevant to be sent.
    ranked = [e for sc, e in scored if sc >= MIN_SCORE][:TOP_K]
    docs = []
    for e in ranked:
        blob = bucket.get_blob(e["name"])
        live = (blob.metadata or {}).get("audience") if blob else None
        if live not in allowed:
            log(severity="WARNING", event="tag_mismatch", doc=e["name"], indexed=e.get("audience"), live=live)
            continue
        docs.append((e["name"], blob.download_as_text()))
    return docs, len(in_scope), scores


@app.route("/healthz")
def healthz():
    return "ok"


@app.route("/ask", methods=["POST"])
def ask():
    email, method = caller_identity()
    if not email:
        log(severity="WARNING", event="auth_denied", reason=method)
        return jsonify({"error": "authentication required"}), 401
    allowed = set(ENTITLEMENTS.get(email, []))
    if not allowed:
        log(severity="WARNING", event="no_entitlements", caller=email)
        return jsonify({"error": "no document entitlements"}), 403
    question = (request.get_json(silent=True) or {}).get("question", "").strip()
    if not question:
        return jsonify({"error": "question is required"}), 400

    docs, in_scope, scores = retrieve(question, allowed)
    sources = [name for name, _ in docs]
    # Audit record: who asked and what was retrieved. The question text is not logged (LG-06).
    log(severity="INFO", event="retrieval", caller=email, auth=method,
        entitled=sorted(allowed), in_scope=in_scope, min_score=MIN_SCORE, scores=scores, sources=sources)
    if not docs:
        return jsonify({"answer": "No documents available to you cover that question.", "sources": []})

    context = "\n\n".join(f"--- {name} ---\n{text}" for name, text in docs)
    prompt = ("You are an internal store operations assistant. "
              "Answer using only the documents below.\n\n"
              f"{context}\n\nQuestion: {question}")
    config = types.GenerateContentConfig(model_armor_config=types.ModelArmorConfig(
        prompt_template_name=MA_TEMPLATE, response_template_name=MA_TEMPLATE))
    r = genai_client.models.generate_content(model=MODEL, contents=prompt, config=config)
    fb = r.prompt_feedback
    if fb and fb.block_reason:
        return jsonify({"blocked": str(fb.block_reason), "detail": fb.block_reason_message}), 403
    if not r.text:
        return jsonify({"blocked": "RESPONSE_BLOCKED"}), 403
    return jsonify({"answer": r.text, "sources": sources})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
