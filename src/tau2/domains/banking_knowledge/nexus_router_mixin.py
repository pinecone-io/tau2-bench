"""Nexus Router tools as tau2 MixIns.

Each method is a thin wrapper around ``NexusRouterClient.call``. The
concrete toolkit sets ``self._nexus_router`` before any tool is invoked.
"""

from __future__ import annotations

from typing import Any, Optional

from tau2.environment.toolkit import ToolKitType, ToolType, is_tool


class NexusRouterMixin(metaclass=ToolKitType):
    """Expects ``self._nexus_router`` (a ``NexusRouterClient``)."""

    @is_tool(ToolType.READ)
    def orient(self) -> str:
        """Gist of the curated Nexus context. Call this first.

        How to retrieve, schema, product catalog, rate/procedure samples.
        SQL first after this. Do not re-orient unless the context changes.
        """
        return self._nexus_router.call("orient")

    @is_tool(ToolType.READ)
    def outline_knowledge(self) -> str:
        """Map of curated artifacts (name / type / scope)."""
        return self._nexus_router.call("outline_knowledge")

    @is_tool(ToolType.READ)
    def list_artifacts(self, scope: Optional[str] = None) -> str:
        """List curated artifacts. Optional scope=corpus|document|index."""
        args: dict[str, Any] = {}
        if scope:
            args["scope"] = scope
        return self._nexus_router.call("list_artifacts", args)

    @is_tool(ToolType.READ)
    def read_artifact(self, name_or_slug: str) -> str:
        """Read one curated artifact body by name or slug."""
        return self._nexus_router.call(
            "read_artifact", {"name_or_slug": name_or_slug}
        )

    @is_tool(ToolType.READ)
    def read_artifact_full(self, name_or_slug: str) -> str:
        """One artifact: body + edges + sources + metadata."""
        return self._nexus_router.call(
            "read_artifact_full", {"name_or_slug": name_or_slug}
        )

    @is_tool(ToolType.READ)
    def read_rosters(self) -> str:
        """Index-scope 'All X' roster artifacts."""
        return self._nexus_router.call("read_rosters")

    @is_tool(ToolType.READ)
    def read_source(self, path: str) -> str:
        """Raw source file text by source-relative path."""
        return self._nexus_router.call("read_source", {"path": path})

    @is_tool(ToolType.READ)
    def get_manifest(self) -> str:
        """Full curate manifest for this context."""
        return self._nexus_router.call("get_manifest")

    @is_tool(ToolType.READ)
    def describe_type(self, name: str) -> str:
        """Manifest spec for one artifact type, plus related edge types."""
        return self._nexus_router.call("describe_type", {"name": name})

    @is_tool(ToolType.READ)
    def search_knowledge(
        self, query: str, top_k: int = 10, kind: Optional[str] = None
    ) -> str:
        """Semantic search over curated artifacts.

        Args:
            query: Natural-language query.
            top_k: Hits to return (default 10).
            kind: Optional artifact kind (summary|topic|entity|event|doc|page|glossary).
        """
        args: dict[str, Any] = {"query": query, "top_k": top_k}
        if kind:
            args["kind"] = kind
        return self._nexus_router.call("search_knowledge", args)

    @is_tool(ToolType.READ)
    def search_source(self, query: str, top_k: int = 10) -> str:
        """Semantic search over raw source chunks.

        Args:
            query: Natural-language query.
            top_k: Hits to return (default 10).
        """
        return self._nexus_router.call(
            "search_source", {"query": query, "top_k": top_k}
        )

    @is_tool(ToolType.READ)
    def search_source_by_keyword(self, query: str, top_k: int = 10) -> str:
        """Lexical / BM25 search over source chunks. Use for exact ids, codes, names."""
        return self._nexus_router.call(
            "search_source_by_keyword", {"query": query, "top_k": top_k}
        )

    @is_tool(ToolType.READ)
    def search_in_sources(self, sources: str, queries: str, max_total: int = 20) -> str:
        """Semantic chunk search restricted to an artifact's source paths.

        Args:
            sources: Comma-separated source paths (from an artifact's .sources).
            queries: One query, or comma-separated queries.
            max_total: Max hits (default 20).
        """
        src_list = [s.strip() for s in sources.split(",") if s.strip()]
        q_list = [q.strip() for q in queries.split(",") if q.strip()]
        return self._nexus_router.call(
            "search_in_sources",
            {"sources": src_list, "queries": q_list or queries, "max_total": max_total},
        )

    @is_tool(ToolType.READ)
    def cite_from_artifact(
        self, name_or_slug: str, queries: str, max_total: int = 8
    ) -> str:
        """Find an artifact, then pull verbatim citable spans from its sources."""
        q_list = [q.strip() for q in queries.split(",") if q.strip()]
        return self._nexus_router.call(
            "cite_from_artifact",
            {
                "name_or_slug": name_or_slug,
                "queries": q_list or queries,
                "max_total": max_total,
            },
        )

    @is_tool(ToolType.READ)
    def query_db(self, sql: str) -> str:
        """Read-only SQL against the context sqlite (SELECT/WITH/PRAGMA/EXPLAIN).

        Tables: product_profile, product_select_rule, atm_fee_terms,
        savings_card_boost, internal_tool, tool_step, transfer_protocol
        (plus policy_doc/rate/procedure if present). Prefer SQL.
        """
        return self._nexus_router.call("query_db", {"sql": sql})

    @is_tool(ToolType.READ)
    def list_tables(self) -> str:
        """Tables + column schemas in the structured database."""
        return self._nexus_router.call("list_tables")

    @is_tool(ToolType.READ)
    def relationships(self, artifact: str) -> str:
        """Typed edges touching `artifact` (either end)."""
        return self._nexus_router.call("relationships", {"artifact": artifact})

    @is_tool(ToolType.READ)
    def walk_graph(self, start: str, max_hops: int = 2) -> str:
        """N-hop undirected walk from `start`."""
        return self._nexus_router.call(
            "walk_graph", {"start": start, "max_hops": max_hops}
        )

    @is_tool(ToolType.READ)
    def get_fact(self, key: str) -> str:
        """Context-level fact: artifact_count, source_count, artifacts_by_type, curated_at."""
        return self._nexus_router.call("get_fact", {"key": key})
