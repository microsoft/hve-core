#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Test-CopyrightHeaders.ps1 script
.DESCRIPTION
    Tests for copyright header validation script:
    - Files with valid headers
    - Files missing copyright line
    - Files missing SPDX line
    - Files with incorrect line positions
    - Parameter validation
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Test-CopyrightHeaders.ps1'
    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/CopyrightHeaders'
    $script:CIHelpersPath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'

    # Import modules for mocking
    Import-Module $script:CIHelpersPath -Force

    # Create test fixtures directory
    if (-not (Test-Path $script:FixturesPath)) {
        New-Item -ItemType Directory -Path $script:FixturesPath -Force | Out-Null
    }

    . $script:ScriptPath
}

AfterAll {
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
    # Cleanup test fixtures
    if (Test-Path $script:FixturesPath) {
        Remove-Item -Path $script:FixturesPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#region Test Fixtures Setup

Describe 'Test-CopyrightHeaders Test Fixtures' -Tag 'Setup' {
    BeforeAll {
        # Valid file with both headers
        $validContent = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Write-Host "Hello World"
"@

        # File missing copyright
        $missingCopyrightContent = @"
#!/usr/bin/env pwsh
# SPDX-License-Identifier: MIT

Write-Host "Hello World"
"@

        # File missing SPDX
        $missingSpdxContent = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.

Write-Host "Hello World"
"@

        # File missing both headers
        $missingBothContent = @"
#!/usr/bin/env pwsh

Write-Host "Hello World"
"@

        # Valid file with #Requires statement
        $validWithRequiresContent = @"
#!/usr/bin/env pwsh
#Requires -Version 7.0
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Write-Host "Hello World"
"@

        # Create fixture files
        Set-Content -Path (Join-Path $script:FixturesPath 'valid.ps1') -Value $validContent
        Set-Content -Path (Join-Path $script:FixturesPath 'missing-copyright.ps1') -Value $missingCopyrightContent
        Set-Content -Path (Join-Path $script:FixturesPath 'missing-spdx.ps1') -Value $missingSpdxContent
        Set-Content -Path (Join-Path $script:FixturesPath 'missing-both.ps1') -Value $missingBothContent
        Set-Content -Path (Join-Path $script:FixturesPath 'valid-with-requires.ps1') -Value $validWithRequiresContent
    }

    It 'Creates test fixture files' {
        Test-Path (Join-Path $script:FixturesPath 'valid.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:FixturesPath 'missing-copyright.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:FixturesPath 'missing-spdx.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:FixturesPath 'missing-both.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:FixturesPath 'valid-with-requires.ps1') | Should -BeTrue
    }
}

#endregion

#region Valid Header Tests

Describe 'Test-CopyrightHeaders Valid Files' -Tag 'Unit' {
    BeforeAll {
        # Ensure fixtures exist
        $validContent = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Write-Host "Hello World"
"@
        if (-not (Test-Path $script:FixturesPath)) {
            New-Item -ItemType Directory -Path $script:FixturesPath -Force | Out-Null
        }
        Set-Content -Path (Join-Path $script:FixturesPath 'valid.ps1') -Value $validContent
    }

    It 'Detects valid headers in file' {
        $outputPath = Join-Path $script:FixturesPath 'results.json'
        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('valid.ps1') -OutputPath $outputPath

        $results = Get-Content $outputPath | ConvertFrom-Json
        $validFile = $results.results | Where-Object { $_.file -like '*valid.ps1' }

        $validFile.hasCopyright | Should -BeTrue
        $validFile.hasSpdx | Should -BeTrue
        $validFile.valid | Should -BeTrue
    }

    It 'Handles files with #Requires statement' {
        $validWithRequiresContent = @"
#!/usr/bin/env pwsh
#Requires -Version 7.0
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Write-Host "Hello World"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'valid-with-requires.ps1') -Value $validWithRequiresContent

        $outputPath = Join-Path $script:FixturesPath 'results-requires.json'
        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('valid-with-requires.ps1') -OutputPath $outputPath

        $results = Get-Content $outputPath | ConvertFrom-Json
        $validFile = $results.results | Where-Object { $_.file -like '*valid-with-requires.ps1' }

        $validFile.valid | Should -BeTrue
    }
}

#endregion

#region Missing Header Tests

Describe 'Test-CopyrightHeaders Missing Headers' -Tag 'Unit' {
    BeforeAll {
        if (-not (Test-Path $script:FixturesPath)) {
            New-Item -ItemType Directory -Path $script:FixturesPath -Force | Out-Null
        }
    }

    It 'Detects missing copyright line' {
        $content = @"
#!/usr/bin/env pwsh
# SPDX-License-Identifier: MIT

Write-Host "Hello World"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'missing-copyright.ps1') -Value $content

        $outputPath = Join-Path $script:FixturesPath 'results-missing-copyright.json'
        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('missing-copyright.ps1') -OutputPath $outputPath

        $results = Get-Content $outputPath | ConvertFrom-Json
        $file = $results.results | Where-Object { $_.file -like '*missing-copyright.ps1' }

        $file.hasCopyright | Should -BeFalse
        $file.hasSpdx | Should -BeTrue
        $file.valid | Should -BeFalse
    }

    It 'Detects missing SPDX line' {
        $content = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.

Write-Host "Hello World"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'missing-spdx.ps1') -Value $content

        $outputPath = Join-Path $script:FixturesPath 'results-missing-spdx.json'
        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('missing-spdx.ps1') -OutputPath $outputPath

        $results = Get-Content $outputPath | ConvertFrom-Json
        $file = $results.results | Where-Object { $_.file -like '*missing-spdx.ps1' }

        $file.hasCopyright | Should -BeTrue
        $file.hasSpdx | Should -BeFalse
        $file.valid | Should -BeFalse
    }

    It 'Detects missing both headers' {
        $content = @"
#!/usr/bin/env pwsh

Write-Host "Hello World"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'missing-both.ps1') -Value $content

        $outputPath = Join-Path $script:FixturesPath 'results-missing-both.json'
        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('missing-both.ps1') -OutputPath $outputPath

        $results = Get-Content $outputPath | ConvertFrom-Json
        $file = $results.results | Where-Object { $_.file -like '*missing-both.ps1' }

        $file.hasCopyright | Should -BeFalse
        $file.hasSpdx | Should -BeFalse
        $file.valid | Should -BeFalse
    }

    It 'Detects headers at incorrect line positions (too late in file)' {
        # Headers appearing after line 15 should not be detected
        $content = @"
#!/usr/bin/env pwsh
# Line 2
# Line 3
# Line 4
# Line 5
# Line 6
# Line 7
# Line 8
# Line 9
# Line 10
# Line 11
# Line 12
# Line 13
# Line 14
# Line 15
# Line 16
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Write-Host "Headers too late"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'headers-too-late.ps1') -Value $content

        $outputPath = Join-Path $script:FixturesPath 'results-headers-too-late.json'
        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('headers-too-late.ps1') -OutputPath $outputPath

        $results = Get-Content $outputPath | ConvertFrom-Json
        $file = $results.results | Where-Object { $_.file -like '*headers-too-late.ps1' }

        # Headers should NOT be found because they're past line 15
        $file.hasCopyright | Should -BeFalse
        $file.hasSpdx | Should -BeFalse
        $file.valid | Should -BeFalse
    }
}

