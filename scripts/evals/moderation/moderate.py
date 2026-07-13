#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Content moderation CLI using Detoxify toxicity classifier.

Reads JSON-lines input containing text records, classifies each via Detoxify,
and writes structured JSON output with per-record scores and an overall summary.
Exits with code 1 when any record exceeds the toxicity threshold.
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any, Literal

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

logger = logging.getLogger(__name__)


def create_parser() -> argparse.ArgumentParser:
    """Create and configure argument parser."""
    parser = argparse.ArgumentParser(
        description="Moderate text content using Detoxify toxicity classifier",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument(
        "--input",
        type=Path,
        help="Path to JSON-lines input file with {id, text} records",
    )
    input_group.add_argument(
        "--stdin",
        action="store_true",
        help="Read JSON-lines input from stdin",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.5,
        help="Toxicity threshold (0.0-1.0); scores above this trigger a flag (default: 0.5)",
    )
    parser.add_argument(
        "--model",
        type=str,
        choices=["original", "unbiased", "multilingual"],
        default="unbiased",
        help="Detoxify model variant (default: unbiased)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Path to write structured JSON output",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose logging",
    )
    return parser


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def load_records(input_path: Path | None) -> list[dict[str, Any]]:
    """Load JSON-lines records from file or stdin."""
    records = []
    source = sys.stdin if input_path is None else input_path.open(encoding="utf-8")
    try:
        for line_num, line in enumerate(source, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
                if not isinstance(record, dict):
                    logger.warning("Line %d: expected object, got %s", line_num, type(record).__name__)
                    continue
                if "id" not in record or "text" not in record:
                    logger.warning("Line %d: missing required fields (id, text)", line_num)
                    continue
                if not isinstance(record["text"], str):
                    logger.warning("Line %d: 'text' must be a string, got %s", line_num, type(record["text"]).__name__)
                    continue
                records.append(record)
            except json.JSONDecodeError as e:
                logger.warning("Line %d: JSON parse error: %s", line_num, e)
    finally:
        if input_path is not None:
            source.close()
    logger.info("Loaded %d records", len(records))
    return records


def classify_records(
    records: list[dict[str, Any]],
    model_name: Literal["original", "unbiased", "multilingual"],
    threshold: float,
) -> list[dict[str, Any]]:
    """Classify records using Detoxify and return results with flag status."""
    try:
        from detoxify import Detoxify
    except ImportError as exc:
        raise ImportError("detoxify package not installed; run: uv pip install -r requirements.txt") from exc

    logger.info("Loading Detoxify model: %s", model_name)
    model = Detoxify(model_name)

    results = []
    for record in records:
        record_id = record["id"]
        text = record["text"]
        record_threshold = float(record.get("threshold", threshold))
        if record_threshold < 0.0 or record_threshold > 1.0:
            raise ValueError(f"Record {record_id}: threshold must be between 0.0 and 1.0")
        logger.debug("Classifying record: %s", record_id)

        scores = model.predict(text)
        # Convert numpy types to native Python floats
        scores = {k: float(v) for k, v in scores.items()}

        flagged_labels = [label for label, score in scores.items() if score > record_threshold]
        flagged = len(flagged_labels) > 0

        results.append(
            {
                "id": record_id,
                "threshold": record_threshold,
                "scores": scores,
                "flagged": flagged,
                "flaggedLabels": flagged_labels,
            }
        )
        if flagged:
            logger.warning(
                "Record %s FLAGGED: %s",
                record_id,
                ", ".join(f"{label}={scores[label]:.3f}" for label in flagged_labels),
            )

    return results


def write_output(results: list[dict[str, Any]], output_path: Path) -> None:
    """Write structured JSON output with per-record results and summary."""
    flagged_count = sum(1 for r in results if r["flagged"])
    output = {
        "records": results,
        "summary": {
            "total": len(results),
            "flaggedCount": flagged_count,
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, indent=2), encoding="utf-8")
    logger.info("Wrote output to %s", output_path)


def main() -> int:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args()
    configure_logging(args.verbose)

    if args.threshold < 0.0 or args.threshold > 1.0:
        logger.error("Threshold must be between 0.0 and 1.0")
        return EXIT_ERROR

    input_path = args.input
    records = load_records(input_path)
    if not records:
        logger.warning("No records to process")
        write_output([], args.output)
        return EXIT_SUCCESS

    try:
        results = classify_records(records, args.model, args.threshold)
    except (ImportError, ValueError) as exc:
        logger.error("%s", exc)
        return EXIT_ERROR
    write_output(results, args.output)

    flagged_count = sum(1 for r in results if r["flagged"])
    if flagged_count > 0:
        logger.error("Content moderation failed: %d/%d records flagged", flagged_count, len(results))
        return EXIT_FAILURE

    logger.info("Content moderation passed: all %d records clean", len(results))
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
