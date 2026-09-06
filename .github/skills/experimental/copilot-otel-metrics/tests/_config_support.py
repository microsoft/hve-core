# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Shared, non-collected support for the configuration and carrier test owners.

This module holds the production-shaped helpers that more than one owner reads:
document parsing, the redaction policy accessors, the fail-closed redaction
simulator, the shipped-consumer derivation, and the OTTL scrub inspectors. It
declares no tests so that pytest never collects it and the fuzz harness can
import it without crossing a collected-test boundary.
"""

from __future__ import annotations

import json
import pathlib
import re
from dataclasses import dataclass
from typing import Any

import yaml

SKILL_ROOT = pathlib.Path(__file__).resolve().parents[1]
EXAMPLES_DIR = SKILL_ROOT / "examples"
AZURE_DIR = EXAMPLES_DIR / "azure"
COMPOSE_PATH = EXAMPLES_DIR / "compose.yaml"
COLLECTOR_PATH = EXAMPLES_DIR / "otel-collector-local.yaml"
DASHBOARD_PATH = EXAMPLES_DIR / "dashboards" / "copilot-otel.json"
BASELINE_PATH = EXAMPLES_DIR / "baseline.py"
FLEET_COLLECTOR_PATH = AZURE_DIR / "otel-collector-config.yaml"
RELAY_DIR = AZURE_DIR / "agent-host-relay"
RELAY_COLLECTOR_PATH = RELAY_DIR / "otel-collector-config.yaml"
RELAY_COMPOSE_PATH = RELAY_DIR / "compose.yaml"

MASK = "****"
SCRUB = "[redacted]"

DIGEST_REFERENCE = re.compile(r"^[^\s@]+@sha256:[0-9a-f]{64}$")

# --- Shipped-consumer derivation -------------------------------------------
#
# The default disposition for a carrier the Collector does not govern is to
# scrub it. The only thing that earns an exception is a shipped consumer that
# reads it, so the consumer set has to be derived from the shipped artifacts
# rather than curated by hand. A hand-curated set cannot notice a newly
# required attribute, and a scrub decision made against a stale set breaks a
# panel silently.

# Label names Prometheus reserves or Grafana generates. Excluded by rule, not
# by listing the ones this dashboard happens to use today.
PROMETHEUS_RESERVED_LABELS = frozenset({"le", "quantile", "__name__", "job", "instance"})

# A metric reference is an identifier immediately followed by a label matcher
# or a range selector. A function is followed by "(", so this separates the two
# without enumerating PromQL's function set.
PROMQL_METRIC = re.compile(r"\b([a-z_][a-z0-9_]*)\s*[{\[]")
# Grafana resolves label_values(metric, label): metric first, label second.
PROMQL_LABEL_VALUES = re.compile(
    r"label_values\(\s*([a-z_][a-z0-9_]*)\s*,\s*([a-z_][a-z0-9_]*)\s*\)"
)
PROMQL_GROUPING = re.compile(r"\b(?:by|without)\s*\(([^)]*)\)")
PROMQL_MATCHER = re.compile(r"([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:=~|!~|=|!=)\s*\"")
# baseline.py reads label values directly rather than through a panel. Its
# reads are consumers too; leaving them out of the inventory is how a detection
# control gets scrubbed without anything noticing.
BASELINE_LABEL_READ = re.compile(r"label_values\(\s*\"([a-z_][a-z0-9_]*)\"\s*\)")

# TraceQL. The lookbehind keeps `service.name=` and `mode_name !=` from
# reading as span-name matchers; only a bare `name` is the intrinsic.
TRACEQL_SPAN_NAME = re.compile(r"(?<![\w.])name\s*(?:=~|!~|=|!=)\s*\"([^\"]*)\"")
TRACEQL_ATTRIBUTE = re.compile(r"\b(span|resource)\.([A-Za-z_][A-Za-z0-9_.]*)")

# Attributes observed carrying plaintext content on spans even with content
# capture left at its default. None may appear in the allow-list.
OBSERVED_CONTENT_ATTRIBUTES = frozenset(
    {
        "copilot_chat.user_request",
        "copilot_chat.reasoning_content",
        "gen_ai.input.messages",
        "gen_ai.output.messages",
        "gen_ai.system_instructions",
        "gen_ai.tool.call.arguments",
        "gen_ai.tool.call.result",
    }
)

# Intrinsics a shipped consumer reads directly. `span.name` is here because
# three TraceQL queries match on it; the metric intrinsics are here because
# every Prometheus query selects by metric name.
PROTECTED_INTRINSICS = frozenset({"span.name", "metric.name", "metric.description", "metric.unit"})

ATTRIBUTE_TARGET = re.compile(r"attributes\[\"([^\"]+)\"\]")


class ConfigError(ValueError):
    """Raised when a configuration document cannot yield the requested value."""


@dataclass(frozen=True)
class ShippedConsumers:
    """Everything the shipped artifacts read out of stored telemetry."""

    metric_names: frozenset[str]
    prometheus_labels: frozenset[str]
    span_name_matchers: tuple[str, ...]
    span_attributes: frozenset[str]
    resource_attributes: frozenset[str]
    trace_fields: frozenset[str]

    def protected_attribute_keys(self) -> frozenset[str]:
        """OTLP attribute keys a shipped consumer reads by their real name."""
        return self.span_attributes | self.resource_attributes


def _promql_labels(expr: str) -> set[str]:
    labels: set[str] = set()
    for clause in PROMQL_GROUPING.findall(expr):
        labels.update(part.strip() for part in clause.split(",") if part.strip())
    labels.update(PROMQL_MATCHER.findall(expr))
    return labels


def shipped_consumers() -> ShippedConsumers:
    """Derive the consumer inventory from the dashboard and the baseline helper."""
    dashboard = json.loads(DASHBOARD_PATH.read_text(encoding="utf-8"))

    metric_names: set[str] = set()
    labels: set[str] = set()
    span_names: list[str] = []
    span_attributes: set[str] = set()
    resource_attributes: set[str] = set()

    for variable in dashboard.get("templating", {}).get("list", []):
        query = variable.get("query")
        if isinstance(query, str):
            for metric, label in PROMQL_LABEL_VALUES.findall(query):
                metric_names.add(metric)
                labels.add(label)

    for panel in dashboard.get("panels", []):
        if panel.get("type") == "row":
            continue
        source = panel.get("datasource", {}).get("type")
        for target in panel.get("targets", []):
            expr = target.get("expr") or target.get("query") or ""
            if source == "prometheus":
                metric_names.update(PROMQL_METRIC.findall(expr))
                labels.update(_promql_labels(expr))
            elif source == "tempo":
                span_names.extend(TRACEQL_SPAN_NAME.findall(expr))
                for scope, key in TRACEQL_ATTRIBUTE.findall(expr):
                    target_set = span_attributes if scope == "span" else resource_attributes
                    target_set.add(key.rstrip("."))

    # A `$name` token is a Grafana template variable, not a stored label.
    labels = {label for label in labels if not label.startswith("$")}

    baseline_source = BASELINE_PATH.read_text(encoding="utf-8")
    labels.update(BASELINE_LABEL_READ.findall(baseline_source))
    labels = {
        label
        for label in labels
        if not label.startswith("$") and label not in PROMETHEUS_RESERVED_LABELS
    }
    trace_fields = {field for field in ("rootTraceName", "durationMs") if field in baseline_source}

    return ShippedConsumers(
        metric_names=frozenset(metric_names),
        prometheus_labels=frozenset(labels),
        span_name_matchers=tuple(span_names),
        span_attributes=frozenset(span_attributes),
        resource_attributes=frozenset(resource_attributes),
        trace_fields=frozenset(trace_fields),
    )


def prometheus_label_for(attribute_key: str) -> str:
    """Render an OTLP attribute key the way Prometheus stores it as a label.

    Comparing in this direction avoids inventing an OTLP spelling from a label.
    `copilot_chat_edit_source` has two plausible sources, and reconstructing one
    of them would be the guess this whole change exists to stop making.
    """
    return re.sub(r"[^a-zA-Z0-9_]", "_", attribute_key)


def load_yaml_text(text: str) -> dict[str, Any]:
    """Parse YAML text into a mapping, raising ConfigError on anything else."""
    try:
        document = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        raise ConfigError(f"document is not valid YAML: {exc}") from exc
    if not isinstance(document, dict):
        raise ConfigError("document root is not a mapping")
    return document


def load_yaml_file(path: pathlib.Path) -> dict[str, Any]:
    """Parse a YAML file into a mapping."""
    if not path.is_file():
        raise ConfigError(f"missing configuration file: {path.name}")
    return load_yaml_text(path.read_text(encoding="utf-8"))


def published_ports(service: dict[str, Any]) -> list[str]:
    """Return the declared host port mappings for a Compose service."""
    return [str(entry) for entry in service.get("ports", []) or []]


def redaction_policy(collector: dict[str, Any]) -> dict[str, Any]:
    """Return the redaction processor configuration from a Collector document."""
    processors = collector.get("processors") or {}
    if not isinstance(processors, dict):
        raise ConfigError("processors is not a mapping")
    for name, config in processors.items():
        if name == "redaction" or str(name).startswith("redaction/"):
            return config or {}
    raise ConfigError("no redaction processor is declared")


def allowed_keys(collector: dict[str, Any]) -> frozenset[str]:
    """Return the allow-listed attribute keys declared by the redaction processor."""
    policy = redaction_policy(collector)
    return frozenset(str(key) for key in policy.get("allowed_keys", []) or [])


def blocked_values(collector: dict[str, Any]) -> tuple[re.Pattern[str], ...]:
    """Return the compiled value patterns the redaction processor masks."""
    policy = redaction_policy(collector)
    return tuple(re.compile(str(pattern)) for pattern in policy.get("blocked_values", []) or [])


def simulate_redaction(
    attributes: dict[str, str],
    allow: frozenset[str],
    blocked: tuple[re.Pattern[str], ...] = (),
    allow_all_keys: bool = False,
) -> dict[str, str]:
    """Model the Collector redaction processor's fail-closed key and value handling.

    Any key outside the allow-list is dropped rather than kept, so an attribute
    this skill has never seen cannot reach storage. Allowed values that still
    match a blocked pattern are masked rather than dropped.
    """
    result: dict[str, str] = {}
    for key, value in attributes.items():
        if not allow_all_keys and key not in allow:
            continue
        text = str(value)
        result[key] = MASK if any(pattern.search(text) for pattern in blocked) else text
    return result


def scrub_statements(collector: dict[str, Any]) -> list[str]:
    """Every OTTL statement the content-scrub processor declares."""
    processors = collector.get("processors") or {}
    processor = processors.get("transform/scrub", {}) or {}
    statements: list[str] = []
    for key in ("trace_statements", "log_statements", "metric_statements"):
        for entry in processor.get(key) or []:
            if isinstance(entry, str):
                statements.append(entry)
            else:
                statements.extend(entry.get("statements", []))
    return statements


def statement_target(statement: str) -> str:
    """The path an OTTL statement writes to.

    Only the write target matters. A `where` clause may read `span.name`
    without endangering it, and treating a read as an overreach would push the
    scrub rules into contortions to avoid mentioning what they must not touch.
    """
    if "(" not in statement:
        return ""
    inner = statement.split("(", 1)[1]
    depth = 0
    for index, character in enumerate(inner):
        if character in "([":
            depth += 1
        elif character in ")]":
            if depth == 0:
                return inner[:index].strip()
            depth -= 1
        elif character == "," and depth == 0:
            return inner[:index].strip()
    return inner.strip()


def overreaching_statements(
    statements: list[str], consumers: ShippedConsumers
) -> list[tuple[str, str]]:
    """Statements whose write target is something a shipped consumer reads."""
    protected_keys = consumers.protected_attribute_keys()
    findings: list[tuple[str, str]] = []
    for statement in statements:
        target = statement_target(statement)
        if target in PROTECTED_INTRINSICS:
            findings.append((statement, target))
            continue
        for key in ATTRIBUTE_TARGET.findall(target):
            if key in protected_keys:
                findings.append((statement, key))
    return findings