#endregion

#region Parameter Tests

Describe 'Test-CopyrightHeaders Parameters' -Tag 'Unit' {
    It 'Accepts Path parameter' {
        { Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -OutputPath (Join-Path $script:FixturesPath 'test.json') } | Should -Not -Throw
    }

    It 'Accepts FileExtensions parameter' {
        { Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('*.ps1') -OutputPath (Join-Path $script:FixturesPath 'test.json') } | Should -Not -Throw
    }

    It 'Accepts ExcludePaths parameter' {
        { Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -ExcludePaths @('node_modules') -OutputPath (Join-Path $script:FixturesPath 'test.json') } | Should -Not -Throw
    }

    It 'Throws with FailOnMissing when files missing headers' {
        $content = @"
#!/usr/bin/env pwsh
Write-Host "No headers"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'no-headers.ps1') -Value $content

        { Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('no-headers.ps1') -OutputPath (Join-Path $script:FixturesPath 'fail-test.json') -FailOnMissing } | Should -Throw '*missing required headers*'
    }
}

#endregion

#region CI Annotation Tests

Describe 'Test-CopyrightHeaders CI Annotations' -Tag 'Unit' {
    BeforeAll {
        if (-not (Test-Path $script:FixturesPath)) {
            New-Item -ItemType Directory -Path $script:FixturesPath -Force | Out-Null
        }
    }

    BeforeEach {
        Mock Write-CIAnnotation {}
        Mock Write-CIStepSummary {}
    }

    It 'Calls Write-CIAnnotation for each failing file' {
        $missingBoth = @"
#!/usr/bin/env pwsh
Write-Host "No headers"
"@
        $missingSpdx = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
Write-Host "Missing SPDX"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-missing1.ps1') -Value $missingBoth
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-missing2.ps1') -Value $missingSpdx

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-missing1.ps1', 'ci-missing2.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-ann.json')

        Should -Invoke Write-CIAnnotation -Times 2 -Exactly
    }

    It 'Does not call Write-CIAnnotation for passing files' {
        $valid = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
Write-Host "Valid"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-valid.ps1') -Value $valid

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-valid.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-ann-valid.json')

        Should -Invoke Write-CIAnnotation -Times 0 -Exactly
    }

    It 'Annotation message includes missing header types' {
        $missingSpdx = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
Write-Host "Missing SPDX"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-spdx-only.ps1') -Value $missingSpdx

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-spdx-only.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-ann-spdx.json')

        Should -Invoke Write-CIAnnotation -Times 1 -Exactly -ParameterFilter {
            $Message -like '*SPDX*' -and $Level -eq 'Warning' -and
            $File -eq ([System.IO.Path]::GetFullPath((Join-Path $script:FixturesPath 'ci-spdx-only.ps1')))
        }
    }

    It 'Annotation message lists both header types when both missing' {
        $missingBoth = @"
#!/usr/bin/env pwsh
Write-Host "No headers"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-both-missing.ps1') -Value $missingBoth

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-both-missing.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-ann-both.json')

        Should -Invoke Write-CIAnnotation -Times 1 -Exactly -ParameterFilter {
            $Message -like '*copyright*' -and $Message -like '*SPDX*' -and $Level -eq 'Warning'
        }
    }

    It 'Annotation uses Warning level' {
        $missing = @"
#!/usr/bin/env pwsh
Write-Host "No headers"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-warn.ps1') -Value $missing

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-warn.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-ann-warn.json')

        Should -Invoke Write-CIAnnotation -Times 1 -Exactly -ParameterFilter {
            $Level -eq 'Warning' -and $Line -eq 1
        }
    }
}

