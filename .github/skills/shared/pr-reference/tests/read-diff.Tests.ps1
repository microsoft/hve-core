#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '../scripts/read-diff.ps1')

    # Fixture XML with multiple file diffs for comprehensive testing
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
diff --git a/src/alpha.ts b/src/alpha.ts
new file mode 100644
index 0000000..a1b2c3d
--- /dev/null
+++ b/src/alpha.ts
@@ -0,0 +1,5 @@
+export function alpha() {
+  return 1;
+}
+
+export default alpha;

diff --git a/src/beta.ts b/src/beta.ts
index a1b2c3d..d4e5f6a 100644
--- a/src/beta.ts
+++ b/src/beta.ts
@@ -1,4 +1,6 @@
 export function beta() {
-  return false;
+  return true;
+  // added line one
+  // added line two
 }

diff --git a/src/gamma.ts b/src/gamma.ts
deleted file mode 100644
index a1b2c3d..0000000
--- a/src/gamma.ts
+++ /dev/null
@@ -1,3 +0,0 @@
-export function gamma() {
-  return null;
-}
  </full_diff>
</commit_history>
'@
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "rd-tests-$([System.Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    $script:FixturePath = Join-Path $script:TempDir 'pr-reference.xml'
    Set-Content -Path $script:FixturePath -Value $script:FixtureXml -NoNewline
}

AfterAll {
    Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ChunkInfo' {
    It 'Calculates total chunks when lines divide evenly' {
        $result = Get-ChunkInfo -TotalLines 1000 -ChunkSize 500
        $result.TotalChunks | Should -Be 2
        $result.TotalLines | Should -Be 1000
        $result.ChunkSize | Should -Be 500
    }

    It 'Rounds up when lines do not divide evenly' {
        $result = Get-ChunkInfo -TotalLines 1001 -ChunkSize 500
        $result.TotalChunks | Should -Be 3
    }

    It 'Returns 1 chunk when total lines equal chunk size' {
        $result = Get-ChunkInfo -TotalLines 500 -ChunkSize 500
        $result.TotalChunks | Should -Be 1
    }

    It 'Returns 1 chunk when total lines are less than chunk size' {
        $result = Get-ChunkInfo -TotalLines 100 -ChunkSize 500
        $result.TotalChunks | Should -Be 1
    }

    It 'Returns 0 chunks when total lines is 0' {
        $result = Get-ChunkInfo -TotalLines 0 -ChunkSize 500
        $result.TotalChunks | Should -Be 0
    }
}

Describe 'Get-ChunkRange' {
    It 'Returns correct range for the first chunk' {
        $result = Get-ChunkRange -ChunkNumber 1 -ChunkSize 10 -TotalLines 25
        $result.Start | Should -Be 1
        $result.End | Should -Be 10
    }

    It 'Returns correct range for a middle chunk' {
        $result = Get-ChunkRange -ChunkNumber 2 -ChunkSize 10 -TotalLines 25
        $result.Start | Should -Be 11
        $result.End | Should -Be 20
    }

    It 'Caps end at TotalLines for the last partial chunk' {
        $result = Get-ChunkRange -ChunkNumber 3 -ChunkSize 10 -TotalLines 25
        $result.Start | Should -Be 21
        $result.End | Should -Be 25
    }

    It 'Handles single-line file' {
        $result = Get-ChunkRange -ChunkNumber 1 -ChunkSize 500 -TotalLines 1
        $result.Start | Should -Be 1
        $result.End | Should -Be 1
    }
}

