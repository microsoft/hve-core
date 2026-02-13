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
