// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// @actions/workflow-parser imports its JSON schemas without an import
// attribute, which Node rejects. This resolve hook adds `type: "json"` to every
// .json module so the published package loads unmodified and without a bundler.
import { registerHooks } from 'node:module';

registerHooks({
  resolve(specifier, context, nextResolve) {
    const result = nextResolve(specifier, context);
    if (new URL(result.url).pathname.endsWith('.json')) {
      return { ...result, importAttributes: { ...(result.importAttributes ?? {}), type: 'json' } };
    }
    return result;
  },
});
