// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { labelRegistry } from './labelRegistry';

export type PackageMaturity =
  | typeof labelRegistry.stable
  | typeof labelRegistry.preview
  | typeof labelRegistry.experimental;

export interface PackageCardData {
  name: string;
  title: string;
  description: string;
  artifacts: number;
  maturity: PackageMaturity;
  href: string;
}

export type PackageMaturityResolution =
  | { kind: 'active'; maturity: PackageMaturity }
  | { kind: 'retired' }
  | { kind: 'unsupported' };

const activeMaturityLabels = new Map<string, PackageMaturity>([
  ['stable', labelRegistry.stable],
  ['preview', labelRegistry.preview],
  ['experimental', labelRegistry.experimental],
]);

const retiredMaturities = new Set(['deprecated', 'removed']);

export function resolvePackageMaturity(
  value: unknown,
): PackageMaturityResolution {
  const raw = value === undefined ? 'stable' : value;
  if (typeof raw !== 'string') {
    return { kind: 'unsupported' };
  }
  if (retiredMaturities.has(raw)) {
    return { kind: 'retired' };
  }
  const maturity = activeMaturityLabels.get(raw);
  return maturity ? { kind: 'active', maturity } : { kind: 'unsupported' };
}
