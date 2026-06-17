#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../devcontainer/Test-DevcontainerLockfile.ps1')
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1') -Force

    $script:FixturesPath = Join-Path $PSScriptRoot '../fixtures/Devcontainer'

    Mock Write-Host {}
    Mock Write-CIAnnotation {}
}

Describe 'Test-LockfileExists' -Tag 'Unit' {
    Context 'when lockfile exists' {
        It 'Returns Passed true' {
            $lockDir = Join-Path $TestDrive '.devcontainer'
            New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
            '{}' | Set-Content -Path (Join-Path $lockDir 'devcontainer-lock.json')

            $result = Test-LockfileExists -RepoRoot $TestDrive

            $result.Passed | Should -BeTrue
        }
    }

    Context 'when lockfile is missing' {
        It 'Returns Passed false' {
            $result = Test-LockfileExists -RepoRoot $TestDrive

            $result.Passed | Should -BeFalse
        }
    }
}

Describe 'Test-FeatureIntegrity' -Tag 'Unit' {
    Context 'when all features have valid integrity' {
        It 'Returns Passed true with no violations' {
            $lockfile = Join-Path $script:FixturesPath 'valid-lock.json'

            $result = Test-FeatureIntegrity -LockfilePath $lockfile

            $result.Passed | Should -BeTrue
            $result.Violations | Should -HaveCount 0
        }
    }

    Context 'when feature is missing integrity' {
        It 'Returns violation for missing integrity' {
            $lockfile = Join-Path $script:FixturesPath 'missing-integrity-lock.json'

            $result = Test-FeatureIntegrity -LockfilePath $lockfile

            $result.Passed | Should -BeFalse
            $result.Violations | Should -HaveCount 1
        }
    }

    Context 'when feature is missing resolved' {
        It 'Returns violation for missing resolved' {
            $lockfile = Join-Path $script:FixturesPath 'missing-resolved-lock.json'

            $result = Test-FeatureIntegrity -LockfilePath $lockfile

            $result.Passed | Should -BeFalse
            $result.Violations.Count | Should -BeGreaterThan 0
        }
    }

    Context 'when integrity has wrong prefix' {
        It 'Returns violation for non-sha256 hash' {
            $lockfile = Join-Path $script:FixturesPath 'wrong-hash-lock.json'

            $result = Test-FeatureIntegrity -LockfilePath $lockfile

            $result.Passed | Should -BeFalse
        }
    }

    Context 'when features object is empty' {
        It 'Returns Passed true' {
            $lockfile = Join-Path $script:FixturesPath 'empty-features-lock.json'

            $result = Test-FeatureIntegrity -LockfilePath $lockfile

            $result.Passed | Should -BeTrue
        }
    }
}

Describe 'Test-FeatureCoverage' -Tag 'Unit' {
    Context 'when all config features are in lockfile' {
        It 'Returns Passed true' {
            $lockfile = Join-Path $script:FixturesPath 'valid-lock.json'
            $config = Join-Path $script:FixturesPath 'valid-config.json'

            $result = Test-FeatureCoverage -LockfilePath $lockfile -ConfigPath $config

            $result.Passed | Should -BeTrue
            $result.MissingKeys | Should -HaveCount 0
        }
    }

    Context 'when config has extra features' {
        It 'Returns MissingKeys containing the extra feature' {
            $lockfile = Join-Path $script:FixturesPath 'valid-lock.json'
            $config = Join-Path $script:FixturesPath 'extra-config-features.json'

            $result = Test-FeatureCoverage -LockfilePath $lockfile -ConfigPath $config

            $result.Passed | Should -BeFalse
            $result.MissingKeys | Should -Contain 'ghcr.io/devcontainers/features/go:1'
        }
    }

    Context 'when both have empty features' {
        It 'Returns Passed true' {
            $lockfile = Join-Path $script:FixturesPath 'empty-features-lock.json'
            $config = Join-Path $script:FixturesPath 'empty-features-config.json'

            $result = Test-FeatureCoverage -LockfilePath $lockfile -ConfigPath $config

            $result.Passed | Should -BeTrue
        }
    }

    Context 'when comparison is case-insensitive' {
        It 'Matches features regardless of case' {
            $lockDir = Join-Path $TestDrive 'case-test'
            New-Item -ItemType Directory -Path $lockDir -Force | Out-Null

            $lockContent = @{
                features = @{
                    'ghcr.io/devcontainers/features/Node:1' = @{
                        resolved  = 'ghcr.io/devcontainers/features/node@sha256:abc123'
                        integrity = 'sha256:abc123'
                    }
                }
            } | ConvertTo-Json -Depth 5
            $lockPath = Join-Path $lockDir 'lock.json'
            $lockContent | Set-Content -Path $lockPath

            $configContent = @{
                features = @{
                    'ghcr.io/devcontainers/features/node:1' = @{}
                }
            } | ConvertTo-Json -Depth 5
            $configPath = Join-Path $lockDir 'config.json'
            $configContent | Set-Content -Path $configPath

            $result = Test-FeatureCoverage -LockfilePath $lockPath -ConfigPath $configPath

            $result.Passed | Should -BeTrue
        }
    }
}

Describe 'Invoke-LockfileValidation' -Tag 'Unit' {
    Context 'when all checks pass' {
        It 'Returns FailedChecks 0' {
            $devDir = Join-Path $TestDrive '.devcontainer'
            New-Item -ItemType Directory -Path $devDir -Force | Out-Null

            $lockContent = Get-Content -Path (Join-Path $script:FixturesPath 'valid-lock.json') -Raw
            $lockContent | Set-Content -Path (Join-Path $devDir 'devcontainer-lock.json')

            $configContent = Get-Content -Path (Join-Path $script:FixturesPath 'valid-config.json') -Raw
            $configContent | Set-Content -Path (Join-Path $devDir 'devcontainer.json')

            $result = Invoke-LockfileValidation -RepoRoot $TestDrive

            $result.FailedChecks | Should -Be 0
        }
    }

    Context 'when lockfile is missing' {
        It 'Returns FailedChecks greater than 0' {
            $devDir = Join-Path $TestDrive '.devcontainer'
            New-Item -ItemType Directory -Path $devDir -Force | Out-Null

            $configContent = Get-Content -Path (Join-Path $script:FixturesPath 'valid-config.json') -Raw
            $configContent | Set-Content -Path (Join-Path $devDir 'devcontainer.json')

            $result = Invoke-LockfileValidation -RepoRoot $TestDrive

            $result.FailedChecks | Should -BeGreaterThan 0
        }
    }

    Context 'when integrity violations exist' {
        It 'Calls Write-CIAnnotation' {
            $devDir = Join-Path $TestDrive '.devcontainer'
            New-Item -ItemType Directory -Path $devDir -Force | Out-Null

            $lockContent = Get-Content -Path (Join-Path $script:FixturesPath 'missing-integrity-lock.json') -Raw
            $lockContent | Set-Content -Path (Join-Path $devDir 'devcontainer-lock.json')

            $configContent = Get-Content -Path (Join-Path $script:FixturesPath 'valid-config.json') -Raw
            $configContent | Set-Content -Path (Join-Path $devDir 'devcontainer.json')

            Invoke-LockfileValidation -RepoRoot $TestDrive

            Should -Invoke Write-CIAnnotation -Times 1
        }
    }
}
