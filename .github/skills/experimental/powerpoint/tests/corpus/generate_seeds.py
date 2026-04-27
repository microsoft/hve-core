# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Generate corpus seeds for fuzz targets."""

import os

CORPUS_DIR = os.path.dirname(__file__)


def write_seed(name, data: bytes):
    """Write raw bytes to corpus file."""
    with open(os.path.join(CORPUS_DIR, name), "wb") as f:
        f.write(data)
    print(f"Created: {name} ({len(data)} bytes)")


if __name__ == "__main__":
    # ------------------------------------------------------------------
    # Seeds for fuzz_has_formatting_variation (target index = 3)
    # Format: [target_index_byte] + random payload
    # ------------------------------------------------------------------

    # 1. Basic small input
    write_seed("3_basic", b"\x03\x01\x00")

    # 2. Underline variation hint
    write_seed("3_underline_var", b"\x03\x02\x01\x00\x01\x00")

    # 3. Size variation hint
    write_seed("3_size_var", b"\x03\x02\x10\x20\x30\x40\x50")

    # 4. Color variation hint
    write_seed("3_color_var", b"\x03\xff\x00\xff\x00")

    # 5. Large mixed input (better exploration)
    write_seed("3_large_mix", b"\x03" + bytes(range(50)))

    # 6. Edge case: empty-like
    write_seed("3_empty", b"\x03")

    # 7. All bytes high (stress case)
    write_seed("3_high", b"\x03" + b"\xff" * 20)

    print("\n✅ All seeds generated!")
