"""HTTP client for the Nexus Router MCP (Streamable HTTP).

Talks to ``NEXUS_ROUTER_URL`` (default ``http://localhost/mcp/router``).
Auth: ``Authorization: Bearer`` and/or ``Api-Key`` (same pass-through as
the router). Every tool call injects ``NEXUS_CONTEXT_SLUG``.
"""

from __future__ import annotations

import json
import os
from typing import Any, Optional

import httpx


class NexusRouterError(RuntimeError):
    """A failed MCP or HTTP call to the router."""


def _parse_sse_json(text: str) -> dict[str, Any]:
    for line in text.splitlines():
        if line.startswith("data:"):
            payload = line[5:].strip()
            if payload:
                return json.loads(payload)
    try:
        return json.loads(text)
    except json.JSONDecodeError as e:
        raise NexusRouterError(f"router response was not JSON/SSE: {text[:300]}") from e


def _tool_text(doc: dict[str, Any]) -> str:
    if "error" in doc:
        err = doc["error"]
        if isinstance(err, dict):
            return f"error: {err.get('message') or err}"
        return f"error: {err}"
    result = doc.get("result") or {}
    if result.get("isError"):
        parts = [
            c.get("text", "")
            for c in (result.get("content") or [])
            if isinstance(c, dict) and c.get("type") == "text"
        ]
        return "error: " + (" ".join(parts) or "tool failed")
    texts = [
        c.get("text", "")
        for c in (result.get("content") or [])
        if isinstance(c, dict) and c.get("type") == "text"
    ]
    if texts:
        return "\n".join(texts)
    sc = result.get("structuredContent")
    if sc is None:
        return ""
    if isinstance(sc, dict) and "result" in sc:
        sc = sc["result"]
    if isinstance(sc, str):
        return sc
    return json.dumps(sc, default=str)


class NexusRouterClient:
    """One MCP session per toolkit instance. Connects on first ``call``."""

    def __init__(
        self,
        url: Optional[str] = None,
        *,
        token: Optional[str] = None,
        api_key: Optional[str] = None,
        context: Optional[str] = None,
        timeout: float = 60.0,
    ) -> None:
        self.url = (url or os.environ.get("NEXUS_ROUTER_URL") or "http://localhost/mcp/router").rstrip(
            "/"
        )
        self.token = token or os.environ.get("NEXUS_TOKEN") or ""
        self.api_key = api_key or os.environ.get("PINECONE_API_KEY") or ""
        self.context = context or os.environ.get("NEXUS_CONTEXT_SLUG") or ""
        self.timeout = timeout
        self._session_id: Optional[str] = None
        self._rpc_id = 0

    def _headers(self, *, session: bool = True) -> dict[str, str]:
        h = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self.token:
            h["Authorization"] = f"Bearer {self.token}"
        if self.api_key:
            h["Api-Key"] = self.api_key
        if session and self._session_id:
            h["mcp-session-id"] = self._session_id
        return h

    def _post(self, body: dict[str, Any], *, session: bool = True) -> httpx.Response:
        try:
            return httpx.post(
                self.url,
                json=body,
                headers=self._headers(session=session),
                timeout=self.timeout,
            )
        except httpx.HTTPError as e:
            raise NexusRouterError(f"router HTTP failed: {e}") from e

    def _ensure_session(self) -> None:
        if self._session_id:
            return
        self._rpc_id += 1
        init = {
            "jsonrpc": "2.0",
            "id": self._rpc_id,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "tau2-nexus-router", "version": "0"},
            },
        }
        resp = self._post(init, session=False)
        if resp.status_code >= 400:
            raise NexusRouterError(
                f"router initialize HTTP {resp.status_code}: {resp.text[:300]}"
            )
        sid = resp.headers.get("mcp-session-id")
        if not sid:
            raise NexusRouterError("router initialize returned no mcp-session-id")
        self._session_id = sid
        notify = {"jsonrpc": "2.0", "method": "notifications/initialized"}
        self._post(notify)

    def call(self, name: str, arguments: Optional[dict[str, Any]] = None) -> str:
        self._ensure_session()
        args = dict(arguments or {})
        if self.context and "context" not in args:
            args["context"] = self.context
        if not args.get("context"):
            raise NexusRouterError(
                "NEXUS_CONTEXT_SLUG is required (or pass context= on the tool)"
            )
        self._rpc_id += 1
        body = {
            "jsonrpc": "2.0",
            "id": self._rpc_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": args},
        }
        resp = self._post(body)
        if resp.status_code >= 400:
            raise NexusRouterError(
                f"router tools/call HTTP {resp.status_code}: {resp.text[:300]}"
            )
        return _tool_text(_parse_sse_json(resp.text))
