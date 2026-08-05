// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import type { PackageCardData } from '../../data/packageCards';

let packageCards: PackageCardData[] = [];

export function __setPackageCards(next: PackageCardData[]): void {
  packageCards = next;
}

export function __resetPackageCards(): void {
  packageCards = [];
}

export default function useDocusaurusContext() {
  return {
    siteConfig: {
      customFields: {
        packageCards,
      },
    },
  };
}
