#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '../scripts/list-changed-files.ps1')

    # Fixture XML with all four change types
    $script:FixtureXml = @'
<commit_history>
  <current_branch>feature/test</current_branch>
  <base_branch>origin/main</base_branch>
  <commits>
    <commit hash="abc1234" date="2026-01-15">
      <message>
        <subject><![CDATA[test commit]]></subject>
        <body><![CDATA[]]></body>
      </message>
    </commit>
  </commits>
  <full_diff>
diff --git a/src/new-file.ts b/src/new-file.ts
new file mode 100644
index 0000000..a1b2c3d
--- /dev/null
+++ b/src/new-file.ts
@@ -0,0 +1,3 @@
+export function newFeature() {
+  return true;
+}

diff --git a/src/existing.ts b/src/existing.ts
index a1b2c3d..d4e5f6a 100644
--- a/src/existing.ts
+++ b/src/existing.ts
@@ -1,3 +1,4 @@
 export function existing() {
-  return false;
+  return true;
+  // comment
 }

diff --git a/src/removed.ts b/src/removed.ts
deleted file mode 100644
index a1b2c3d..0000000
--- a/src/removed.ts
+++ /dev/null
@@ -1,3 +0,0 @@
-export function removed() {
-  return null;
-}

diff --git a/src/old-name.ts b/src/new-name.ts
rename from src/old-name.ts
rename to src/new-name.ts
index a1b2c3d..d4e5f6a 100644
--- a/src/old-name.ts
+++ b/src/new-name.ts
@@ -1,3 +1,3 @@
 export function renamed() {
-  return 'old';
+  return 'new';
 }
  </full_diff>
</commit_history>
'@
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "lcf-tests-$([System.Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    $script:FixturePath = Join-Path $script:TempDir 'pr-reference.xml'
    Set-Content -Path $script:FixturePath -Value $script:FixtureXml -NoNewline
}

AfterAll {
    Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Get-FileChanges' {
    Context 'All change types' {
        It 'Returns all four changed files when filtering by All' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'All'
            $changes.Count | Should -Be 4
        }

        It 'Returns results sorted by Path' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'All'
            $paths = @($changes | Select-Object -ExpandProperty Path)
            $sorted = @($paths | Sort-Object)
            $paths | Should -Be $sorted
        }

        It 'Classifies each change type correctly' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'All'
            ($changes | Where-Object Type -eq 'Added').Count | Should -Be 1
            ($changes | Where-Object Type -eq 'Modified').Count | Should -Be 1
            ($changes | Where-Object Type -eq 'Deleted').Count | Should -Be 1
            ($changes | Where-Object Type -eq 'Renamed').Count | Should -Be 1
        }
    }

    Context 'Added files' {
        It 'Returns only new file mode files' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'Added'
            $changes.Count | Should -Be 1
            $changes[0].Type | Should -Be 'Added'
            $changes[0].Path | Should -Be 'src/new-file.ts'
        }
    }

    Context 'Deleted files' {
        It 'Returns only deleted file mode files' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'Deleted'
            $changes.Count | Should -Be 1
            $changes[0].Type | Should -Be 'Deleted'
            $changes[0].Path | Should -Be 'src/removed.ts'
        }
    }

    Context 'Modified files' {
        It 'Returns only modified files (no mode header)' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'Modified'
            $changes.Count | Should -Be 1
            $changes[0].Type | Should -Be 'Modified'
            $changes[0].Path | Should -Be 'src/existing.ts'
        }
    }

    Context 'Renamed files' {
        It 'Returns only renamed files' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'Renamed'
            $changes.Count | Should -Be 1
            $changes[0].Type | Should -Be 'Renamed'
        }

        It 'Uses arrow notation for old -> new path' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath -FilterType 'Renamed'
            $changes[0].Path | Should -Be 'src/old-name.ts -> src/new-name.ts'
        }
    }

    Context 'Rename by path mismatch' {
        BeforeAll {
            $xml = @'
<commit_history>
  <full_diff>
diff --git a/old/path.ts b/new/path.ts
index a1b2c3d..d4e5f6a 100644
--- a/old/path.ts
+++ b/new/path.ts
@@ -1 +1 @@
-old content
+new content
  </full_diff>
</commit_history>
'@
            $script:RenameFixture = Join-Path $script:TempDir 'rename-path.xml'
            Set-Content -Path $script:RenameFixture -Value $xml -NoNewline
        }

        It 'Detects rename when a/ and b/ paths differ without explicit rename header' {
            $changes = Get-FileChanges -XmlPath $script:RenameFixture -FilterType 'All'
            $changes[0].Type | Should -Be 'Renamed'
            $changes[0].Path | Should -Be 'old/path.ts -> new/path.ts'
        }
    }

    Context 'Empty diff' {
        BeforeAll {
            $xml = @'
<commit_history>
  <full_diff>
  </full_diff>
</commit_history>
'@
            $script:EmptyFixture = Join-Path $script:TempDir 'empty-diff.xml'
            Set-Content -Path $script:EmptyFixture -Value $xml -NoNewline
        }

        It 'Returns empty result when no diff headers present' {
            $changes = Get-FileChanges -XmlPath $script:EmptyFixture -FilterType 'All'
            $changes | Should -BeNullOrEmpty
        }
    }

    Context 'Default FilterType' {
        It 'Returns all files when FilterType is omitted' {
            $changes = Get-FileChanges -XmlPath $script:FixturePath
            $changes.Count | Should -Be 4
        }
    }
}

