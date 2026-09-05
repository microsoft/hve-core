// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { labelRegistry } from './labelRegistry';

export type PackageMaturity =
  | typeof labelRegistry.stable
  | typeof labelRegistry.preview
  | typeof labelRegistry.experimental;

export type PackageContentKind =
  | 'agents'
  | 'prompts'
  | 'instructions'
  | 'skills';

export interface PackageContentSummary {
  kind: PackageContentKind;
  label: string;
  count: number;
  href: string;
}

export interface PackageCardData {
  name: string;
  title: string;
  description: string;
  artifacts: number;
  contents: PackageContentSummary[];
  maturity: PackageMaturity;
  href: string;
}
