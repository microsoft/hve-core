---
description: 'Temporary test file for WSL symlink verification — safe to delete'
---

# WSL Symlink Verification Test

This file exists solely to test whether a NEW plugin link created on Windows
(text stub, staged as mode 100644) resolves correctly when checked out on Linux/WSL.

If this file appears as a symlink on WSL, the cross-platform fix works end-to-end.
If it appears as a plain text file containing a relative path, there is a gap.