Describe 'Get-FileDiff' {
    BeforeAll {
        $script:fileDiffContent = @(Get-Content -LiteralPath $script:FixturePath)
    }

    It 'Extracts diff block for an existing file' {
        $result = Get-FileDiff -Content $script:fileDiffContent -FilePath 'src/beta.ts'
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match 'diff --git a/src/beta.ts'
        $result | Should -Match 'return true'
    }

    It 'Stops extraction at the next diff header' {
        $result = Get-FileDiff -Content $script:fileDiffContent -FilePath 'src/alpha.ts'
        $result | Should -Match 'diff --git a/src/alpha.ts'
        $result | Should -Not -Match 'diff --git a/src/beta.ts'
    }

    It 'Returns empty string when file is not in the diff' {
        $result = Get-FileDiff -Content $script:fileDiffContent -FilePath 'src/nonexistent.ts'
        $result | Should -BeNullOrEmpty
    }

    It 'Extracts the last file in the diff without a trailing diff header' {
        $result = Get-FileDiff -Content $script:fileDiffContent -FilePath 'src/gamma.ts'
        $result | Should -Match 'diff --git a/src/gamma.ts'
        $result | Should -Match 'deleted file mode'
    }

    It 'Handles file paths containing regex special characters' {
        $specialContent = @(
            'diff --git a/src/[utils].ts b/src/[utils].ts'
            'index abc..def 100644'
            '--- a/src/[utils].ts'
            '+++ b/src/[utils].ts'
            '@@ -1 +1 @@'
            '-old'
            '+new'
        )
        $result = Get-FileDiff -Content $specialContent -FilePath 'src/[utils].ts'
        $result | Should -Match '\[utils\]'
    }
}

Describe 'Get-DiffSummary' {
    BeforeAll {
        $script:summaryContent = @(Get-Content -LiteralPath $script:FixturePath)
    }

    It 'Counts additions and deletions per file' {
        $result = Get-DiffSummary -Content $script:summaryContent
        # src/alpha.ts: 4 additions (bare + line excluded by regex), 0 deletions
        $result | Should -Match 'src/alpha.ts \(\+4/-0\)'
    }

    It 'Reports correct counts for modified files' {
        $result = Get-DiffSummary -Content $script:summaryContent
        # src/beta.ts: 3 additions (+return true, +added line one, +added line two), 1 deletion (-return false)
        $result | Should -Match 'src/beta.ts \(\+3/-1\)'
    }

    It 'Reports correct counts for deleted files' {
        $result = Get-DiffSummary -Content $script:summaryContent
        # src/gamma.ts: 0 additions, 3 deletions
        $result | Should -Match 'src/gamma.ts \(\+0/-3\)'
    }

    It 'Starts output with Changed files header' {
        $result = Get-DiffSummary -Content $script:summaryContent
        $result | Should -Match '^Changed files:'
    }

    It 'Sorts files alphabetically' {
        $result = Get-DiffSummary -Content $script:summaryContent
        $lines = ($result -split [Environment]::NewLine) | Where-Object { $_ -match '^\s+\S' }
        $filePaths = $lines | ForEach-Object { ($_ -replace '^\s+(\S+)\s.*', '$1') }
        $sorted = $filePaths | Sort-Object
        @($filePaths) | Should -Be @($sorted)
    }

    It 'Returns only header when content has no diff blocks' {
        $result = Get-DiffSummary -Content @('no diff content here')
        $result | Should -Be 'Changed files:'
    }

    It 'Does not count lines starting with ++ or -- as changes' {
        $content = @(
            'diff --git a/file.ts b/file.ts'
            '--- a/file.ts'
            '+++ b/file.ts'
            '@@ -1,2 +1,2 @@'
            '-old line'
            '+new line'
        )
        $result = Get-DiffSummary -Content $content
        # Only 1 addition and 1 deletion; --- and +++ are excluded
        $result | Should -Match 'file.ts \(\+1/-1\)'
    }
}