#endregion

#region CI Step Summary Tests

Describe 'Test-CopyrightHeaders Step Summary' -Tag 'Unit' {
    BeforeAll {
        if (-not (Test-Path $script:FixturesPath)) {
            New-Item -ItemType Directory -Path $script:FixturesPath -Force | Out-Null
        }
    }

    BeforeEach {
        Mock Write-CIAnnotation {}
        Mock Write-CIStepSummary {}
    }

    It 'Calls Write-CIStepSummary when all files pass' {
        $valid = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
Write-Host "Valid"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-sum-valid.ps1') -Value $valid

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-sum-valid.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-sum-valid.json')

        Should -Invoke Write-CIStepSummary -Times 2 -Exactly
        Should -Invoke Write-CIStepSummary -Times 1 -Exactly -ParameterFilter {
            $Content -like '*Passed*'
        }
    }

    It 'Calls Write-CIStepSummary with failure table when files fail' {
        $missing = @"
#!/usr/bin/env pwsh
Write-Host "No headers"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-sum-fail.ps1') -Value $missing

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-sum-fail.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-sum-fail.json')

        Should -Invoke Write-CIStepSummary -Times 2 -Exactly
        Should -Invoke Write-CIStepSummary -Times 1 -Exactly -ParameterFilter {
            $Content -like '*Failed*' -and $Content -like '*Missing Headers*'
        }
    }

    It 'Summary contains compliance metrics' {
        $missing = @"
#!/usr/bin/env pwsh
Write-Host "No headers"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-sum-metrics.ps1') -Value $missing

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-sum-metrics.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-sum-metrics.json')

        Should -Invoke Write-CIStepSummary -Times 1 -Exactly -ParameterFilter {
            $Content -like '*Total Files*' -and $Content -like '*Compliance*'
        }
    }

    It 'Summary header always emitted' {
        $valid = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
Write-Host "Valid"
"@
        Set-Content -Path (Join-Path $script:FixturesPath 'ci-sum-header.ps1') -Value $valid

        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('ci-sum-header.ps1') -OutputPath (Join-Path $script:FixturesPath 'ci-sum-header.json')

        Should -Invoke Write-CIStepSummary -Times 1 -Exactly -ParameterFilter {
            $Content -like '*Copyright Header Validation*'
        }
    }
}

#endregion

#region Output Format Tests

Describe 'Test-CopyrightHeaders Output Format' -Tag 'Unit' {
    BeforeAll {
        $content = @"
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Write-Host "Test"
"@
        if (-not (Test-Path $script:FixturesPath)) {
            New-Item -ItemType Directory -Path $script:FixturesPath -Force | Out-Null
        }
        Set-Content -Path (Join-Path $script:FixturesPath 'output-test.ps1') -Value $content

        $script:OutputPath = Join-Path $script:FixturesPath 'output-format.json'
        Invoke-CopyrightHeaderCheck -Path $script:FixturesPath -FileExtensions @('output-test.ps1') -OutputPath $script:OutputPath
    }

    It 'Outputs valid JSON' {
        { Get-Content $script:OutputPath | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Contains required fields' {
        $results = Get-Content $script:OutputPath | ConvertFrom-Json

        $results.PSObject.Properties.Name | Should -Contain 'timestamp'
        $results.PSObject.Properties.Name | Should -Contain 'totalFiles'
        $results.PSObject.Properties.Name | Should -Contain 'filesWithHeaders'
        $results.PSObject.Properties.Name | Should -Contain 'filesMissingHeaders'
        $results.PSObject.Properties.Name | Should -Contain 'results'
    }

    It 'Contains compliance percentage' {
        $results = Get-Content $script:OutputPath | ConvertFrom-Json

        $results.PSObject.Properties.Name | Should -Contain 'compliancePercentage'
        $results.compliancePercentage | Should -BeOfType [double]
    }

    It 'Results contain file details' {
        $results = Get-Content $script:OutputPath | ConvertFrom-Json

        $results.results.Count | Should -BeGreaterThan 0
        $results.results[0].PSObject.Properties.Name | Should -Contain 'file'
        $results.results[0].PSObject.Properties.Name | Should -Contain 'hasCopyright'
        $results.results[0].PSObject.Properties.Name | Should -Contain 'hasSpdx'
        $results.results[0].PSObject.Properties.Name | Should -Contain 'valid'
    }
}

#endregion