Describe 'Format-Output' {
    BeforeAll {
        $script:TestChanges = @(
            [PSCustomObject]@{ Path = 'src/alpha.ts'; Type = 'Added' }
            [PSCustomObject]@{ Path = 'src/beta.ts'; Type = 'Modified' }
            [PSCustomObject]@{ Path = 'src/gamma.ts'; Type = 'Deleted' }
        )
    }

    Context 'Plain format' {
        It 'Returns newline-separated file paths' {
            $result = Format-Output -Changes $script:TestChanges -OutputFormat 'Plain'
            $lines = $result -split [Environment]::NewLine
            $lines.Count | Should -Be 3
            $lines[0] | Should -Be 'src/alpha.ts'
        }

        It 'Excludes Type from plain output' {
            $result = Format-Output -Changes $script:TestChanges -OutputFormat 'Plain'
            $result | Should -Not -Match 'Added|Modified|Deleted'
        }
    }

    Context 'Json format' {
        It 'Returns valid JSON with Path and Type properties' {
            $result = Format-Output -Changes $script:TestChanges -OutputFormat 'Json'
            $parsed = $result | ConvertFrom-Json
            $parsed.Count | Should -Be 3
            $parsed[0].Path | Should -Be 'src/alpha.ts'
            $parsed[0].Type | Should -Be 'Added'
        }

        It 'Handles a single change entry' {
            $single = @([PSCustomObject]@{ Path = 'one.ts'; Type = 'Added' })
            $result = Format-Output -Changes $single -OutputFormat 'Json'
            $parsed = $result | ConvertFrom-Json
            # ConvertTo-Json may not wrap single object in array
            if ($parsed -is [array]) {
                $parsed[0].Path | Should -Be 'one.ts'
            }
            else {
                $parsed.Path | Should -Be 'one.ts'
            }
        }
    }

    Context 'Markdown format' {
        It 'Returns table with header row and separator' {
            $result = Format-Output -Changes $script:TestChanges -OutputFormat 'Markdown'
            $result | Should -Match '\| File \| Change Type \|'
            $result | Should -Match '\|------|-------------|'
        }

        It 'Wraps file paths in backticks within cells' {
            $result = Format-Output -Changes $script:TestChanges -OutputFormat 'Markdown'
            $result | Should -Match '`src/alpha.ts`'
        }

        It 'Includes one row per change plus header and separator' {
            $result = Format-Output -Changes $script:TestChanges -OutputFormat 'Markdown'
            $lines = $result -split [Environment]::NewLine
            $lines.Count | Should -Be 5
        }
    }

    Context 'Default format' {
        It 'Uses Plain when OutputFormat is omitted' {
            $result = Format-Output -Changes $script:TestChanges
            $lines = $result -split [Environment]::NewLine
            $lines.Count | Should -Be 3
        }
    }
}

Describe 'Invoke-ListChangedFiles' {
    It 'Returns plain output for a valid fixture file' {
        $result = Invoke-ListChangedFiles -InputPath $script:FixturePath
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Filters by type when specified' {
        $result = Invoke-ListChangedFiles -InputPath $script:FixturePath -Type 'Added'
        $joined = $result -join "`n"
        $joined | Should -Match 'new-file'
        $joined | Should -Not -Match 'removed'
    }

    It 'Returns Json format when specified' {
        $result = Invoke-ListChangedFiles -InputPath $script:FixturePath -Format 'Json'
        $parsed = ($result -join "`n") | ConvertFrom-Json
        $parsed | Should -Not -BeNullOrEmpty
    }

    It 'Returns Markdown format when specified' {
        $result = Invoke-ListChangedFiles -InputPath $script:FixturePath -Format 'Markdown'
        $joined = $result -join "`n"
        $joined | Should -Match '\| File \| Change Type \|'
    }

    It 'Throws when PR reference file does not exist' {
        { Invoke-ListChangedFiles -InputPath '/nonexistent/path.xml' } | Should -Throw '*PR reference file not found*'
    }

    It 'Uses default path when InputPath is empty' {
        Mock Get-RepositoryRoot { return $script:TempDir }
        { Invoke-ListChangedFiles } | Should -Throw '*PR reference file not found*'
    }
}

Describe 'Entry-point execution' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/list-changed-files.ps1'
    }

    It 'Exits 1 when PR reference file does not exist' {
        $null = & pwsh -File $script:ScriptPath -InputPath '/nonexistent/file.xml' 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It 'Lists all files in plain format by default' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output | Measure-Object).Count | Should -BeGreaterOrEqual 1
    }

    It 'Filters by Added type via parameter' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Type Added 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'new-file'
        $joined | Should -Not -Match 'removed'
    }

    It 'Filters by Deleted type via parameter' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Type Deleted 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'removed'
        $joined | Should -Not -Match 'new-file'
    }

    It 'Outputs in Json format' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Format Json 2>&1
        $LASTEXITCODE | Should -Be 0
        $parsed = ($output -join "`n") | ConvertFrom-Json
        $parsed | Should -Not -BeNullOrEmpty
    }

    It 'Outputs in Markdown format with table header' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Format Markdown 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match '\| File \| Change Type \|'
    }
}
