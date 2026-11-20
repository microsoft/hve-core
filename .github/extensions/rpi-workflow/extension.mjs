// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { registerRpiWorkflow } from '../hve-core/rpi-workflow/register.mjs';

// Use a separate ID so an installed plugin can also register its published canvas.
await registerRpiWorkflow({ preview: true });
