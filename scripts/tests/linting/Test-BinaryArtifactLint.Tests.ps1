#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'Test-FsiBinaryArtifactContract' -Tag 'Unit' {
    Context 'binary producers with declared cleanup' {
        It 'returns no warnings when every binary producer declares cleanup' {
            $pipeline = @{
                stages = @(
                    @{ id = 'render'; kind = 'render'; produces = @(
                        @{ id = 'deck'; kind = 'binary/docx'; cleanup = 'ephemeral' }
                    ) }
                )
            }
            $result = Test-FsiBinaryArtifactContract -Pipeline $pipeline -Framework 'demo'
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'binary producer missing cleanup' {
        It 'emits a single warning identifying the framework, stage, produce id, and kind' {
            $pipeline = @{
                stages = @(
                    @{ id = 'render'; kind = 'render'; produces = @(
                        @{ id = 'report'; kind = 'binary/pdf' }
                    ) }
                )
            }
            $result = Test-FsiBinaryArtifactContract -Pipeline $pipeline -Framework 'demo'
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'demo'
            $result.Warnings[0] | Should -Match 'render'
            $result.Warnings[0] | Should -Match 'report'
            $result.Warnings[0] | Should -Match 'binary/pdf'
            $result.Warnings[0] | Should -Match 'cleanup'
        }
    }

    Context 'non-binary producers' {
        It 'does not warn on markdown or other non-binary kinds missing cleanup' {
            $pipeline = @{
                stages = @(
                    @{ id = 'render'; kind = 'render'; produces = @(
                        @{ id = 'doc'; kind = 'markdown' }
                        @{ id = 'data'; kind = 'yaml' }
                    ) }
                )
            }
            $result = Test-FsiBinaryArtifactContract -Pipeline $pipeline -Framework 'demo'
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'pipeline with no produces' {
        It 'returns no warnings when stages have only consumes' {
            $pipeline = @{
                stages = @(
                    @{ id = 'gather'; kind = 'gather'; consumes = @('host:input') }
                )
            }
            $result = Test-FsiBinaryArtifactContract -Pipeline $pipeline -Framework 'demo'
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'pipeline with no stages' {
        It 'returns no warnings when the stages key is absent' {
            $pipeline = @{}
            $result = Test-FsiBinaryArtifactContract -Pipeline $pipeline -Framework 'demo'
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'mixed binary producers' {
        It 'emits exactly one warning per binary producer missing cleanup' {
            $pipeline = @{
                stages = @(
                    @{ id = 'one'; kind = 'render'; produces = @(
                        @{ id = 'a'; kind = 'binary/docx' }
                        @{ id = 'b'; kind = 'binary/pdf'; cleanup = 'retained' }
                    ) }
                    @{ id = 'two'; kind = 'render'; produces = @(
                        @{ id = 'c'; kind = 'binary/png' }
                    ) }
                )
            }
            $result = Test-FsiBinaryArtifactContract -Pipeline $pipeline -Framework 'demo'
            $result.Warnings | Should -HaveCount 2
        }
    }
}
