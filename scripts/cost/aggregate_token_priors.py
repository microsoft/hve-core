# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Aggregate historical token priors from local HVE telemetry summaries."""

from __future__ import annotations

import argparse
import copy
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts.cost.estimate_agent_cost import (  # noqa: E402
    EXIT_FAILURE,
    EXIT_SUCCESS,
    CostEstimatorError,
    normalize_name,
    sanitize_filename,
)
from scripts.cost.estimate_agent_cost import (  # noqa: E402
    build_result as build_static_result,
)
from scripts.cost.estimate_agent_cost import (  # noqa: E402
    to_serializable as static_to_serializable,
)

DEFAULT_MINIMUM_SAMPLES = 10
PERCENTILE_METHOD = "inclusive_linear_interpolation_ceil"


@dataclass(frozen=True)
class TokenMeasurement:
    """Token counters for one session, agent, or model observation."""

    input_tokens: int
    fresh_input_tokens: int
    output_tokens: int
    total_tokens: int
    cache_read_tokens: int
    cache_write_tokens: int
    requests: int


@dataclass
class ScanDiagnostics:
    """Counters describing telemetry ingestion and quality."""

    files_scanned: int = 0
    records_read: int = 0
    malformed_records: int = 0
    summary_records: int = 0
    ignored_summaries: int = 0
    superseded_summaries: int = 0
    unreadable_files: int = 0
    invalid_measurements: int = 0
    unattributed_model_sessions: int = 0
    merged_subagent_sessions: int = 0
    unresolved_subagent_sessions: int = 0


