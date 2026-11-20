#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Pester tests for Test-DocHubCompleteness.ps1 script
.DESCRIPTION
    Tests for the doc hub completeness validator:
    - Per-hub artifact discovery and README substring matching
    - Detection of missing entries, duplicate basenames, and dt-method-* exclusions
    - CI integration (annotations, JSON output, step summary, CI outputs)
    - Repository integration (guard passes against current repo state)
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Test-DocHubCompleteness.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'
    $script:CIHelpersPath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'

    Import-Module $script:ModulePath -Force
    Import-Module $script:CIHelpersPath -Force

    . $script:ScriptPath

    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("doc-hub-tests-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:TestRoot | Out-Null

    function New-TestHubDefinition {
        param(
            [string]$Name = 'instructions',
            [string]$ArtifactRoot = '.github/instructions',
            [string]$ArtifactFilter = '*.instructions.md',
            [string]$ReadmePath = '.github/instructions/README.md',
            $ExcludePattern = $null
        )
        [pscustomobject]@{
            Name           = $Name
            ArtifactRoot   = $ArtifactRoot
            ArtifactFilter = $ArtifactFilter
            ReadmePath     = $ReadmePath
            ExcludePattern = $ExcludePattern
        }
    }

    function New-TestHubFixture {
        param(
            [string]$RepoRoot,
            [string]$Hub,
            [string]$ArtifactRelativePath,
            [AllowEmptyString()]
            [string]$ReadmeContent
        )

        $hubRoot = switch ($Hub) {
            'instructions' { '.github/instructions' }
            'prompts'      { '.github/prompts' }
            default        { throw "Unknown hub: $Hub" }
        }

        $artifactPath = Join-Path $RepoRoot $hubRoot $ArtifactRelativePath
        New-Item -ItemType Directory -Path (Split-Path -Path $artifactPath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $artifactPath -Value '# Fixture' -Encoding utf8NoBOM

        $readmePath = Join-Path $RepoRoot $hubRoot 'README.md'
        New-Item -ItemType Directory -Path (Split-Path -Path $readmePath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $readmePath -Value $ReadmeContent -Encoding utf8NoBOM
    }
}

AfterAll {
    if ($script:TestRoot -and (Test-Path $script:TestRoot)) {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

#region Get-HubArtifact Tests

Describe 'Get-HubArtifact' -Tag 'Unit' {
    BeforeEach {
        $script:CaseDir = Join-Path $script:TestRoot ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:CaseDir | Out-Null
    }

    It 'Returns artifacts with correct Name and RelativePath' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'coding-standards/bash/bash.instructions.md' `
            -ReadmeContent '# Instructions'

        $hubDef = New-TestHubDefinition
        $artifacts = Get-HubArtifact -RepoRoot $repo -HubDefinition $hubDef

        $artifacts | Should -HaveCount 1
        $artifacts[0].Name | Should -Be 'bash.instructions.md'
        $artifacts[0].RelativePath | Should -Be '.github/instructions/coding-standards/bash/bash.instructions.md'
    }

    It 'Excludes artifacts matching the ExcludePattern' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'prompts' `
            -ArtifactRelativePath 'dt-start-project.prompt.md' `
            -ReadmeContent '# Prompts'

        $dtMethodPath = Join-Path $repo '.github/prompts/dt-method-04-test.prompt.md'
        New-Item -ItemType Directory -Path (Split-Path -Path $dtMethodPath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $dtMethodPath -Value '# Fixture' -Encoding utf8NoBOM

        $hubDef = New-TestHubDefinition -Name 'prompts' -ArtifactRoot '.github/prompts' -ArtifactFilter '*.prompt.md' -ReadmePath '.github/prompts/README.md' -ExcludePattern 'dt-method-*'
        $artifacts = Get-HubArtifact -RepoRoot $repo -HubDefinition $hubDef

        $artifacts | Should -HaveCount 1
        $artifacts[0].Name | Should -Be 'dt-start-project.prompt.md'
    }

    It 'Returns empty list when artifact root does not exist' {
        $hubDef = New-TestHubDefinition
        $artifacts = Get-HubArtifact -RepoRoot $script:CaseDir -HubDefinition $hubDef
        $artifacts | Should -HaveCount 0
    }
}


#region Test-HubCompleteness Tests

Describe 'Test-HubCompleteness' -Tag 'Unit' {
    BeforeEach {
        $script:CaseDir = Join-Path $script:TestRoot ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:CaseDir | Out-Null
    }

    It 'Passes when an artifact is referenced in the hub README' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'bash.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [bash](bash.instructions.md)`n"

        $hubDef = New-TestHubDefinition
        $result = Test-HubCompleteness -RepoRoot $repo -HubDefinition $hubDef

        $result.TotalChecked | Should -Be 1
        $result.Missing | Should -HaveCount 0
        $result.ReadmeMissing | Should -BeFalse
    }

    It 'Reports a missing artifact when not referenced in the README' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'rust.instructions.md' `
            -ReadmeContent "# Instructions`n`nOnly bash listed.`n"

        $hubDef = New-TestHubDefinition
        $result = Test-HubCompleteness -RepoRoot $repo -HubDefinition $hubDef

        $result.TotalChecked | Should -Be 1
        $result.Missing | Should -HaveCount 1
        $result.Missing[0].FileName | Should -Be 'rust.instructions.md'
    }

    It 'Returns ReadmeMissing when the README does not exist' {
        $repo = $script:CaseDir
        $artifactPath = Join-Path $repo '.github/instructions/bash.instructions.md'
        New-Item -ItemType Directory -Path (Split-Path -Path $artifactPath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $artifactPath -Value '# Fixture' -Encoding utf8NoBOM

        $hubDef = New-TestHubDefinition
        $result = Test-HubCompleteness -RepoRoot $repo -HubDefinition $hubDef

        $result.ReadmeMissing | Should -BeTrue
        $result.Issue | Should -Not -BeNullOrEmpty
    }

    It 'Returns empty results when artifact root does not exist' {
        $hubDef = New-TestHubDefinition
        $result = Test-HubCompleteness -RepoRoot $script:CaseDir -HubDefinition $hubDef

        $result.TotalChecked | Should -Be 0
        $result.Missing | Should -HaveCount 0
        $result.ReadmeMissing | Should -BeFalse
    }

    It 'Detects duplicate basenames within the hub' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'pull-request.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [pr](pull-request.instructions.md)`n"

        $dupPath = Join-Path $repo '.github/instructions/hve-core/pull-request.instructions.md'
        New-Item -ItemType Directory -Path (Split-Path -Path $dupPath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $dupPath -Value '# Fixture' -Encoding utf8NoBOM

        $hubDef = New-TestHubDefinition
        $result = Test-HubCompleteness -RepoRoot $repo -HubDefinition $hubDef

        $result.TotalChecked | Should -Be 2
        $result.Duplicates | Should -HaveCount 1
        $result.Duplicates[0].FileName | Should -Be 'pull-request.instructions.md'
        $result.Duplicates[0].Paths | Should -HaveCount 2
    }
}

#endregion

#region Test-DocHubCompleteness Tests

Describe 'Test-DocHubCompleteness' -Tag 'Unit' {
    BeforeEach {
        $script:CaseDir = Join-Path $script:TestRoot ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:CaseDir | Out-Null
    }

    It 'Passes when every instruction artifact is referenced in the hub README' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'coding-standards/bash/bash.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [bash](coding-standards/bash/bash.instructions.md)`n"

        $result = Test-DocHubCompleteness -RepoRoot $repo

        $result.Passed | Should -BeTrue
        $result.TotalChecked | Should -Be 1
        $result.MissingArtifacts | Should -HaveCount 0
    }

    It 'Fails when an instruction artifact is not referenced in the hub README' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'coding-standards/rust/rust.instructions.md' `
            -ReadmeContent "# Instructions`n`nOnly bash is listed here.`n"

        $result = Test-DocHubCompleteness -RepoRoot $repo

        $result.Passed | Should -BeFalse
        $result.MissingArtifacts | Should -HaveCount 1
        $result.MissingArtifacts[0].FileName | Should -Be 'rust.instructions.md'
        $result.MissingArtifacts[0].Hub | Should -Be 'instructions'
        ($result.Issues -join "`n") | Should -Match 'rust\.instructions\.md'
    }

    It 'Excludes dt-method-* prompts from the prompts hub check' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'prompts' `
            -ArtifactRelativePath 'design-thinking/dt-start-project.prompt.md' `
            -ReadmeContent "# Prompts`n`n- [DT Start](design-thinking/dt-start-project.prompt.md)`n`n> Note: dt-method-* prompts are summarized here.`n"

        $dtMethodPath = Join-Path $repo '.github/prompts/design-thinking/dt-method-04-empathy-mapping.prompt.md'
        New-Item -ItemType Directory -Path (Split-Path -Path $dtMethodPath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $dtMethodPath -Value '# Fixture' -Encoding utf8NoBOM

        $result = Test-DocHubCompleteness -RepoRoot $repo

        $result.Passed | Should -BeTrue
        $result.TotalChecked | Should -Be 1
        $result.ExcludedCount | Should -Be 1
        $result.MissingArtifacts | Should -HaveCount 0
    }

    It 'Passes when a prompt artifact filename appears in path text, not just markdown links' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'prompts' `
            -ArtifactRelativePath 'hve-core/task-research.prompt.md' `
            -ReadmeContent "# Prompts`n`nDirectory tree excerpt:`n.github/prompts/hve-core/task-research.prompt.md`n"

        $result = Test-DocHubCompleteness -RepoRoot $repo

        $result.Passed | Should -BeTrue
        $result.TotalChecked | Should -Be 1
    }

    It 'Fails when the hub README is empty and artifacts exist' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'coding-standards/bash/bash.instructions.md' `
            -ReadmeContent ''

        $result = Test-DocHubCompleteness -RepoRoot $repo

        $result.Passed | Should -BeFalse
        $result.MissingArtifacts | Should -HaveCount 1
        $result.MissingArtifacts[0].FileName | Should -Be 'bash.instructions.md'
    }

    It 'Passes when a hub has a README but no artifacts' {
        $repo = $script:CaseDir
        $readmeDir = Join-Path $repo '.github/instructions'
        New-Item -ItemType Directory -Path $readmeDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $readmeDir 'README.md') -Value '# Instructions' -Encoding utf8NoBOM

        $result = Test-DocHubCompleteness -RepoRoot $repo

        $result.Passed | Should -BeTrue
        $result.TotalChecked | Should -Be 0
        $result.MissingArtifacts | Should -HaveCount 0
    }

    It 'Detects duplicate basenames within a hub without failing' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'pull-request.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [pull-request](pull-request.instructions.md)`n"

        $dupPath = Join-Path $repo '.github/instructions/hve-core/pull-request.instructions.md'
        New-Item -ItemType Directory -Path (Split-Path -Path $dupPath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $dupPath -Value '# Fixture' -Encoding utf8NoBOM

        $result = Test-DocHubCompleteness -RepoRoot $repo

        $result.Passed | Should -BeTrue
        $result.MissingArtifacts | Should -HaveCount 0
        $result.DuplicateBasenames | Should -HaveCount 1
        $result.DuplicateBasenames[0].FileName | Should -Be 'pull-request.instructions.md'
        $result.DuplicateBasenames[0].Paths | Should -HaveCount 2
    }

    It 'Throws when RepoRoot does not exist' {
        $nonExistent = Join-Path $script:TestRoot 'does-not-exist'
        { Test-DocHubCompleteness -RepoRoot $nonExistent } | Should -Throw
    }

    It 'Runs Git lookup from the RepoRoot directory, not the caller current directory'{
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions'`
        -ArtifactRelativePath 'bash.instructions.md'`
        -ReadmeContent "# Instructions `n`n- [bash](bash.instructions.md)`n"

        $script:CapturedLocation = $null
        Mock Get-ChangedFilesFromGit {
            $script:CapturedLocation = (Get-Location).path
            return @('.github/instructions/bash.instructions.md')
        }

        $otherDir = Join-Path $script:TestRoot 'other-Location'
        New-Item -ItemType Directory -Force -Path $otherDir | Out-Null
        Push-Location $otherDir
        try {
            $result = Test-DocHubCompleteness -RepoRoot $repo -ChangedFilesOnly
        }
        finally {
            Pop-Location
        }

        $script:CapturedLocation | Should -Be $repo
        $result.TotalChecked | Should -Be 1
    }

    It "Normalize a relative RepoRoot before the Git lookup" {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions'`
        -ArtifactRelativePath 'bash.instructions.md'`
        -ReadmeContent "#Instructions `n`n-[bash](bash.instructions.md)`n"

        $script:CapturedLocation = $null
        Mock Get-ChangedFilesFromGit {
            $script:CapturedLocation = (Get-Location).path
            return @('.github/instructions/bash.instructions.md')
        }

        Push-Location $repo
        try {
            $result = Test-DocHubCompleteness -RepoRoot '.' -ChangedFilesOnly
        }
        finally {
            Pop-Location
        }
        $script:CapturedLocation | Should -Be $repo
        $result.TotalChecked | Should -Be 1
    }
}


