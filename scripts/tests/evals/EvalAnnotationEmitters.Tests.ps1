#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:EvalsRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../evals')).Path
    $script:SourceFiles = @(Get-ChildItem -Path $script:EvalsRoot -Recurse -File -Include '*.ps1', '*.psm1')
    $script:RawEmitterPattern = '["'']\s*::(error|warning|notice)\b'
}

Describe 'Eval workflow-command emitters' -Tag 'Unit' {
    It 'Scans both scripts and modules, including the moderation module' {
        $script:SourceFiles.Name | Should -Contain 'Invoke-VallyEvals.ps1'
        $script:SourceFiles.Name | Should -Contain 'ModerationRunner.psm1'
    }

    It 'Routes every workflow-command annotation through Write-CIAnnotation' {
        $violations = foreach ($file in $script:SourceFiles) {
            Select-String -LiteralPath $file.FullName -Pattern $script:RawEmitterPattern |
                Where-Object { $_.Line -notmatch '^\s*#' } |
                ForEach-Object {
                    '{0}:{1}: {2}' -f $file.FullName.Substring($script:EvalsRoot.Length + 1), $_.LineNumber, $_.Line.Trim()
                }
        }
        $violations | Should -BeNullOrEmpty -Because 'raw workflow commands bypass the property and message encoding in Write-CIAnnotation'
    }
}
