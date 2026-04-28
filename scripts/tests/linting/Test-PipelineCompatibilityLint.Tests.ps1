#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'Test-FsiPipelineCompatibility' -Tag 'Unit' {
    Context 'valid producer/consumer chain' {
        It 'reports no errors or warnings when consumer ids match prior producer ids' {
            $pipeline = @{
                stages = @(
                    @{ id = 'gather'; kind = 'gather'; produces = @(@{ id = 'raw'; kind = 'yaml' }) }
                    @{ id = 'render'; kind = 'render'; consumes = @('raw'); produces = @(@{ id = 'doc'; kind = 'md' }) }
                )
            }
            $result = Test-FsiPipelineCompatibility -Pipeline $pipeline -Framework 'demo'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'mismatched consume id' {
        It 'emits an error when a consumed id was not produced by any prior stage' {
            $pipeline = @{
                stages = @(
                    @{ id = 'gather'; kind = 'gather'; produces = @(@{ id = 'raw'; kind = 'yaml' }) }
                    @{ id = 'render'; kind = 'render'; consumes = @('nonexistent') }
                )
            }
            $result = Test-FsiPipelineCompatibility -Pipeline $pipeline -Framework 'demo'
            $result.Errors.Count | Should -BeGreaterThan 0
            ($result.Errors -join "`n") | Should -Match 'nonexistent'
        }
    }

    Context 'first stage host-sourced consume' {
        It 'emits a warning (not an error) for host: prefixed consumes' {
            $pipeline = @{
                stages = @(
                    @{ id = 'gather'; kind = 'gather'; consumes = @('host:user-input'); produces = @(@{ id = 'raw'; kind = 'yaml' }) }
                )
            }
            $result = Test-FsiPipelineCompatibility -Pipeline $pipeline -Framework 'demo'
            $result.Errors | Should -HaveCount 0
            $result.Warnings.Count | Should -BeGreaterThan 0
            ($result.Warnings -join "`n") | Should -Match 'host:user-input'
        }
    }

    Context 'self-consume rejected' {
        It 'emits an error when a stage consumes its own produces id' {
            $pipeline = @{
                stages = @(
                    @{ id = 'one'; kind = 'mix'; consumes = @('self'); produces = @(@{ id = 'self'; kind = 'yaml' }) }
                )
            }
            $result = Test-FsiPipelineCompatibility -Pipeline $pipeline -Framework 'demo'
            $result.Errors.Count | Should -BeGreaterThan 0
        }
    }

    Context 'duplicate produces id across stages' {
        It 'emits an error when two stages produce the same id' {
            $pipeline = @{
                stages = @(
                    @{ id = 'a'; kind = 'gather'; produces = @(@{ id = 'shared'; kind = 'yaml' }) }
                    @{ id = 'b'; kind = 'gather'; produces = @(@{ id = 'shared'; kind = 'yaml' }) }
                )
            }
            $result = Test-FsiPipelineCompatibility -Pipeline $pipeline -Framework 'demo'
            $result.Errors.Count | Should -BeGreaterThan 0
            ($result.Errors -join "`n") | Should -Match 'duplicated'
        }
    }

    Context 'null pipeline' {
        It 'returns no errors or warnings when pipeline is $null' {
            $result = Test-FsiPipelineCompatibility -Pipeline $null -Framework 'demo'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }
}
