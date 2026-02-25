#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
using module ..\..\security\Modules\SecurityClasses.psm1

Describe 'DependencyViolation' -Tag 'Unit' {
    Context 'Default constructor' {
        It 'Initializes with empty Metadata hashtable' {
            $v = [DependencyViolation]::new()
            $v.Metadata | Should -BeOfType [hashtable]
            $v.Metadata.Count | Should -Be 0
        }

        It 'Has null/default string properties' {
            $v = [DependencyViolation]::new()
            $v.File | Should -BeNullOrEmpty
            $v.Name | Should -BeNullOrEmpty
            $v.Line | Should -Be 0
        }
    }

    Context 'Parameterized constructor' {
        BeforeAll {
            $script:violation = [DependencyViolation]::new(
                'workflow.yml', 10, 'github-actions', 'actions/checkout', 'High', 'Not SHA-pinned'
            )
        }

        It 'Sets File property' {
            $script:violation.File | Should -Be 'workflow.yml'
        }

        It 'Sets Line property' {
            $script:violation.Line | Should -Be 10
        }

        It 'Sets Type property' {
            $script:violation.Type | Should -Be 'github-actions'
        }

        It 'Sets Name property' {
            $script:violation.Name | Should -Be 'actions/checkout'
        }

        It 'Sets Severity property' {
            $script:violation.Severity | Should -Be 'High'
        }

        It 'Sets Description property' {
            $script:violation.Description | Should -Be 'Not SHA-pinned'
        }

        It 'Initializes Metadata as empty hashtable' {
            $script:violation.Metadata | Should -BeOfType [hashtable]
            $script:violation.Metadata.Count | Should -Be 0
        }
    }

    Context 'ViolationType ValidateSet' {
        It 'Accepts valid ViolationType values' -ForEach @(
            @{ Value = 'Unpinned' }
            @{ Value = 'Stale' }
            @{ Value = 'VersionMismatch' }
            @{ Value = 'MissingVersionComment' }
            @{ Value = 'MissingPermissions' }
            @{ Value = '' }
        ) {
            $v = [DependencyViolation]::new()
            $v.ViolationType = $Value
            $v.ViolationType | Should -Be $Value
        }

        It 'Rejects invalid ViolationType' {
            $v = [DependencyViolation]::new()
            { $v.ViolationType = 'InvalidType' } | Should -Throw
        }
    }
}

Describe 'ComplianceReport' -Tag 'Unit' {
    Context 'Default constructor' {
        BeforeAll {
            $script:report = [ComplianceReport]::new()
        }

        It 'Sets Timestamp to current time' {
            $script:report.Timestamp | Should -BeOfType [datetime]
            ($script:report.Timestamp - (Get-Date)).TotalSeconds | Should -BeLessThan 5
        }

        It 'Initializes empty Violations array' {
            $script:report.Violations | Should -HaveCount 0
        }

        It 'Initializes empty Summary hashtable' {
            $script:report.Summary | Should -BeOfType [hashtable]
        }

        It 'Initializes empty Metadata hashtable' {
            $script:report.Metadata | Should -BeOfType [hashtable]
        }
    }

    Context 'Parameterized constructor' {
        It 'Sets ScanPath' {
            $report = [ComplianceReport]::new('/repo')
            $report.ScanPath | Should -Be '/repo'
        }

        It 'Initializes collections' {
            $report = [ComplianceReport]::new('/repo')
            $report.Violations | Should -HaveCount 0
            $report.Summary | Should -BeOfType [hashtable]
            $report.Metadata | Should -BeOfType [hashtable]
        }
    }

    Context 'AddViolation' {
        It 'Appends violation and updates UnpinnedDependencies count' {
            $report = [ComplianceReport]::new('/repo')
            $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'desc')
            $report.AddViolation($v)
            $report.Violations | Should -HaveCount 1
            $report.UnpinnedDependencies | Should -Be 1
        }

        It 'Tracks multiple violations' {
            $report = [ComplianceReport]::new('/repo')
            $report.AddViolation([DependencyViolation]::new('a.yml', 1, 't', 'n1', 'High', 'd'))
            $report.AddViolation([DependencyViolation]::new('b.yml', 2, 't', 'n2', 'Low', 'd'))
            $report.Violations | Should -HaveCount 2
            $report.UnpinnedDependencies | Should -Be 2
        }
    }

    Context 'CalculateScore' {
        It 'Computes percentage when TotalDependencies > 0' {
            $report = [ComplianceReport]::new('/repo')
            $report.TotalDependencies = 10
            $report.PinnedDependencies = 8
            $report.CalculateScore()
            $report.ComplianceScore | Should -Be 80.0
        }

        It 'Returns 100 when TotalDependencies is zero' {
            $report = [ComplianceReport]::new('/repo')
            $report.TotalDependencies = 0
            $report.CalculateScore()
            $report.ComplianceScore | Should -Be 100.0
        }

        It 'Rounds to two decimal places' {
            $report = [ComplianceReport]::new('/repo')
            $report.TotalDependencies = 3
            $report.PinnedDependencies = 1
            $report.CalculateScore()
            $report.ComplianceScore | Should -Be 33.33
        }
    }

    Context 'ToHashtable' {
        BeforeAll {
            $script:report = [ComplianceReport]::new('/repo')
            $script:report.TotalFiles = 5
            $script:report.ScannedFiles = 3
            $script:report.TotalDependencies = 10
            $script:report.PinnedDependencies = 8
            $script:report.UnpinnedDependencies = 2
            $script:report.ComplianceScore = 80.0
            $script:ht = $script:report.ToHashtable()
        }

        It 'Returns hashtable with 11 keys' {
            $script:ht | Should -BeOfType [hashtable]
            $script:ht.Keys.Count | Should -Be 11
        }

        It 'Includes all expected keys' -ForEach @(
            @{ Key = 'ScanPath' }
            @{ Key = 'Timestamp' }
            @{ Key = 'TotalFiles' }
            @{ Key = 'ScannedFiles' }
            @{ Key = 'TotalDependencies' }
            @{ Key = 'PinnedDependencies' }
            @{ Key = 'UnpinnedDependencies' }
            @{ Key = 'ComplianceScore' }
            @{ Key = 'Violations' }
            @{ Key = 'Summary' }
            @{ Key = 'Metadata' }
        ) {
            $script:ht.ContainsKey($Key) | Should -BeTrue
        }

        It 'Formats Timestamp as ISO 8601 string' {
            $script:ht['Timestamp'] | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$'
        }

        It 'Preserves numeric values' {
            $script:ht['TotalFiles'] | Should -Be 5
            $script:ht['ComplianceScore'] | Should -Be 80.0
        }
    }
}
