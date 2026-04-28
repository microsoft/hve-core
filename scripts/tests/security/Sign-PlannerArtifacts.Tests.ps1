#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    # Stub cosign when not installed so Pester can mock it
    if (-not (Get-Command cosign -ErrorAction SilentlyContinue)) { function global:cosign { } }

    $script:ScriptPath = Join-Path $PSScriptRoot '../../security/Sign-PlannerArtifacts.ps1'

    # Extract helper functions via AST. The script has a mandatory ProjectSlug
    # parameter with script-scope execution, preventing dot-source.
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:ScriptPath, [ref]$null, [ref]$null)
    $ast.FindAll(
        { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true
    ) | ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }

    Mock Write-Host {}
}

Describe 'Get-ArtifactHash' -Tag 'Unit' {
    Context 'SHA-256 computation' {
        It 'Returns a lowercase hex SHA-256 hash for a file' {
            $testFile = Join-Path $TestDrive 'hash-test.txt'
            Set-Content -Path $testFile -Value 'deterministic content' -NoNewline -Encoding utf8NoBOM

            $hash = Get-ArtifactHash -FilePath $testFile

            $hash | Should -Match '^[0-9a-f]{64}$'
        }

        It 'Returns consistent hashes for identical content' {
            $file1 = Join-Path $TestDrive 'dup1.txt'
            $file2 = Join-Path $TestDrive 'dup2.txt'
            Set-Content -Path $file1 -Value 'same' -NoNewline -Encoding utf8NoBOM
            Set-Content -Path $file2 -Value 'same' -NoNewline -Encoding utf8NoBOM

            $hash1 = Get-ArtifactHash -FilePath $file1
            $hash2 = Get-ArtifactHash -FilePath $file2

            $hash1 | Should -Be $hash2
        }

        It 'Returns different hashes for different content' {
            $file1 = Join-Path $TestDrive 'diff1.txt'
            $file2 = Join-Path $TestDrive 'diff2.txt'
            Set-Content -Path $file1 -Value 'alpha' -NoNewline -Encoding utf8NoBOM
            Set-Content -Path $file2 -Value 'bravo' -NoNewline -Encoding utf8NoBOM

            $hash1 = Get-ArtifactHash -FilePath $file1
            $hash2 = Get-ArtifactHash -FilePath $file2

            $hash1 | Should -Not -Be $hash2
        }
    }
}

Describe 'Manifest Generation' -Tag 'Unit' {
    BeforeEach {
        $script:projectSlug = 'test-project'
        $script:artifactDir = Join-Path $TestDrive ".copilot-tracking/rai-plans/$($script:projectSlug)"
        if (Test-Path $script:artifactDir) { Remove-Item $script:artifactDir -Recurse -Force }
        New-Item -ItemType Directory -Path $script:artifactDir -Force | Out-Null
    }

    Context 'when artifact directory does not exist' {
        It 'Exits with code 1 for missing directory' {
            $missingSlug = 'nonexistent-project'
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $missingSlug
            }
            catch { $_ | Out-Null }
            finally {
                Set-Location $originalPWD
            }
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context 'when artifact directory is empty' {
        It 'Exits with code 0 and reports no artifacts' {
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            catch { $_ | Out-Null }
            finally {
                Set-Location $originalPWD
            }

            Should -Invoke Write-Host -ParameterFilter { $Object -like '*No artifacts found*' }
        }
    }

    Context 'when artifacts exist' {
        BeforeEach {
            Set-Content -Path (Join-Path $script:artifactDir 'state.json') -Value '{"status":"complete"}' -Encoding utf8NoBOM
            Set-Content -Path (Join-Path $script:artifactDir 'findings.md') -Value '# Findings' -Encoding utf8NoBOM
            $script:outputPath = Join-Path $script:artifactDir 'artifact-manifest.json'
        }

        It 'Generates a valid JSON manifest' {
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            Test-Path $script:outputPath | Should -BeTrue
            $manifest = Get-Content $script:outputPath -Raw | ConvertFrom-Json
            $manifest.version | Should -Be '1.0'
            $manifest.projectSlug | Should -Be $script:projectSlug
            $manifest.algorithm | Should -Be 'SHA256'
        }

        It 'Includes correct file count' {
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            $manifest = Get-Content $script:outputPath -Raw | ConvertFrom-Json
            $manifest.fileCount | Should -Be 2
            $manifest.artifacts.Count | Should -Be 2
        }

        It 'Computes SHA-256 hashes for each artifact' {
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            $manifest = Get-Content $script:outputPath -Raw | ConvertFrom-Json
            foreach ($artifact in $manifest.artifacts) {
                $artifact.sha256 | Should -Match '^[0-9a-f]{64}$'
                $artifact.path | Should -Not -BeNullOrEmpty
                $artifact.sizeBytes | Should -BeGreaterThan 0
            }
        }

        It 'Writes manifest to custom OutputPath when specified' {
            $customPath = Join-Path $TestDrive 'custom-manifest.json'

            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug -OutputPath $customPath
            }
            finally {
                Set-Location $originalPWD
            }

            Test-Path $customPath | Should -BeTrue
            $manifest = Get-Content $customPath -Raw | ConvertFrom-Json
            $manifest.fileCount | Should -Be 2
        }

        It 'Includes generatedAt in ISO 8601 format' {
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            $raw = Get-Content $script:outputPath -Raw
            $raw | Should -Match '"generatedAt"\s*:\s*"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
        }

        It 'Orders artifacts alphabetically by path' {
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            $manifest = Get-Content $script:outputPath -Raw | ConvertFrom-Json
            $paths = $manifest.artifacts | ForEach-Object { $_.path }
            $sorted = $paths | Sort-Object
            $paths | Should -Be $sorted
        }

        It 'Contains all required top-level manifest fields' {
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            $manifest = Get-Content $script:outputPath -Raw | ConvertFrom-Json
            $fields = ($manifest | Get-Member -MemberType NoteProperty).Name | Sort-Object
            $expected = @('algorithm', 'artifacts', 'fileCount', 'generatedAt', 'planRoot', 'projectSlug', 'scope', 'version') | Sort-Object
            $fields | Should -Be $expected
        }
    }

    Context 'exclude patterns' {
        It 'Excludes artifact-manifest.json from the inventory' {
            Set-Content -Path (Join-Path $script:artifactDir 'state.json') -Value '{}' -Encoding utf8NoBOM
            Set-Content -Path (Join-Path $script:artifactDir 'artifact-manifest.json') -Value '{}' -Encoding utf8NoBOM

            $outputPath = Join-Path $script:artifactDir 'artifact-manifest.json'
            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            $manifest = Get-Content $outputPath -Raw | ConvertFrom-Json
            $manifest.fileCount | Should -Be 1
            $manifest.artifacts[0].path | Should -Be 'state.json'
        }

        It 'Excludes .sig and .bundle files from the inventory' {
            Set-Content -Path (Join-Path $script:artifactDir 'data.md') -Value '# Data' -Encoding utf8NoBOM
            Set-Content -Path (Join-Path $script:artifactDir 'manifest.json.sig') -Value 'sig' -Encoding utf8NoBOM
            Set-Content -Path (Join-Path $script:artifactDir 'manifest.json.bundle') -Value 'bundle' -Encoding utf8NoBOM

            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug
            }
            finally {
                Set-Location $originalPWD
            }

            $manifest = Get-Content $script:outputPath -Raw | ConvertFrom-Json
            $manifest.fileCount | Should -Be 1
            $manifest.artifacts[0].path | Should -Be 'data.md'
        }
    }
}

