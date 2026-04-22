#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'ConvertFrom-Iso8601Duration' -Tag 'Unit' {
    It 'parses days' {
        (ConvertFrom-Iso8601Duration -Duration 'P180D').TotalDays | Should -Be 180
    }
    It 'parses weeks' {
        (ConvertFrom-Iso8601Duration -Duration 'P2W').TotalDays | Should -Be 14
    }
    It 'parses years/months mix' {
        (ConvertFrom-Iso8601Duration -Duration 'P1Y6M').TotalDays | Should -Be (365 + 180)
    }
    It 'returns $null on garbage' {
        ConvertFrom-Iso8601Duration -Duration 'not-a-duration' | Should -Be $null
    }
}

Describe 'Test-FsiGovernanceReviewCurrency' -Tag 'Unit' {
    Context 'absent governance block' {
        It 'returns no errors or warnings' {
            $manifest = @{ framework = 'demo' }
            $result = Test-FsiGovernanceReviewCurrency -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'review still current' {
        It 'returns no warnings when last_reviewed + cadence is in the future' {
            $manifest = @{
                governance = @{
                    owners         = @('@org/team')
                    review_cadence = 'P180D'
                    last_reviewed  = '2026-01-01'
                }
            }
            $now = [DateTime]::Parse('2026-04-21')
            $result = Test-FsiGovernanceReviewCurrency -Manifest $manifest -Framework 'demo' -Now $now
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'review overdue' {
        It 'warns when last_reviewed + cadence is before $Now' {
            $manifest = @{
                governance = @{
                    owners         = @('@org/team')
                    review_cadence = 'P30D'
                    last_reviewed  = '2026-01-01'
                }
            }
            $now = [DateTime]::Parse('2026-04-21')
            $result = Test-FsiGovernanceReviewCurrency -Manifest $manifest -Framework 'demo' -Now $now
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'overdue'
        }
    }

    Context 'cadence without last_reviewed' {
        It 'warns about missing last_reviewed' {
            $manifest = @{
                governance = @{
                    owners         = @('@org/team')
                    review_cadence = 'P180D'
                }
            }
            $result = Test-FsiGovernanceReviewCurrency -Manifest $manifest -Framework 'demo'
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'last_reviewed required'
        }
    }

    Context 'unparseable cadence' {
        It 'warns when review_cadence cannot be parsed' {
            $manifest = @{
                governance = @{
                    owners         = @('@org/team')
                    review_cadence = 'not-a-duration'
                    last_reviewed  = '2026-01-01'
                }
            }
            $result = Test-FsiGovernanceReviewCurrency -Manifest $manifest -Framework 'demo'
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'not a parseable ISO 8601 duration'
        }
    }
}
