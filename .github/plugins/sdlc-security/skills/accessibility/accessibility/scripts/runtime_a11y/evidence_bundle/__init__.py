# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Product-neutral accessibility evidence bundle composition."""

from runtime_a11y.evidence_bundle._canonical import canonical_digest, canonical_json
from runtime_a11y.evidence_bundle._compose import compose_evidence
from runtime_a11y.evidence_bundle._validate import validate_document

__all__ = [
    "canonical_digest",
    "canonical_json",
    "compose_evidence",
    "validate_document",
]