def positive_int(value: str) -> int:
    """Parse a positive integer for argparse."""
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("value must be at least 1")
    return parsed


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the historical-priors CLI parser."""
    parser = argparse.ArgumentParser(description="Aggregate local historical token priors")
    parser.add_argument("--agent", required=True, help="Agent used for prior selection")
    parser.add_argument("--phase", default=None, help="Optional phase for static fallback")
    parser.add_argument("--model", default=None, help="Optional model prior to highlight")
    parser.add_argument(
        "--encoding",
        default=None,
        help="Optional tiktoken encoding for the static fallback",
    )
    parser.add_argument(
        "--minimum-samples",
        type=positive_int,
        default=DEFAULT_MINIMUM_SAMPLES,
        help="Samples required before a p90 historical prior is eligible",
    )
    parser.add_argument(
        "--telemetry-dir",
        type=Path,
        default=None,
        help="Telemetry directory containing sessions-*.jsonl",
    )
    parser.add_argument("--repo-root", type=Path, default=None, help="Repository root path")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    return parser


def summary_rank(summary: dict[str, Any]) -> int:
    """Rank summary provenance consistently with the telemetry report."""
    token_source = summary.get("token_source")
    if token_source == "process_log":
        return 2
    if token_source == "state_fallback":
        return 0
    accurate_legacy_fields = (
        summary.get("input_tokens"),
        summary.get("cache_read_tokens"),
        summary.get("total_nano_aiu"),
    )
    return 2 if any(accurate_legacy_fields) else 0


def summary_timestamp(summary: dict[str, Any]) -> str:
    """Return the timestamp used to compare cumulative summary freshness."""
    value = summary.get("last_ts") or summary.get("ts") or ""
    return value if isinstance(value, str) else ""


def load_session_summaries(
    telemetry_dir: Path,
) -> tuple[dict[str, dict[str, Any]], ScanDiagnostics]:
    """Load one best cumulative SessionSummary per session id."""
    diagnostics = ScanDiagnostics()
    selected: dict[str, tuple[int, str, int, dict[str, Any]]] = {}
    if not telemetry_dir.exists():
        return {}, diagnostics
    if not telemetry_dir.is_dir():
        raise CostEstimatorError(f"Telemetry path is not a directory: {telemetry_dir.name}")

    order = 0
    for path in sorted(telemetry_dir.glob("sessions-*.jsonl")):
        diagnostics.files_scanned += 1
        try:
            handle = path.open(encoding="utf-8", errors="replace")
        except OSError:
            diagnostics.unreadable_files += 1
            continue
        with handle:
            try:
                for line in handle:
                    if not line.strip():
                        continue
                    try:
                        record = json.loads(line)
                    except ValueError:
                        diagnostics.malformed_records += 1
                        continue
                    if not isinstance(record, dict):
                        diagnostics.malformed_records += 1
                        continue
                    diagnostics.records_read += 1
                    if record.get("event") != "SessionSummary":
                        continue
                    diagnostics.summary_records += 1
                    sid = record.get("sid")
                    if not isinstance(sid, str) or not sid:
                        diagnostics.ignored_summaries += 1
                        continue

                    order += 1
                    candidate = (summary_rank(record), summary_timestamp(record), order, record)
                    current = selected.get(sid)
                    if current is not None:
                        diagnostics.superseded_summaries += 1
                    if current is None or candidate[:3] >= current[:3]:
                        selected[sid] = candidate
            except OSError:
                diagnostics.unreadable_files += 1

    return {sid: candidate[3] for sid, candidate in selected.items()}, diagnostics


def as_nonnegative_int(value: Any, default: int | None = None) -> int | None:
    """Return an integer token counter or the supplied default when invalid."""
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return value if value >= 0 else default
    if not isinstance(value, float):
        return default
    if not math.isfinite(value) or value < 0 or not value.is_integer():
        return default
    return int(value)


def measurement_from_mapping(mapping: dict[str, Any]) -> TokenMeasurement | None:
    """Normalize a telemetry token mapping into one complete measurement."""
    input_tokens = as_nonnegative_int(mapping.get("input_tokens"))
    output_tokens = as_nonnegative_int(mapping.get("output_tokens"))
    if input_tokens is None or output_tokens is None:
        return None

    cache_read = as_nonnegative_int(mapping.get("cache_read_tokens"), 0) or 0
    cache_write = as_nonnegative_int(mapping.get("cache_write_tokens"), 0) or 0
    requests = as_nonnegative_int(
        mapping.get("requests", mapping.get("messages", 0)),
        0,
    ) or 0
    fresh_input = as_nonnegative_int(mapping.get("input_tokens_uncached"))
    if fresh_input is None:
        fresh_input = max(input_tokens - cache_read - cache_write, 0)

    return TokenMeasurement(
        input_tokens=input_tokens,
        fresh_input_tokens=fresh_input,
        output_tokens=output_tokens,
        total_tokens=input_tokens + output_tokens,
        cache_read_tokens=cache_read,
        cache_write_tokens=cache_write,
        requests=requests,
    )


def combine_measurements(
    first: TokenMeasurement,
    second: TokenMeasurement,
) -> TokenMeasurement:
    """Combine same-session measurements that resolve to one agent label."""
    return TokenMeasurement(
        input_tokens=first.input_tokens + second.input_tokens,
        fresh_input_tokens=first.fresh_input_tokens + second.fresh_input_tokens,
        output_tokens=first.output_tokens + second.output_tokens,
        total_tokens=first.total_tokens + second.total_tokens,
        cache_read_tokens=first.cache_read_tokens + second.cache_read_tokens,
        cache_write_tokens=first.cache_write_tokens + second.cache_write_tokens,
        requests=first.requests + second.requests,
    )


def measurement_to_mapping(measurement: TokenMeasurement) -> dict[str, int]:
    """Convert a normalized measurement to the telemetry usage shape."""
    return {
        "input_tokens": measurement.input_tokens,
        "input_tokens_uncached": measurement.fresh_input_tokens,
        "output_tokens": measurement.output_tokens,
        "cache_read_tokens": measurement.cache_read_tokens,
        "cache_write_tokens": measurement.cache_write_tokens,
        "requests": measurement.requests,
    }


def merge_usage_mapping(target: dict[str, Any], source: dict[str, Any]) -> None:
    """Add canonical token counters from one usage mapping into another."""
    required_fields = ("input_tokens", "output_tokens")
    optional_fields = ("cache_read_tokens", "cache_write_tokens", "requests", "messages")
    for field in required_fields:
        target_value = as_nonnegative_int(target.get(field))
        source_value = as_nonnegative_int(source.get(field))
        target[field] = (
            target_value + source_value
            if target_value is not None and source_value is not None
            else None
        )
    for field in optional_fields:
        target[field] = (as_nonnegative_int(target.get(field), 0) or 0) + (
            as_nonnegative_int(source.get(field), 0) or 0
        )
    target_uncached = as_nonnegative_int(target.get("input_tokens_uncached"))
    source_uncached = as_nonnegative_int(source.get("input_tokens_uncached"))
    if target_uncached is not None and source_uncached is not None:
        target["input_tokens_uncached"] = target_uncached + source_uncached
    else:
        target.pop("input_tokens_uncached", None)


def merge_model_usage(target: dict[str, Any], source: dict[str, Any]) -> None:
    """Merge per-model usage buckets from a child summary."""
    for model, source_usage in source.items():
        if not isinstance(model, str) or not isinstance(source_usage, dict):
            continue
        target_usage = target.setdefault(model, {})
        if isinstance(target_usage, dict):
            merge_usage_mapping(target_usage, source_usage)


def merge_subagent_summaries(
    summaries: dict[str, dict[str, Any]],
    diagnostics: ScanDiagnostics,
) -> dict[str, dict[str, Any]]:
    """Collapse linked child summaries into their parent workflow summaries."""
    merged = copy.deepcopy(summaries)
    children_by_parent: dict[str, list[tuple[str, str]]] = {}
    parent_by_child: dict[str, str] = {}
    represented_by_parent: dict[str, set[str]] = {}

    for parent_sid, summary in merged.items():
        agent_usage = summary.get("agent_usage")
        agent_labels = agent_usage if isinstance(agent_usage, dict) else {}
        represented_by_parent[parent_sid] = {
            normalize_name(label)
            for label in agent_labels
            if isinstance(label, str)
        }
        subagent_map = summary.get("subagent_map")
        if not isinstance(subagent_map, dict):
            continue
        for child_sid, label in subagent_map.items():
            if not isinstance(child_sid, str) or not isinstance(label, str) or not label:
                diagnostics.unresolved_subagent_sessions += 1
                continue
            existing_parent = parent_by_child.get(child_sid)
            if existing_parent and existing_parent != parent_sid:
                diagnostics.unresolved_subagent_sessions += 1
                continue
            parent_by_child[child_sid] = parent_sid
            children_by_parent.setdefault(parent_sid, []).append((child_sid, label))

    visiting: set[str] = set()
    visited: set[str] = set()

    def merge_children(parent_sid: str) -> None:
        if parent_sid in visited:
            return
        if parent_sid in visiting:
            diagnostics.unresolved_subagent_sessions += 1
            return
        visiting.add(parent_sid)
        parent = merged.get(parent_sid)
        if parent is None:
            visiting.remove(parent_sid)
            return
        for child_sid, label in children_by_parent.get(parent_sid, []):
            if child_sid in visiting:
                diagnostics.unresolved_subagent_sessions += 1
                continue
            merge_children(child_sid)
            child = merged.get(child_sid)
            if child is None:
                diagnostics.unresolved_subagent_sessions += 1
                continue

            represented = normalize_name(label) in represented_by_parent.get(parent_sid, set())
            child_measurement = measurement_from_mapping(child)
            if not represented and child_measurement is not None:
                merge_usage_mapping(parent, child)
                parent_model_usage = parent.setdefault("model_usage", {})
                child_model_usage = child.get("model_usage")
                if isinstance(parent_model_usage, dict) and isinstance(child_model_usage, dict):
                    merge_model_usage(parent_model_usage, child_model_usage)
                parent_agent_usage = parent.setdefault("agent_usage", {})
                if isinstance(parent_agent_usage, dict):
                    existing_usage = parent_agent_usage.get(label)
                    if isinstance(existing_usage, dict):
                        merge_usage_mapping(
                            existing_usage,
                            measurement_to_mapping(child_measurement),
                        )
                    else:
                        parent_agent_usage[label] = measurement_to_mapping(child_measurement)
            del merged[child_sid]
            diagnostics.merged_subagent_sessions += 1
        visiting.remove(parent_sid)
        visited.add(parent_sid)

    for sid in list(merged):
        if sid not in parent_by_child:
            merge_children(sid)
    for sid in list(merged):
        merge_children(sid)
    return merged


def percentile(values: list[int], percentile_value: float) -> int:
    """Calculate an inclusive linear percentile, rounded up conservatively."""
    if not values:
        raise ValueError("percentile requires at least one value")
    if not 0 <= percentile_value <= 1:
        raise ValueError("percentile must be between 0 and 1")
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * percentile_value
    lower_index = math.floor(position)
    upper_index = math.ceil(position)
    if lower_index == upper_index:
        return ordered[lower_index]
    fraction = position - lower_index
    interpolated = ordered[lower_index] + (
        ordered[upper_index] - ordered[lower_index]
    ) * fraction
    return math.ceil(interpolated)


def summarize_measurements(
    measurements: list[TokenMeasurement], minimum_samples: int
) -> dict[str, Any]:
    """Build quality-labeled p50 and guarded p90 statistics."""
    metric_names = (
        "input_tokens",
        "fresh_input_tokens",
        "output_tokens",
        "total_tokens",
        "cache_read_tokens",
        "cache_write_tokens",
        "requests",
    )
    p50 = {
        name: percentile([getattr(item, name) for item in measurements], 0.50)
        for name in metric_names
    }
    p90 = None
    quality = "sparse"
    if len(measurements) >= minimum_samples:
        quality = "sufficient"
        p90 = {
            name: percentile([getattr(item, name) for item in measurements], 0.90)
            for name in metric_names
        }
    return {
        "sample_count": len(measurements),
        "quality": quality,
        "p50": p50,
        "p90": p90,
    }


def summarize_groups(
    groups: dict[str, list[TokenMeasurement]], minimum_samples: int, label_key: str
) -> list[dict[str, Any]]:
    """Summarize named measurement groups in deterministic order."""
    return [
        {label_key: label, **summarize_measurements(groups[label], minimum_samples)}
        for label in sorted(groups, key=lambda item: (normalize_name(item), item))
    ]


def aggregate_summaries(
    summaries: dict[str, dict[str, Any]],
    diagnostics: ScanDiagnostics,
    minimum_samples: int,
) -> tuple[dict[str, Any] | None, list[dict[str, Any]], list[dict[str, Any]]]:
    """Aggregate independent session, agent, and model priors."""
    session_measurements: list[TokenMeasurement] = []
    agent_groups: dict[str, list[TokenMeasurement]] = {}
    model_groups: dict[str, list[TokenMeasurement]] = {}

    for sid in sorted(summaries):
        summary = summaries[sid]
        session_measurement = measurement_from_mapping(summary)
        if session_measurement is None:
            diagnostics.invalid_measurements += 1
        else:
            session_measurements.append(session_measurement)

        agent_usage = summary.get("agent_usage")
        root_agent = summary.get("gen_ai.agent.name") or summary.get("root_agent")
        if not isinstance(root_agent, str) or not root_agent.strip():
            root_agent = ""
        session_agent_measurements: dict[str, TokenMeasurement] = {}
        if root_agent and session_measurement is not None:
            session_agent_measurements[root_agent] = session_measurement
        if isinstance(agent_usage, dict):
            for label, raw_usage in agent_usage.items():
                if not isinstance(label, str) or not label or not isinstance(raw_usage, dict):
                    diagnostics.invalid_measurements += 1
                    continue
                measurement = measurement_from_mapping(raw_usage)
                if measurement is None:
                    diagnostics.invalid_measurements += 1
                    continue
                if root_agent and (
                    label == "root" or normalize_name(label) == normalize_name(root_agent)
                ):
                    continue
                resolved_label = label
                current = session_agent_measurements.get(resolved_label)
                session_agent_measurements[resolved_label] = (
                    combine_measurements(current, measurement) if current else measurement
                )
        if not session_agent_measurements and session_measurement is not None:
            session_agent_measurements[root_agent or "root"] = session_measurement
        for label, measurement in session_agent_measurements.items():
            agent_groups.setdefault(label, []).append(measurement)

        model_usage = summary.get("model_usage")
        valid_model_measurements = 0
        had_model_usage = isinstance(model_usage, dict) and bool(model_usage)
        if isinstance(model_usage, dict):
            for label, raw_usage in model_usage.items():
                if not isinstance(label, str) or not label or not isinstance(raw_usage, dict):
                    diagnostics.invalid_measurements += 1
                    continue
                measurement = measurement_from_mapping(raw_usage)
                if measurement is None:
                    diagnostics.invalid_measurements += 1
                    continue
                model_groups.setdefault(label, []).append(measurement)
                valid_model_measurements += 1
        if (
            valid_model_measurements == 0
            and not had_model_usage
            and session_measurement is not None
        ):
            models = summary.get("models")
            labels = list(models) if isinstance(models, dict) else []
            if len(labels) == 1 and isinstance(labels[0], str) and labels[0]:
                model_groups.setdefault(labels[0], []).append(session_measurement)
            elif not labels:
                model_groups.setdefault("unknown", []).append(session_measurement)
            else:
                diagnostics.unattributed_model_sessions += 1

    session_prior = (
        summarize_measurements(session_measurements, minimum_samples)
        if session_measurements
        else None
    )
    return (
        session_prior,
        summarize_groups(agent_groups, minimum_samples, "agent"),
        summarize_groups(model_groups, minimum_samples, "model"),
    )


def find_group(groups: list[dict[str, Any]], key: str, value: str) -> dict[str, Any] | None:
    """Find a group using normalized display-name matching."""
    normalized = normalize_name(value)
    return next(
        (group for group in groups if normalize_name(str(group.get(key, ""))) == normalized),
        None,
    )


def diagnostics_to_dict(
    diagnostics: ScanDiagnostics, selected_sessions: int
) -> dict[str, int]:
    """Convert scan diagnostics to a stable JSON shape."""
    return {
        "files_scanned": diagnostics.files_scanned,
        "records_read": diagnostics.records_read,
        "malformed_records": diagnostics.malformed_records,
        "summary_records": diagnostics.summary_records,
        "selected_sessions": selected_sessions,
        "ignored_summaries": diagnostics.ignored_summaries,
        "superseded_summaries": diagnostics.superseded_summaries,
        "unreadable_files": diagnostics.unreadable_files,
        "invalid_measurements": diagnostics.invalid_measurements,
        "unattributed_model_sessions": diagnostics.unattributed_model_sessions,
        "merged_subagent_sessions": diagnostics.merged_subagent_sessions,
        "unresolved_subagent_sessions": diagnostics.unresolved_subagent_sessions,
    }


def build_priors_result(
    repo_root: Path,
    telemetry_dir: Path,
    agent: str,
    phase: str | None,
    model: str | None,
    encoding: str | None,
    minimum_samples: int,
) -> dict[str, Any]:
    """Build historical priors plus a conservative selected forecast."""
    if minimum_samples < 1:
        raise CostEstimatorError("Minimum samples must be at least 1")

    summaries, diagnostics = load_session_summaries(telemetry_dir)
    summaries = merge_subagent_summaries(summaries, diagnostics)
    session_prior, by_agent, by_model = aggregate_summaries(
        summaries,
        diagnostics,
        minimum_samples,
    )
    historical_prior = find_group(by_agent, "agent", agent)
    model_prior = find_group(by_model, "model", model) if model else None
    static_result = build_static_result(agent, phase, repo_root, encoding, model)
    static_floor = static_to_serializable(static_result)

    if historical_prior and historical_prior["sample_count"] >= minimum_samples:
        source = "historical_p90"
        estimated_tokens = historical_prior["p90"]["total_tokens"]
        reason = "The requested agent has enough attributable local history."
    else:
        source = "static_floor"
        estimated_tokens = static_result.estimated_tokens
        if historical_prior:
            reason = (
                f"Only {historical_prior['sample_count']} attributable sample(s) are available; "
                f"{minimum_samples} are required for p90."
            )
        else:
            reason = (
                "No attributable history matches the requested agent. Older or mixed-agent "
                "sessions may remain grouped as root."
            )

    return {
        "schema_version": 1,
        "minimum_samples": minimum_samples,
        "percentile_method": PERCENTILE_METHOD,
        "telemetry": diagnostics_to_dict(diagnostics, len(summaries)),
        "session_prior": session_prior,
        "by_agent": by_agent,
        "by_model": by_model,
        "forecast": {
            "agent": agent,
            "phase": phase,
            "model": model,
            "source": source,
            "estimated_tokens": estimated_tokens,
            "reason": reason,
            "historical_prior": historical_prior,
            "model_prior": model_prior,
            "static_floor": static_floor,
        },
        "limitations": [
            "Telemetry is opt-in, local, and may be sparse or incomplete.",
            "Older and mixed-agent summaries without one gen_ai.agent.name remain grouped as root.",
            "Agent and model priors are independent because telemetry does not record "
            "their intersection.",
            "Historical totals are heuristics, not guaranteed future usage or billing estimates.",
        ],
    }


def write_output(result: dict[str, Any], output_path: Path, output_format: str) -> None:
    """Persist deterministic JSON and print the requested representation."""
    payload = json.dumps(result, indent=2) + "\n"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(payload, encoding="utf-8")
    if output_format == "json":
        print(payload, end="")
        return

    forecast = result["forecast"]
    historical = forecast["historical_prior"]
    summary_lines = [
        f"Agent: {forecast['agent']}",
        f"Phase: {forecast['phase'] or 'n/a'}",
        f"Model: {forecast['model'] or 'n/a'}",
        f"Selected source: {forecast['source']}",
        f"Estimated tokens: {forecast['estimated_tokens']}",
        f"Attributable samples: {historical['sample_count'] if historical else 0}",
        f"Minimum samples: {result['minimum_samples']}",
        f"Sessions analyzed: {result['telemetry']['selected_sessions']}",
        f"Reason: {forecast['reason']}",
    ]
    print("\n".join(summary_lines))


def main(argv: list[str] | None = None) -> int:
    """Run the historical-priors CLI."""
    parser = create_parser()
    args = parser.parse_args(argv)
    try:
        repo_root = args.repo_root.resolve() if args.repo_root else Path.cwd().resolve()
        telemetry_dir = args.telemetry_dir or Path(".copilot-tracking/telemetry")
        if not telemetry_dir.is_absolute():
            telemetry_dir = repo_root / telemetry_dir
        result = build_priors_result(
            repo_root=repo_root,
            telemetry_dir=telemetry_dir.resolve(),
            agent=args.agent,
            phase=args.phase,
            model=args.model,
            encoding=args.encoding,
            minimum_samples=args.minimum_samples,
        )
        phase_suffix = f"-{sanitize_filename(args.phase)}" if args.phase else ""
        output_name = f"{sanitize_filename(args.agent)}{phase_suffix}-priors.json"
        write_output(result, repo_root / "logs" / "cost" / output_name, args.format)
    except CostEstimatorError as error:
        print(f"Error: {error}", file=sys.stderr)
        return error.exit_code
    except Exception as error:  # pragma: no cover - defensive boundary
        print(f"Error: {error}", file=sys.stderr)
        return EXIT_FAILURE
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