Describe 'Invoke-ReadDiff' {
    Context 'Info mode' {
        It 'Outputs file path and chunk breakdown' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -Info
            $joined = $result -join "`n"
            $joined | Should -Match 'Total lines:'
            $joined | Should -Match 'Total chunks:'
            $joined | Should -Match 'Chunk breakdown:'
        }

        It 'Respects custom ChunkSize' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -Info -ChunkSize 10
            $joined = $result -join "`n"
            $joined | Should -Match 'Chunk size: 10'
        }
    }

    Context 'Summary mode' {
        It 'Outputs changed files with counts' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -Summary
            $joined = $result -join "`n"
            $joined | Should -Match 'Changed files:'
            $joined | Should -Match 'src/alpha.ts'
        }
    }

    Context 'File extraction mode' {
        It 'Extracts diff for a specific file' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -File 'src/beta.ts'
            $joined = $result -join "`n"
            $joined | Should -Match 'diff --git a/src/beta.ts'
        }

        It 'Warns when file is not in the diff' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -File 'src/missing.ts' 3>&1
            $result | Should -Match 'No diff found'
        }
    }

    Context 'Chunk mode' {
        It 'Reads chunk with header comment' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -Chunk 1 -ChunkSize 10
            $joined = $result -join "`n"
            $joined | Should -Match '# Chunk 1/'
        }

        It 'Throws when chunk number exceeds total' {
            { Invoke-ReadDiff -InputPath $script:FixturePath -Chunk 9999 -ChunkSize 10 } | Should -Throw '*exceeds file*'
        }
    }

    Context 'Lines mode' {
        It 'Reads a line range with header' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -Lines '1,5'
            $joined = $result -join "`n"
            $joined | Should -Match '# Lines 1-5'
        }

        It 'Throws on invalid line range format' {
            { Invoke-ReadDiff -InputPath $script:FixturePath -Lines 'invalid' } | Should -Throw '*Invalid line range*'
        }

        It 'Throws when start line exceeds file length' {
            { Invoke-ReadDiff -InputPath $script:FixturePath -Lines '99999,100000' } | Should -Throw '*exceeds file length*'
        }

        It 'Caps end line at file length' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath -Lines '1,999999'
            $joined = $result -join "`n"
            $joined | Should -Match '# Lines 1-'
        }
    }

    Context 'Default mode' {
        It 'Displays usage guidance when no mode requested' {
            $result = Invoke-ReadDiff -InputPath $script:FixturePath
            $joined = $result -join "`n"
            $joined | Should -Match 'Total lines:'
            $joined | Should -Match 'Use -Chunk N'
        }
    }

    Context 'Error handling' {
        It 'Throws when file does not exist' {
            { Invoke-ReadDiff -InputPath '/nonexistent/file.xml' } | Should -Throw '*PR reference file not found*'
        }

        It 'Uses default path when InputPath is empty' {
            Mock Get-RepositoryRoot { return $script:TempDir }
            { Invoke-ReadDiff } | Should -Throw '*PR reference file not found*'
        }
    }
}

Describe 'Entry-point: file not found' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/read-diff.ps1'
    }

    It 'Exits 1 when PR reference file does not exist' {
        $null = & pwsh -File $script:ScriptPath -InputPath '/nonexistent/file.xml' 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'Entry-point: Info mode' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/read-diff.ps1'
    }

    It 'Displays file path and chunk breakdown' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Info 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'Total lines:'
        $joined | Should -Match 'Total chunks:'
        $joined | Should -Match 'Chunk breakdown:'
    }

    It 'Respects custom ChunkSize in info output' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Info -ChunkSize 10 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'Chunk size: 10'
    }
}

Describe 'Entry-point: Summary mode' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/read-diff.ps1'
    }

    It 'Outputs changed files with add/remove counts' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Summary 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'Changed files:'
        $joined | Should -Match 'src/alpha.ts'
    }
}

Describe 'Entry-point: File mode' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/read-diff.ps1'
    }

    It 'Extracts diff for a specific file' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -File 'src/beta.ts' 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'diff --git a/src/beta.ts'
    }

    It 'Warns when file is not found in the diff' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -File 'src/missing.ts' 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'No diff found for file'
    }
}

Describe 'Entry-point: Chunk mode' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/read-diff.ps1'
    }

    It 'Reads the first chunk with header comment' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Chunk 1 -ChunkSize 10 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match '# Chunk 1/'
    }

    It 'Exits 1 when chunk number exceeds total chunks' {
        $null = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Chunk 9999 -ChunkSize 10 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'Entry-point: Lines mode' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/read-diff.ps1'
    }

    It 'Reads a line range using comma separator' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Lines '1,5' 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match '# Lines 1-5'
    }

    It 'Reads a line range using dash separator' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Lines '2-4' 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match '# Lines 2-4'
    }

    It 'Exits 1 when start line exceeds file length' {
        $null = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Lines '99999,100000' 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It 'Exits 1 with invalid line range format' {
        $null = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Lines 'invalid' 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It 'Caps end line at file length when range exceeds total' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath -Lines '1,999999' 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match '# Lines 1-'
    }
}

Describe 'Entry-point: Default mode' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/read-diff.ps1'
    }

    It 'Displays usage guidance when no mode arguments are supplied' {
        $output = & pwsh -File $script:ScriptPath -InputPath $script:FixturePath 2>&1
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join "`n"
        $joined | Should -Match 'Total lines:'
        $joined | Should -Match 'Use -Chunk N'
    }
}
