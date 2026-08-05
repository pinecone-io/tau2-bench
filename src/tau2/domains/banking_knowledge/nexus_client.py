"""HTTP client for the Pinecone Nexus knowledge layer.

Auth resolves from the environment: ``NEXUS_TOKEN`` (a Nexus session JWT,
used directly) or ``PINECONE_API_KEY`` (minted into a session JWT via
``POST /api/v0/auth/login``; re-minted once on a 401). Queries are submitted
in background mode and polled until terminal, since Nexus queries can take
minutes.

Failures are returned as strings rather than raised so the calling agent
sees the error as a tool result and can retry or proceed.
"""

import json
import os
import time
from typing import Any, Optional

import httpx

DEFAULT_NEXUS_URL = "https://dev.nexus.pinecone.io"
LOGIN_TIMEOUT_SECONDS = 30.0
REQUEST_TIMEOUT_SECONDS = 60.0
POLL_INTERVAL_SECONDS = 3.0
TERMINAL_STATUSES = {"completed", "failed", "cancelled"}


class NexusClientError(Exception):
    """Configuration or authentication error for the Nexus client."""


class NexusClient:
    """Minimal client for querying one Nexus context."""

    def __init__(
        self,
        context: Optional[str] = None,
        url: Optional[str] = None,
        timeout_seconds: int = 600,
    ):
        self.context = (context or os.environ.get("NEXUS_CONTEXT", "")).strip()
        if not self.context:
            raise NexusClientError(
                "A Nexus context slug is required: set NEXUS_CONTEXT or pass "
                "--retrieval-config-kwargs '{\"nexus_context\": \"<slug>\"}'."
            )
        self.url = (url or os.environ.get("NEXUS_URL") or DEFAULT_NEXUS_URL).rstrip("/")
        self.timeout_seconds = timeout_seconds
        self._token: Optional[str] = None
        self._usage_log_path = os.environ.get("NEXUS_USAGE_LOG")

    # ── auth ────────────────────────────────────────────────────────────

    def _login(self) -> str:
        token = os.environ.get("NEXUS_TOKEN", "").strip()
        if token:
            return token
        api_key = os.environ.get("PINECONE_API_KEY", "").strip()
        if not api_key:
            raise NexusClientError(
                "Nexus auth is not configured: set NEXUS_TOKEN or PINECONE_API_KEY."
            )
        resp = httpx.post(
            f"{self.url}/api/v0/auth/login",
            json={"api_key": api_key},
            timeout=LOGIN_TIMEOUT_SECONDS,
        )
        if resp.status_code != 200:
            raise NexusClientError(f"Nexus login failed (HTTP {resp.status_code}).")
        token = resp.json().get("token")
        if not token:
            raise NexusClientError("Nexus login succeeded but returned no token.")
        return token

    def _request(
        self, method: str, path: str, retry_auth: bool = True, **kwargs: Any
    ) -> httpx.Response:
        if self._token is None:
            self._token = self._login()
        resp = httpx.request(
            method,
            f"{self.url}{path}",
            headers={"Authorization": f"Bearer {self._token}"},
            timeout=REQUEST_TIMEOUT_SECONDS,
            **kwargs,
        )
        if resp.status_code == 401 and retry_auth:
            self._token = None
            return self._request(method, path, retry_auth=False, **kwargs)
        return resp

    # ── query ───────────────────────────────────────────────────────────

    def query(self, question: str, task_id: Optional[str] = None) -> str:
        """Ask the context a question; block until the answer is ready.

        Returns the formatted answer with citations, or a human-readable
        error string on any failure.

        If ``NEXUS_QUERY_DIRECTIVE`` is set, its text is appended to every
        question as an answer-shape contract (the server sees it as part of
        the ask; the usage log records the original question).

        If ``NEXUS_QUERY_MODEL`` is set, it selects the model that runs the
        server-side search loop. It must be a **concrete catalog id** such as
        ``Qwen/Qwen3-235B-A22B-Instruct-2507``, never a tier name: a tier name
        passes the API's validation and is then dropped by the runtime's
        catalog filter, silently falling back to the standard tier — which
        would leave a cost experiment measuring a model it did not choose.

        ``task_id`` is optional bookkeeping for ``NEXUS_USAGE_LOG`` so per-task
        query cost/latency can be joined after a run.
        """
        directive = os.environ.get("NEXUS_QUERY_DIRECTIVE", "").strip()
        ask = (
            f"{question}\n\n[Answer requirements: {directive}]"
            if directive
            else question
        )
        payload: dict[str, Any] = {
            "scope": [self.context],
            "ask": ask,
            "background": True,
        }
        model = os.environ.get("NEXUS_QUERY_MODEL", "").strip()
        if model:
            payload["model"] = model
        try:
            resp = self._request("POST", "/api/v0/query", json=payload)
        except (httpx.HTTPError, NexusClientError) as e:
            return f"Nexus query error: {e}"

        if resp.status_code == 404:
            return f"Nexus error: context '{self.context}' not found."
        if resp.status_code == 409:
            return (
                f"Nexus error: context '{self.context}' is not queryable yet "
                "(never optimized)."
            )
        if resp.status_code not in (200, 201, 202):
            return f"Nexus query failed (HTTP {resp.status_code}): {resp.text[:500]}"

        query_id = resp.json().get("id")
        if not query_id:
            return "Nexus query was accepted but no query id was returned."

        row: dict[str, Any] = {}
        t_poll0 = time.monotonic()
        deadline = t_poll0 + self.timeout_seconds
        while time.monotonic() < deadline:
            try:
                poll = self._request("GET", f"/api/v0/queries/{query_id}")
            except (httpx.HTTPError, NexusClientError) as e:
                return f"Nexus poll error: {e}"
            if poll.status_code != 200:
                return f"Nexus poll failed (HTTP {poll.status_code}): {poll.text[:500]}"
            row = poll.json()
            if row.get("status") in TERMINAL_STATUSES:
                break
            time.sleep(POLL_INTERVAL_SECONDS)
        else:
            return (
                f"Nexus query timed out after {self.timeout_seconds}s "
                f"(query id {query_id}, last status: {row.get('status')})."
            )

        wall_ms = int((time.monotonic() - t_poll0) * 1000)
        self._log_usage(
            row,
            question=question,
            model_requested=model or None,
            wall_ms=wall_ms,
            task_id=task_id,
        )

        if row.get("status") != "completed":
            return (
                f"Nexus query {row.get('status')}: "
                f"{row.get('error') or 'no answer produced'}"
            )
        return _format_result(row)

    # ── bookkeeping ─────────────────────────────────────────────────────

    def _log_usage(
        self,
        row: dict[str, Any],
        *,
        question: str = "",
        model_requested: Optional[str] = None,
        wall_ms: Optional[int] = None,
        task_id: Optional[str] = None,
    ) -> None:
        """Append per-query usage to NEXUS_USAGE_LOG (jsonl) for cost accounting.

        Captures server ``runtime_ms`` / ``usage`` (tokens + cost_usd when present),
        client wall-clock wait ``wall_ms``, and optional ``task_id`` for joins.
        """
        if not self._usage_log_path:
            return
        usage = row.get("usage") or {}
        record = {
            "ts": time.time(),
            "task_id": task_id,
            "query_id": row.get("id"),
            "context": self.context,
            "status": row.get("status"),
            "model": row.get("model") or model_requested,
            "model_requested": model_requested,
            "runtime_ms": row.get("runtime_ms"),
            "wall_ms": wall_ms,
            "usage": usage,
            "input_tokens": usage.get("input_tokens") if isinstance(usage, dict) else None,
            "output_tokens": usage.get("output_tokens") if isinstance(usage, dict) else None,
            "total_tokens": usage.get("total_tokens") if isinstance(usage, dict) else None,
            "cost_usd": usage.get("cost_usd") if isinstance(usage, dict) else None,
            "question_preview": (question or "")[:240],
        }
        try:
            with open(self._usage_log_path, "a") as fp:
                fp.write(json.dumps(record) + "\n")
        except OSError:
            pass


def _format_result(row: dict[str, Any]) -> str:
    """Flatten the query wire document into a tool-result string."""
    answer_parts: list[str] = []
    for item in row.get("output") or []:
        for part in item.get("content") or []:
            if part.get("type") == "output_text" and part.get("text"):
                answer_parts.append(str(part["text"]))
    answer = "".join(answer_parts).strip()
    if not answer:
        return "Nexus returned no answer text."

    citations = row.get("citations") or []
    if not citations:
        return answer

    lines = [answer, "", "Citations:"]
    for i, citation in enumerate(citations, 1):
        lines.append(f"[{i}] {_format_citation(citation)}")
    return "\n".join(lines)


def _format_citation(citation: Any) -> str:
    if not isinstance(citation, dict):
        return str(citation)[:200]
    for key in ("title", "name", "source", "artifact", "document", "id"):
        value = citation.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return json.dumps(citation)[:200]
