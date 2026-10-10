#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../evals/Test-VallyTestSafety.ps1')
}

Describe 'Write-VallyTestSafetyAnnotation' -Tag 'Unit' {
    BeforeEach {
        Mock Write-CIAnnotation {}
    }

    It 'Emits an error annotation with the match path, line, and flattened snippet' {
        $match = [pscustomobject]@{
            path         = 'evals/sample/stimuli.yml'
            lineNumber   = 7
            category     = 'sample-category'
            patternIndex = 2
            matchText    = "first line`nsecond line"
        }

        Write-VallyTestSafetyAnnotation -MatchList @($match)

        Should -Invoke Write-CIAnnotation -Times 1 -Exactly -ParameterFilter {
            $Level -eq 'Error' -and $File -eq 'evals/sample/stimuli.yml' -and $Line -eq 7 -and
            $Message -eq 'vally-test-safety: sample-category (pattern #2) match -> first line second line'
        }
    }
}