Describe 'Cosign Signing' -Tag 'Unit' {
    BeforeEach {
        $script:projectSlug = 'cosign-test'
        $script:artifactDir = Join-Path $TestDrive ".copilot-tracking/rai-plans/$($script:projectSlug)"
        if (Test-Path $script:artifactDir) { Remove-Item $script:artifactDir -Recurse -Force }
        New-Item -ItemType Directory -Path $script:artifactDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:artifactDir 'data.md') -Value '# Test' -Encoding utf8NoBOM
        $script:outputPath = Join-Path $script:artifactDir 'artifact-manifest.json'
    }

    Context 'when cosign is not installed' {
        It 'Warns and skips signing gracefully' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'cosign' }
            Mock cosign {}

            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug -IncludeCosign
            }
            catch { $_ | Out-Null }
            finally {
                Set-Location $originalPWD
            }

            Should -Invoke Write-Host -ParameterFilter { $Object -like '*cosign not found*' }
            Should -Not -Invoke cosign
        }
    }

    Context 'when cosign is available' {
        It 'Invokes cosign sign-blob with correct arguments' {
            Mock Get-Command { [pscustomobject]@{ Name = 'cosign' } } -ParameterFilter { $Name -eq 'cosign' }
            Mock cosign {}

            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $script:projectSlug -IncludeCosign
            }
            finally {
                Set-Location $originalPWD
            }

            Should -Invoke cosign -Times 1 -Exactly
        }
    }
}

Describe 'Scope routing' -Tag 'Unit' {
    Context 'when -Scope sssc is supplied' {
        It 'Writes the manifest under .copilot-tracking/sssc-plans/{slug}/' {
            $slug = 'sssc-routing'
            $artifactDir = Join-Path $TestDrive ".copilot-tracking/sssc-plans/$slug"
            New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
            Set-Content -Path (Join-Path $artifactDir 'state.json') -Value '{}' -Encoding utf8NoBOM

            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $slug -Scope sssc
            }
            finally {
                Set-Location $originalPWD
            }

            $manifestPath = Join-Path $artifactDir 'artifact-manifest.json'
            Test-Path $manifestPath | Should -BeTrue
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.scope | Should -Be 'sssc'
            $manifest.projectSlug | Should -Be $slug
            $manifest.planRoot | Should -Match 'sssc-plans'
        }
    }

    Context 'when -Scope security is supplied' {
        It 'Writes the manifest under .copilot-tracking/security-plans/{slug}/' {
            $slug = 'security-routing'
            $artifactDir = Join-Path $TestDrive ".copilot-tracking/security-plans/$slug"
            New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
            Set-Content -Path (Join-Path $artifactDir 'state.json') -Value '{}' -Encoding utf8NoBOM

            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $slug -Scope security
            }
            finally {
                Set-Location $originalPWD
            }

            $manifestPath = Join-Path $artifactDir 'artifact-manifest.json'
            Test-Path $manifestPath | Should -BeTrue
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.scope | Should -Be 'security'
            $manifest.planRoot | Should -Match 'security-plans'
        }
    }

    Context 'default scope' {
        It 'Defaults to scope "rai" and writes under rai-plans/' {
            $slug = 'rai-default'
            $artifactDir = Join-Path $TestDrive ".copilot-tracking/rai-plans/$slug"
            New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
            Set-Content -Path (Join-Path $artifactDir 'state.json') -Value '{}' -Encoding utf8NoBOM

            $originalPWD = $PWD
            try {
                Set-Location $TestDrive
                & $script:ScriptPath -ProjectSlug $slug
            }
            finally {
                Set-Location $originalPWD
            }

            $manifest = Get-Content (Join-Path $artifactDir 'artifact-manifest.json') -Raw | ConvertFrom-Json
            $manifest.scope | Should -Be 'rai'
            $manifest.planRoot | Should -Match 'rai-plans'
        }
    }
}
