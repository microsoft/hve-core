# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from runtime_a11y.matrix._build import build_matrix
from runtime_a11y.matrix._coverage import compute_coverage
from runtime_a11y.matrix._merge import merge_updates
from runtime_a11y.matrix._model import CandidateUpdate, Cell, Criterion, Matrix, Surface

__all__ = [
    "CandidateUpdate",
    "Cell",
    "Criterion",
    "Matrix",
    "Surface",
    "build_matrix",
    "compute_coverage",
    "merge_updates",
]