#region Invoke-DocHubCompletenessCore Tests

Describe 'Invoke-DocHubCompletenessCore' -Tag 'Unit' {
    BeforeEach {
        Mock Set-CIOutput {}
        Mock Set-CIEnv {}
        Mock Write-CIStepSummary {}
        Mock Write-CIAnnotation {}

        $script:CaseDir = Join-Path $script:TestRoot ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:CaseDir | Out-Null
        $script:Output = Join-Path $script:CaseDir 'doc-hub-results.json'
    }

    It 'Does not throw when all artifacts are referenced in their hub READMEs' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'bash.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [bash](bash.instructions.md)`n"

        { Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $script:Output } | Should -Not -Throw
    }

    It 'Throws when an artifact is not referenced in the hub README' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'rust.instructions.md' `
            -ReadmeContent "# Instructions`n`nOnly bash listed.`n"

        { Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $script:Output } | Should -Throw
    }

    It 'Does not throw when there are no artifacts to check' {
        $repo = $script:CaseDir
        $readmeDir = Join-Path $repo '.github/instructions'
        New-Item -ItemType Directory -Path $readmeDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $readmeDir 'README.md') -Value '# Instructions' -Encoding utf8NoBOM

        { Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $script:Output } | Should -Not -Throw
    }

    It 'Creates the OutputPath parent directory when missing' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'bash.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [bash](bash.instructions.md)`n"

        $nestedOutput = Join-Path $repo 'nested/sub/dir/results.json'
        { Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $nestedOutput } | Should -Not -Throw
        Test-Path (Split-Path $nestedOutput -Parent) | Should -BeTrue
    }

    It 'Writes JSON results file with summary and findings' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'bash.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [bash](bash.instructions.md)`n"

        Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $script:Output

        Test-Path $script:Output | Should -BeTrue
        $json = Get-Content -LiteralPath $script:Output -Raw | ConvertFrom-Json
        $json.Summary.Passed | Should -BeTrue
        $json.Summary.TotalChecked | Should -Be 1
        $json.MissingArtifacts | Should -HaveCount 0
    }

    It 'Emits a CI annotation with Error level for each missing artifact' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'rust.instructions.md' `
            -ReadmeContent "# Instructions`n`nOnly bash listed.`n"

        { Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $script:Output } | Should -Throw
        Should -Invoke Write-CIAnnotation -ParameterFilter { $Level -eq 'Error' } -Times 1
    }

    It 'Sets CI outputs for count and passed status' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'bash.instructions.md' `
            -ReadmeContent "# Instructions`n`n- [bash](bash.instructions.md)`n"

        Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $script:Output

        Should -Invoke Set-CIOutput -ParameterFilter { $Name -eq 'count' } -Times 1
        Should -Invoke Set-CIOutput -ParameterFilter { $Name -eq 'passed' } -Times 1
    }

    It 'Sets failure env var when artifacts are missing' {
        $repo = $script:CaseDir
        New-TestHubFixture -RepoRoot $repo -Hub 'instructions' `
            -ArtifactRelativePath 'rust.instructions.md' `
            -ReadmeContent "# Instructions`n`nOnly bash listed.`n"

        { Invoke-DocHubCompletenessCore -RepoRoot $repo -OutputPath $script:Output } | Should -Throw
        Should -Invoke Set-CIEnv -ParameterFilter { $Name -eq 'DOC_HUB_COMPLETENESS_FAILED' } -Times 1
    }
}


#region Repository Hub Completeness Tests

Describe 'Repository hub completeness' -Tag 'Integration' {
    It 'All instruction and prompt artifacts are referenced in their hub READMEs' {
        $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path

        $result = Test-DocHubCompleteness -RepoRoot $repoRoot

        $result.Passed | Should -BeTrue
        $result.MissingArtifacts | Should -HaveCount 0
        $result.TotalChecked | Should -BeGreaterThan 0
    }
}

#endregion
