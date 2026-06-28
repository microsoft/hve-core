#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-PrValidationGate.ps1')

    $script:FixturesPath = Join-Path $PSScriptRoot '../fixtures/pr-validation-gate'
    $script:CompleteGate = Join-Path $script:FixturesPath 'complete-gate.yml'
    $script:MissingJob = Join-Path $script:FixturesPath 'missing-job.yml'
    $script:StaleNeeds = Join-Path $script:FixturesPath 'stale-needs.yml'

    Mock Write-Host {}
}

Describe 'Get-PrValidationGateResult' -Tag 'Unit' {
    Context 'when the gate lists every non-gate job' {
        BeforeAll {
            $script:Result = Get-PrValidationGateResult -WorkflowPath $script:CompleteGate -GateJobId 'pr-validation-success'
        }

        It 'Reports the gate job as present' {
            $script:Result.GateJobPresent | Should -BeTrue
        }

        It 'Reports no missing jobs' {
            $script:Result.Missing | Should -BeNullOrEmpty
        }

        It 'Reports no stale needs entries' {
            $script:Result.Stale | Should -BeNullOrEmpty
        }
    }

    Context 'when a job is omitted from the gate needs' {
        BeforeAll {
            $script:Result = Get-PrValidationGateResult -WorkflowPath $script:MissingJob -GateJobId 'pr-validation-success'
        }

        It 'Reports the omitted job as missing' {
            $script:Result.Missing | Should -Contain 'build'
        }

        It 'Reports no stale needs entries' {
            $script:Result.Stale | Should -BeNullOrEmpty
        }
    }

    Context 'when a needs entry references a non-existent job' {
        BeforeAll {
            $script:Result = Get-PrValidationGateResult -WorkflowPath $script:StaleNeeds -GateJobId 'pr-validation-success'
        }

        It 'Reports the stale needs entry' {
            $script:Result.Stale | Should -Contain 'deleted-job'
        }

        It 'Reports no missing jobs' {
            $script:Result.Missing | Should -BeNullOrEmpty
        }
    }

    Context 'when the gate job is absent' {
        BeforeAll {
            $script:Result = Get-PrValidationGateResult -WorkflowPath $script:CompleteGate -GateJobId 'nonexistent-gate'
        }

        It 'Reports the gate job as not present' {
            $script:Result.GateJobPresent | Should -BeFalse
        }
    }
}

Describe 'Invoke-PrValidationGateCheck' -Tag 'Unit' {
    BeforeEach {
        $script:OutputPath = Join-Path $TestDrive 'pr-validation-gate-results.json'
    }

    Context 'when the gate is complete' {
        It 'Returns exit code 0' {
            $exitCode = Invoke-PrValidationGateCheck -WorkflowPath $script:CompleteGate -GateJobId 'pr-validation-success' -OutputPath $script:OutputPath -FailOnViolation
            $exitCode | Should -Be 0
        }

        It 'Writes a JSON results file' {
            Invoke-PrValidationGateCheck -WorkflowPath $script:CompleteGate -GateJobId 'pr-validation-success' -OutputPath $script:OutputPath | Out-Null
            Test-Path -Path $script:OutputPath | Should -BeTrue
            $json = Get-Content -Raw -Path $script:OutputPath | ConvertFrom-Json
            $json.violationCount | Should -Be 0
        }
    }

    Context 'when a job is missing from the gate needs' {
        It 'Returns exit code 1 under FailOnViolation' {
            $exitCode = Invoke-PrValidationGateCheck -WorkflowPath $script:MissingJob -GateJobId 'pr-validation-success' -OutputPath $script:OutputPath -FailOnViolation
            $exitCode | Should -Be 1
        }

        It 'Returns exit code 0 in soft-fail mode' {
            $exitCode = Invoke-PrValidationGateCheck -WorkflowPath $script:MissingJob -GateJobId 'pr-validation-success' -OutputPath $script:OutputPath
            $exitCode | Should -Be 0
        }

        It 'Records the missing job in the JSON results' {
            Invoke-PrValidationGateCheck -WorkflowPath $script:MissingJob -GateJobId 'pr-validation-success' -OutputPath $script:OutputPath | Out-Null
            $json = Get-Content -Raw -Path $script:OutputPath | ConvertFrom-Json
            $json.missing | Should -Contain 'build'
        }
    }

    Context 'when a needs entry is stale' {
        It 'Returns exit code 1 under FailOnViolation' {
            $exitCode = Invoke-PrValidationGateCheck -WorkflowPath $script:StaleNeeds -GateJobId 'pr-validation-success' -OutputPath $script:OutputPath -FailOnViolation
            $exitCode | Should -Be 1
        }

        It 'Records the stale entry in the JSON results' {
            Invoke-PrValidationGateCheck -WorkflowPath $script:StaleNeeds -GateJobId 'pr-validation-success' -OutputPath $script:OutputPath | Out-Null
            $json = Get-Content -Raw -Path $script:OutputPath | ConvertFrom-Json
            $json.stale | Should -Contain 'deleted-job'
        }
    }

    Context 'when the gate job is absent' {
        It 'Returns exit code 1 even without FailOnViolation' {
            $exitCode = Invoke-PrValidationGateCheck -WorkflowPath $script:CompleteGate -GateJobId 'nonexistent-gate' -OutputPath $script:OutputPath
            $exitCode | Should -Be 1
        }
    }
}
