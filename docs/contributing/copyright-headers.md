---
title: Copyright Header Guidelines
description: Standards for copyright and license headers in source files to meet OpenSSF Best Practices badge criteria
author: Microsoft
ms.date: 2026-01-31
ms.topic: reference
keywords:
  - copyright
  - license
  - SPDX
  - headers
  - OpenSSF
estimated_reading_time: 3
---

This document defines the copyright and license header format required for source files in the hve-core repository. Following these guidelines ensures compliance with [OpenSSF Best Practices](https://www.bestpractices.dev/en/criteria/2) Gold badge criteria for `copyright_per_file` and `license_per_file`.

## Overview

All source files in this repository must include a copyright and license header. We use the [SPDX License Identifier](https://spdx.org/licenses/) standard to provide machine-readable license information.

## Header Format by File Type

### Hash-style Comments (PowerShell, Bash, Python)

```text
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
```

Applies to: `.ps1`, `.sh`, `.py` files

### Slash-style Comments (C#, TypeScript, JavaScript)

```text
// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: MIT
```

Applies to: `.cs`, `.ts`, `.js` files

## Placement Rules

The header placement depends on the file type and any required directives:

### Shell Scripts (Bash)

Place the header **after** the shebang line:

```bash
#!/bin/bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Script content starts here
```

### PowerShell Scripts

Place the header **after** any `#Requires` statements:

```powershell
#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0" }
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Script content starts here
```

If no `#Requires` statements exist, place the header at the first line:

```powershell
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

param(
    [string]$Path
)
```

### Python Files

Place the header **after** the shebang (if present) and encoding declaration:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

"""Module docstring."""
```

If no shebang or encoding declaration exists, place at the first line:

```python
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

"""Module docstring."""
```

### C#, TypeScript, and JavaScript Files

Place the header at the **first lines** of the file:

```csharp
// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: MIT

namespace HveCore;
```

```typescript
// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: MIT

export class Example {
}
```

## References

- [SPDX License List](https://spdx.org/licenses/) - Standard license identifiers
- [SPDX License Identifier Specification](https://spdx.github.io/spdx-spec/v2.3/using-SPDX-short-identifiers-in-source-files/) - How to use SPDX identifiers in source files
- [OpenSSF Best Practices Badge Criteria](https://www.bestpractices.dev/en/criteria/2) - Gold level requirements
- [PowerShell/PowerShell header example](https://github.com/PowerShell/PowerShell/blob/master/tools/Sign-Package.ps1) - Reference implementation

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
