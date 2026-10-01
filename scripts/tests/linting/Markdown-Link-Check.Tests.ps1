#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Markdown-Link-Check.ps1 script
.DESCRIPTION
    Tests for markdown link checking wrapper functions:
    - Get-MarkdownTarget
    - Get-RelativePrefix
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Markdown-Link-Check.ps1'
    . $script:ScriptPath

    # Import LintingHelpers for mocking
    Import-Module (Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1') -Force

    $script:FixtureDir = Join-Path $PSScriptRoot '../fixtures/Linting'

    function New-TestMarkdownLinkCheckReport {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [hashtable[]]$Suite
        )

        $suiteXml = foreach ($suiteDefinition in $Suite) {
            $fileProperty = if (-not $suiteDefinition.ContainsKey('IncludeFile') -or $suiteDefinition.IncludeFile) {
                $escapedFile = [System.Security.SecurityElement]::Escape([string]$suiteDefinition.File)
                "<property name=`"file`" value=`"$escapedFile`"/>"
            }
            else {
                ''
            }

            $links = @($suiteDefinition.Links)
            $failures = @($links | Where-Object { $_.Status -eq 'dead' }).Count
            $errors = @($links | Where-Object { $_.Status -eq 'error' }).Count
            $testCases = foreach ($link in $links) {
                $escapedUrl = [System.Security.SecurityElement]::Escape([string]$link.Url)
                $statusCode = if ($null -ne $link.StatusCode) {
                    "<property name=`"statusCode`" value=`"$($link.StatusCode)`"/>"
                }
                else {
                    ''
                }
                $resultElement = switch ($link.Status) {
                    'dead' { '<failure message="dead" type="DeadLink"/>' }
                    'error' { '<error message="error" type="LinkCheckError"/>' }
                    'ignored' { '<skipped message="ignored"/>' }
                    default { '' }
                }

                @"
<testcase name="$escapedUrl" classname="test" time="0"><properties><property name="url" value="$escapedUrl"/><property name="status" value="$($link.Status)"/>$statusCode</properties>$resultElement</testcase>
"@
            }

            @"
<testsuite name="test" tests="$($links.Count)" failures="$failures" errors="$errors" skipped="0" time="0"><properties>$fileProperty</properties>$($testCases -join '')</testsuite>
"@
        }

        return "<testsuites name=`"markdown-link-check`">$($suiteXml -join '')</testsuites>"
    }

    function New-TestMarkdownLinkCheckCli {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Directory
        )

        $scriptPath = Join-Path $Directory 'fake-markdown-link-check.js'
        $scriptContent = @'
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const targets = [];
let junitOutput;
let configPath;
for (let index = 0; index < args.length; index++) {
    const argument = args[index];
    if (argument === '-c') {
        configPath = args[++index];
    } else if (argument === '--reporters') {
        index++;
    } else if (argument === '--junit-output') {
        junitOutput = args[++index];
    } else if (argument !== '-q') {
        targets.push(argument);
    }
}

const escapeXml = (value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

const decodeHtml = (value) => value
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

const extractTestUrls = (target) => {
    const content = fs.readFileSync(target, 'utf8');
    const urls = [];
    for (const pattern of [
        /\]\((https?:\/\/[^\s)]+)\)/gi,
        /href="([^"]+)"/gi,
        /<(https?:\/\/[^>]+)>/gi
    ]) {
        for (const match of content.matchAll(pattern)) {
            urls.push(decodeHtml(match[1]));
        }
    }
    return [...new Set(urls)];
};

const urlMode = process.env.MARKDOWN_LINK_CHECK_TEST_URL_MODE === 'true';
const config = configPath ? JSON.parse(fs.readFileSync(configPath, 'utf8')) : {};
const sourceStage = (config.ignorePatterns || []).some(({ pattern }) =>
    pattern === '^[Hh][Tt][Tt][Pp][Ss]?://'
);
const aggregateStage = targets.some((target) => path.basename(target).startsWith('external-links-'));
const stage = sourceStage ? 'source' : (aggregateStage ? 'aggregate' : 'legacy');
const urlsByTarget = new Map(targets.map((target) => [
    target,
    urlMode || aggregateStage ? extractTestUrls(target) : [`https://example.test/${target}`]
]));
const aggregateUrls = stage === 'aggregate' ? [...new Set([...urlsByTarget.values()].flat())] : [];
const fetchedUrls = sourceStage ? [] : [...urlsByTarget.values()].flat().filter((url) =>
    url !== process.env.MARKDOWN_LINK_CHECK_TEST_IGNORED_URL
);
const recordPath = path.join(process.env.MARKDOWN_LINK_CHECK_TEST_LEDGER, `${process.pid}.json`);
fs.writeFileSync(recordPath, JSON.stringify({
    Targets: targets,
    Stage: stage,
    AggregateUrls: aggregateUrls,
    FetchedUrls: fetchedUrls,
    ConfigPath: configPath,
    IgnorePatterns: config.ignorePatterns,
    JunitOutput: junitOutput
}), 'utf8');

const aggregateDefect = aggregateStage ? process.env.MARKDOWN_LINK_CHECK_TEST_AGGREGATE_DEFECT : undefined;
const defectUrl = process.env.MARKDOWN_LINK_CHECK_TEST_DEFECT_URL;
const allUrls = [...urlsByTarget.values()].flat();
const defectProcess = Boolean(aggregateDefect) && (!defectUrl || allUrls.includes(defectUrl));

const createResult = (url, target) => {
    const ignored = sourceStage || url === process.env.MARKDOWN_LINK_CHECK_TEST_IGNORED_URL;
    const isDead = urlMode
        ? url === process.env.MARKDOWN_LINK_CHECK_TEST_DEAD_URL
        : target === process.env.MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET ||
            url === `https://example.test/${process.env.MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET}`;
    const status = ignored ? 'ignored' : (isDead ? 'dead' : 'alive');
    return {
        url,
        status,
        statusCode: ignored ? '0' : (isDead ? '404' : '200'),
        resultElement: ignored
            ? '<skipped message="ignored"/>'
            : (isDead ? '<failure message="dead" type="DeadLink"/>' : '')
    };
};

const renderResult = (result, applyDefect) => {
    const escapedUrl = escapeXml(result.url);
    const status = applyDefect && aggregateDefect === 'unsupported-status'
        ? 'unsupported'
        : result.status;
    const properties = [];
    if (!(applyDefect && aggregateDefect === 'missing-url-property')) {
        properties.push(`<property name="url" value="${escapedUrl}"/>`);
        if (applyDefect && aggregateDefect === 'duplicate-url-property') {
            properties.push(`<property name="url" value="${escapedUrl}"/>`);
        }
    }
    if (!(applyDefect && aggregateDefect === 'missing-status-property')) {
        properties.push(`<property name="status" value="${status}"/>`);
        if (applyDefect && aggregateDefect === 'duplicate-status-property') {
            properties.push(`<property name="status" value="${status}"/>`);
        }
    }
    properties.push(`<property name="statusCode" value="${result.statusCode}"/>`);
    if (applyDefect && aggregateDefect === 'duplicate-status-code-property') {
        properties.push(`<property name="statusCode" value="${result.statusCode}"/>`);
    }
    return `<testcase name="${escapedUrl}" classname="test" time="0"><properties>${properties.join('')}</properties>${result.resultElement}</testcase>`;
};

const suites = targets.map((target) => {
    const escapedTarget = escapeXml(target);
    const results = urlsByTarget.get(target).map((url) => createResult(url, target));
    if (defectProcess && aggregateDefect === 'unexpected-result' && target === targets[0]) {
        results.push(createResult('https://unexpected.example.test/result', target));
    }
    const failures = results.filter(({ status }) => status === 'dead').length;
    const skipped = results.filter(({ status }) => status === 'ignored').length;
    const testCases = [];
    for (const result of results) {
        const applyDefect = defectProcess && (!defectUrl || result.url === defectUrl);
        if (applyDefect && aggregateDefect === 'missing-result') {
            continue;
        }
        const testCase = renderResult(result, applyDefect);
        testCases.push(testCase);
        if (applyDefect && aggregateDefect === 'duplicate-result') {
            testCases.push(testCase);
        }
    }
    return `<testsuite name="test" tests="${testCases.length}" failures="${failures}" errors="0" skipped="${skipped}" time="0"><properties><property name="file" value="${escapedTarget}"/></properties>${testCases.join('')}</testsuite>`;
});

if (defectProcess && aggregateDefect === 'invocation-error') {
    process.exit(2);
}
if (defectProcess && aggregateDefect === 'malformed-xml') {
    fs.writeFileSync(junitOutput, '<testsuites><testsuite>', 'utf8');
    process.exit(1);
}
fs.writeFileSync(junitOutput, `<testsuites name="markdown-link-check">${suites.join('')}</testsuites>`, 'utf8');
const hasDeadResult = [...urlsByTarget.entries()].some(([target, urls]) => urlMode
    ? urls.includes(process.env.MARKDOWN_LINK_CHECK_TEST_DEAD_URL) && !sourceStage
    : !sourceStage && (
        target === process.env.MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET ||
        urls.includes(`https://example.test/${process.env.MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET}`)
    )
);
process.exit(hasDeadResult || (defectProcess && aggregateDefect === 'unexplained-exit') ? 1 : 0);
'@
        Set-Content -LiteralPath $scriptPath -Value $scriptContent -Encoding utf8

        if ($IsWindows) {
            $cliPath = Join-Path $Directory 'markdown-link-check.cmd'
            Set-Content -LiteralPath $cliPath -Value "@node `"$scriptPath`" %*" -Encoding ascii
            return $cliPath
        }

        $cliPath = Join-Path $Directory 'markdown-link-check'
        Set-Content -LiteralPath $cliPath -Value "#!/usr/bin/env node`n$scriptContent" -Encoding utf8
        & chmod +x $cliPath
        return $cliPath
    }
}

AfterAll {
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

#region Get-MarkdownTarget Tests

Describe 'Get-MarkdownTarget' -Tag 'Unit' {
    BeforeAll {
        # Create a temp directory to use as test input
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Git-tracked files in repository' {
        BeforeEach {
            # Create test markdown files
            $script:TestFile1 = Join-Path $script:TempDir 'test1.md'
            $script:TestFile2 = Join-Path $script:TempDir 'test2.md'
            Set-Content -Path $script:TestFile1 -Value '# Test 1'
            Set-Content -Path $script:TestFile2 -Value '# Test 2'

            # Mock git to indicate we're in a repo and return tracked files
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TempDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @('test1.md', 'test2.md')
                }
            }
        }

        It 'Returns markdown files when given a directory' {
            $result = Get-MarkdownTarget -InputPath $script:TempDir
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Requests tracked and untracked nonignored files' {
            Get-MarkdownTarget -InputPath $script:TempDir | Out-Null

            Should -Invoke git -ParameterFilter {
                $args -contains 'ls-files' -and
                $args -contains '--cached' -and
                $args -contains '--others' -and
                $args -contains '--exclude-standard'
            } -Times 1 -Exactly
        }
    }

    Context 'Changed-files-only filtering' {
        BeforeEach {
            Set-Content -Path (Join-Path $script:TempDir 'changed.md') -Value '# Changed'
            Set-Content -Path (Join-Path $script:TempDir 'unchanged.md') -Value '# Unchanged'

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TempDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @('changed.md', 'unchanged.md')
                }
            }
        }

        It 'Restricts targets to markdown files reported as changed' {
            Mock Get-ChangedFilesFromGit { @('changed.md') }

            $result = @(Get-MarkdownTarget -InputPath $script:TempDir -ChangedFilesOnly -BaseBranch 'origin/main')

            $result.Count | Should -Be 1
            [System.IO.Path]::GetFileName($result[0]) | Should -Be 'changed.md'
        }

        It 'Returns no targets when no markdown files changed' {
            Mock Get-ChangedFilesFromGit { @() }

            $result = @(Get-MarkdownTarget -InputPath $script:TempDir -ChangedFilesOnly)

            $result.Count | Should -Be 0
        }

        It 'Returns every discovered file when the switch is absent' {
            Mock Get-ChangedFilesFromGit { @('changed.md') }

            $result = @(Get-MarkdownTarget -InputPath $script:TempDir)

            $result.Count | Should -Be 2
            Should -Invoke Get-ChangedFilesFromGit -Times 0 -Exactly
        }
    }

    Context 'Non-git fallback mode' {
        BeforeEach {
            # Create test files
            $script:TestFile = Join-Path $script:TempDir 'readme.md'
            Set-Content -Path $script:TestFile -Value '# Readme'

            # Mock git to simulate not being in a repo
            Mock git {
                $global:LASTEXITCODE = 128
                return 'fatal: not a git repository'
            }
        }

        It 'Falls back to filesystem when not in git repo' {
            $result = Get-MarkdownTarget -InputPath $script:TempDir
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Returns absolute paths' {
            $result = Get-MarkdownTarget -InputPath $script:TempDir
            if ($result) {
                [System.IO.Path]::IsPathRooted($result[0]) | Should -BeTrue
            }
        }
    }

    Context 'Empty input handling' {
        It 'Returns empty array for null input' {
            $result = Get-MarkdownTarget -InputPath $null
            $result | Should -BeNullOrEmpty
        }

        It 'Returns empty array for empty string input' {
            $result = Get-MarkdownTarget -InputPath ''
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Git file discovery failure' {
        BeforeEach {
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TempDir
                }

                $global:LASTEXITCODE = 1
                return $null
            }
        }

        It 'Throws instead of treating a failed directory query as no files' {
            { Get-MarkdownTarget -InputPath $script:TempDir } |
                Should -Throw '*git ls-files failed*'
        }

        It 'Throws instead of reporting a specific file as ignored' {
            $file = Join-Path $script:TempDir 'git-failure.md'
            Set-Content -LiteralPath $file -Value '# Git failure'

            { Get-MarkdownTarget -InputPath $file } |
                Should -Throw '*git ls-files failed*'
        }
    }

    Context 'Fixture exclusion filtering' {
        BeforeEach {
            # Create test files including fixture path
            $script:IncludeFile = Join-Path $script:TempDir 'docs' 'readme.md'
            $script:ExcludeFile = Join-Path $script:TempDir 'scripts' 'tests' 'fixtures' 'test.md'

            New-Item -ItemType Directory -Path (Join-Path $script:TempDir 'docs') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TempDir 'scripts' 'tests' 'fixtures') -Force | Out-Null
            Set-Content -Path $script:IncludeFile -Value '# Include This'
            Set-Content -Path $script:ExcludeFile -Value '# Exclude Fixture'

            # Mock git to simulate repository with tracked files including fixtures
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TempDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    # Return both fixture and non-fixture files
                    return @('docs/readme.md', 'scripts/tests/fixtures/test.md')
                }
            }
        }

        It 'Filters out test fixture files from results' {
            # Act
            $result = Get-MarkdownTarget -InputPath $script:TempDir

            # Assert - Should exclude files in scripts/tests/fixtures/
            $fixtureFiles = $result | Where-Object { $_ -like '*fixtures*' }
            $fixtureFiles | Should -BeNullOrEmpty
        }

        It 'Includes non-fixture files in results' {
            # Act
            $result = Get-MarkdownTarget -InputPath $script:TempDir

            # Assert - Should include docs files
            $docsFiles = $result | Where-Object { $_ -like '*docs*readme.md' }
            $docsFiles | Should -Not -BeNullOrEmpty
        }

        It 'Correctly applies the notlike filter pattern' {
            # Test the exact filter pattern used in the code
            $testPaths = @('docs/readme.md', 'scripts/tests/fixtures/test.md', 'src/guide.md')
            $filtered = $testPaths | Where-Object { $_ -notlike 'scripts/tests/fixtures/*' }

            $filtered | Should -Contain 'docs/readme.md'
            $filtered | Should -Contain 'src/guide.md'
            $filtered | Should -Not -Contain 'scripts/tests/fixtures/test.md'
        }
    }
}

#endregion

#region Get-RelativePrefix Tests

Describe 'Get-RelativePrefix' -Tag 'Unit' {
    BeforeAll {
        # Create a temp directory structure for testing relative paths
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot 'docs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot 'docs/guide') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot 'src') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Nested directory traversal' {
        It 'Returns relative prefix from subdirectory to root' {
            $fromPath = Join-Path $script:TempRoot 'docs/guide'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            $result | Should -Be '../../'
        }

        It 'Returns relative prefix from single-level directory to root' {
            $fromPath = Join-Path $script:TempRoot 'docs'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            $result | Should -Be '../'
        }
    }

    Context 'Same directory' {
        It 'Returns empty string for same directory' {
            $result = Get-RelativePrefix -FromPath $script:TempRoot -ToPath $script:TempRoot
            $result | Should -Be ''
        }
    }

    Context 'Sibling directories' {
        It 'Returns correct prefix between sibling directories' {
            $fromPath = Join-Path $script:TempRoot 'docs'
            $toPath = Join-Path $script:TempRoot 'src'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $toPath
            $result | Should -Be '../src/'
        }
    }

    Context 'Forward slash normalization' {
        It 'Returns forward slashes on Windows' {
            $fromPath = Join-Path $script:TempRoot 'docs/guide'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            $result | Should -Not -Match '\\'
        }

        It 'Always has trailing slash when not empty' {
            $fromPath = Join-Path $script:TempRoot 'docs'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            if ($result -ne '') {
                $result | Should -Match '/$'
            }
        }
    }
}

#endregion

#region Split-MarkdownTargetBatch Tests

Describe 'Split-MarkdownTargetBatch' -Tag 'Unit' {
    It 'Creates the throttle-derived batch count for <TargetCount> targets and throttle <ThrottleLimit> when no budget applies' -ForEach @(
        @{ TargetCount = 0; ThrottleLimit = 4; ExpectedBatchCount = 0 }
        @{ TargetCount = 1; ThrottleLimit = 4; ExpectedBatchCount = 1 }
        @{ TargetCount = 4; ThrottleLimit = 4; ExpectedBatchCount = 4 }
        @{ TargetCount = 7; ThrottleLimit = 4; ExpectedBatchCount = 4 }
        @{ TargetCount = 7; ThrottleLimit = 1; ExpectedBatchCount = 1 }
    ) {
        $targets = @(0..($TargetCount - 1) | ForEach-Object { "file-$_.md" })
        if ($TargetCount -eq 0) {
            $targets = @()
        }

        $batches = @(Split-MarkdownTargetBatch -Target $targets -ThrottleLimit $ThrottleLimit)

        $batches.Count | Should -Be $ExpectedBatchCount
        @($batches | Where-Object { @($_.Files).Count -eq 0 }).Count | Should -Be 0
    }

    It 'Sorts targets and distributes them into balanced contiguous batches' {
        $batches = @(Split-MarkdownTargetBatch -Target @('z.md', 'a.md', 'm.md', 'b.md', 'x.md') -ThrottleLimit 2)

        @($batches[0].Files) | Should -Be @('a.md', 'b.md', 'm.md')
        @($batches[1].Files) | Should -Be @('x.md', 'z.md')
        $sizes = @($batches | ForEach-Object { @($_.Files).Count })
        (($sizes | Measure-Object -Maximum).Maximum - ($sizes | Measure-Object -Minimum).Minimum) | Should -BeLessOrEqual 1
    }

    It 'Keeps every batch within the budget when combined argument length crosses it' {
        $targets = @(0..79 | ForEach-Object {
            'docs/deeply/nested/section/file-{0:D3}-{1}.md' -f $_, ('x' * 20)
        })
        $budget = 1024
        $reserved = 512
        $available = $budget - $reserved

        $batches = @(Split-MarkdownTargetBatch `
            -Target $targets `
            -ThrottleLimit 4 `
            -ArgumentLengthBudget $budget `
            -ReservedLength $reserved)

        $batches.Count | Should -BeGreaterThan 4
        foreach ($batch in $batches) {
            $files = @($batch.Files)
            $length = (($files | Measure-Object -Property Length -Sum).Sum) + (3 * $files.Count)
            $length | Should -BeLessOrEqual $available
        }
        @($batches | ForEach-Object { @($_.Files) }) | Should -Be @($targets | Sort-Object)
        @($batches.Index) | Should -Be @(0..($batches.Count - 1))
    }

    It 'Reproduces the unbudgeted batches when no batch would exceed the budget' {
        $targets = @(0..9 | ForEach-Object { "file-$_.md" })

        $unbudgeted = @(Split-MarkdownTargetBatch -Target $targets -ThrottleLimit 4)
        $budgeted = @(Split-MarkdownTargetBatch `
            -Target $targets `
            -ThrottleLimit 4 `
            -ArgumentLengthBudget 8191 `
            -ReservedLength 200)

        @($budgeted | ForEach-Object { $_.Files -join '|' }) |
            Should -Be @($unbudgeted | ForEach-Object { $_.Files -join '|' })
    }

    It 'Throws when a single target alone exceeds the available length' {
        {
            Split-MarkdownTargetBatch `
                -Target @((('a' * 200) + '.md')) `
                -ThrottleLimit 1 `
                -ArgumentLengthBudget 100 `
                -ReservedLength 10
        } | Should -Throw -ExpectedMessage '*alone exceeds the available command-line length*'
    }

    It 'Leaves URL batching bounded only by the throttle limit' {
        $urls = @(0..19 | ForEach-Object { 'https://example.test/{0}/{1}' -f $_, ('y' * 2000) })

        $batches = @(Split-MarkdownTargetBatch -Target $urls -ThrottleLimit 4)

        $batches.Count | Should -Be 4
        (($batches | ForEach-Object { ($_.Files | Measure-Object -Property Length -Sum).Sum } |
            Measure-Object -Maximum).Maximum) | Should -BeGreaterThan 8191
    }
}

#endregion

#region Get-MarkdownBatchLengthBudget Tests

Describe 'Get-MarkdownBatchLengthBudget' -Tag 'Unit' {
    It 'Reserves the CLI path, base arguments, and reporter arguments' {
        $cli = '/repo/node_modules/.bin/markdown-link-check'
        $baseArgument = @('-c', '/tmp/task-workspace/source-config.json', '-q')
        $reportPath = '/tmp/task-workspace/source-00.xml'

        $result = Get-MarkdownBatchLengthBudget -Cli $cli -BaseArgument $baseArgument -ReportPath $reportPath

        $fixed = @($cli) + $baseArgument + @('--reporters', 'default,junit', '--junit-output', $reportPath)
        $expected = (@($fixed | ForEach-Object { $_.Length + 3 }) | Measure-Object -Sum).Sum
        if ($IsWindows) {
            $expected += 'cmd.exe /c ""'.Length
        }

        $result.Reserved | Should -Be $expected
        $result.Reserved | Should -BeLessThan $result.Budget
    }

    It 'Uses the command-interpreter ceiling on Windows rather than the CreateProcess ceiling' {
        $result = Get-MarkdownBatchLengthBudget -Cli 'cli' -BaseArgument @('-c', 'config.json') -ReportPath 'report.xml'

        if ($IsWindows) {
            $result.Budget | Should -Be 8191
        }
        else {
            $result.Budget | Should -BeGreaterThan 8191
        }
    }
}

#endregion

#region Test-MarkdownExternalScope Tests

Describe 'Test-MarkdownExternalScope' -Tag 'Unit' {
    It 'Treats an absent scope as every file in scope and an empty scope as no file in scope' {
        $emptyScope = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        Test-MarkdownExternalScope -RelativePath 'docs/readme.md' -Scope $null | Should -BeTrue
        Test-MarkdownExternalScope -RelativePath 'docs/readme.md' -Scope $emptyScope | Should -BeFalse
    }

    It 'Matches a platform-separator source path against a forward-slash scope key' {
        $scope = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        [void]$scope.Add('docs/guide/readme.md')

        Test-MarkdownExternalScope -RelativePath 'docs\guide\readme.md' -Scope $scope | Should -BeTrue
        Test-MarkdownExternalScope -RelativePath 'DOCS\GUIDE\README.MD' -Scope $scope | Should -BeTrue
        Test-MarkdownExternalScope -RelativePath 'docs/guide/other.md' -Scope $scope | Should -BeFalse
    }
}

#endregion

#region ConvertFrom-MarkdownLinkCheckReport Tests

Describe 'ConvertFrom-MarkdownLinkCheckReport' -Tag 'Unit' {
    It 'Maps trustworthy suites by normalized full file path and explains a nonzero exit selectively' {
        $report = New-TestMarkdownLinkCheckReport -Suite @(
            @{ File = 'docs\readme.md'; Links = @(@{ Url = 'https://alive.test'; Status = 'alive'; StatusCode = 200 }) }
            @{ File = 'other/readme.md'; Links = @(@{ Url = 'https://dead.test'; Status = 'dead'; StatusCode = 404 }) }
            @{ File = 'third.md'; Links = @(@{ Url = 'https://ignored.test'; Status = 'ignored'; StatusCode = 0 }) }
            @{ File = 'fourth.md'; Links = @(@{ Url = 'https://error.test'; Status = 'error'; StatusCode = 500 }) }
        )

        $results = @(ConvertFrom-MarkdownLinkCheckReport `
            -ExpectedFile @('other/readme.md', 'docs/readme.md', 'third.md', 'fourth.md') `
            -ReportContent $report -ExitCode 1)

        @($results.File) | Should -Be @('docs/readme.md', 'fourth.md', 'other/readme.md', 'third.md')
        ($results | Where-Object File -eq 'docs/readme.md').Failed | Should -BeFalse
        ($results | Where-Object File -eq 'other/readme.md').Failed | Should -BeTrue
        ($results | Where-Object File -eq 'fourth.md').Failed | Should -BeTrue
        ($results | Where-Object File -eq 'third.md').Failed | Should -BeFalse
        @($results | Where-Object ParseFailed).Count | Should -Be 0
    }

    It 'Fails every expected file for an unexplained nonzero exit' {
        $report = New-TestMarkdownLinkCheckReport -Suite @(
            @{ File = 'a.md'; Links = @(@{ Url = 'https://a.test'; Status = 'alive'; StatusCode = 200 }) }
            @{ File = 'b.md'; Links = @(@{ Url = 'https://b.test'; Status = 'alive'; StatusCode = 200 }) }
        )

        $results = @(ConvertFrom-MarkdownLinkCheckReport -ExpectedFile @('a.md', 'b.md') -ReportContent $report -ExitCode 1)

        @($results | Where-Object Failed).Count | Should -Be 2
        @($results | Where-Object ParseFailed).Count | Should -Be 0
    }

    It 'Fails closed for every untrustworthy report shape' {
        $expected = @('a.md', 'b.md')
        $cases = @(
            @{ Name = 'absent'; Report = $null }
            @{ Name = 'malformed'; Report = '<testsuites><testsuite>' }
            @{ Name = 'missing file property'; Report = (New-TestMarkdownLinkCheckReport -Suite @(
                @{ IncludeFile = $false; Links = @() }
                @{ File = 'b.md'; Links = @() }
            )) }
            @{ Name = 'empty file property'; Report = (New-TestMarkdownLinkCheckReport -Suite @(
                @{ File = ''; Links = @() }
                @{ File = 'b.md'; Links = @() }
            )) }
            @{ Name = 'duplicate file'; Report = (New-TestMarkdownLinkCheckReport -Suite @(
                @{ File = 'a.md'; Links = @() }
                @{ File = 'a.md'; Links = @() }
            )) }
            @{ Name = 'unexpected file'; Report = (New-TestMarkdownLinkCheckReport -Suite @(
                @{ File = 'a.md'; Links = @() }
                @{ File = 'unexpected.md'; Links = @() }
            )) }
            @{ Name = 'missing expected file'; Report = (New-TestMarkdownLinkCheckReport -Suite @(
                @{ File = 'a.md'; Links = @() }
            )) }
        )

        foreach ($case in $cases) {
            $results = @(ConvertFrom-MarkdownLinkCheckReport -ExpectedFile $expected -ReportContent $case.Report -ExitCode 0)

            @($results | Where-Object Failed).Count | Should -Be 2 -Because $case.Name
            @($results | Where-Object ParseFailed).Count | Should -Be 2 -Because $case.Name
        }
    }

    It 'Retains known dead-link details when incomplete attribution fails the batch' {
        $report = New-TestMarkdownLinkCheckReport -Suite @(
            @{ File = 'a.md'; Links = @(@{ Url = 'https://dead.test'; Status = 'dead'; StatusCode = 404 }) }
        )

        $results = @(ConvertFrom-MarkdownLinkCheckReport -ExpectedFile @('a.md', 'b.md') -ReportContent $report -ExitCode 1)

        @($results | Where-Object Failed).Count | Should -Be 2
        @($results | Where-Object ParseFailed).Count | Should -Be 2
        ($results | Where-Object File -eq 'a.md').Links[0].Url | Should -Be 'https://dead.test'
    }
}

#endregion

#region Script Integration Tests

Describe 'Markdown-Link-Check Integration' -Tag 'Integration' {
    Context 'Config file loading' {
        BeforeAll {
            $script:ConfigPath = Join-Path $PSScriptRoot '../fixtures/Linting/link-check-config.json'
        }

        It 'Config fixture file exists' {
            Test-Path $script:ConfigPath | Should -BeTrue
        }

        It 'Config fixture is valid JSON' {
            { Get-Content $script:ConfigPath | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Config contains expected properties' {
            $config = Get-Content $script:ConfigPath | ConvertFrom-Json
            $config.PSObject.Properties.Name | Should -Contain 'ignorePatterns'
            $config.PSObject.Properties.Name | Should -Contain 'replacementPatterns'
        }
    }

    Context 'Main execution error handling' {
        BeforeAll {
            $script:OriginalGHA = $env:GITHUB_ACTIONS
            $script:LinkCheckScript = Join-Path $PSScriptRoot '../../linting/Markdown-Link-Check.ps1'
        }

        AfterAll {
            if ($null -eq $script:OriginalGHA) {
                Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue
            } else {
                $env:GITHUB_ACTIONS = $script:OriginalGHA
            }
        }

        It 'Outputs GitHub error annotation when script fails in CI' {
            # Arrange
            $env:GITHUB_ACTIONS = 'true'

            # Create temp directory with no markdown files
            $emptyDir = Join-Path $TestDrive 'empty-no-md'
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            # Mock git to simulate no tracked markdown files
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $emptyDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @()  # No markdown files
                }
            }

            # Act - Run script with empty directory (will fail with no files found)
            $output = & $script:LinkCheckScript -Path $emptyDir 2>&1

            # Assert - Should output error
            $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            $errors | Should -Not -BeNullOrEmpty
        }
    }
}

#endregion

#region Invoke-MarkdownLinkCheck Tests

Describe 'Invoke-MarkdownLinkCheck' -Tag 'Unit' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:FixtureConfig = Join-Path $PSScriptRoot '../fixtures/Linting/link-check-config.json'
    }

    Context 'No markdown files found' {
        It 'Throws when Get-MarkdownTarget returns empty' {
            Mock Get-MarkdownTarget { return @() }
            Mock Resolve-Path { return [PSCustomObject]@{ Path = $script:RepoRoot } }

            { Invoke-MarkdownLinkCheck -Path @('nonexistent') -ConfigPath $script:FixtureConfig } |
                Should -Throw '*No markdown files were found to validate*'
        }
    }

    Context 'CLI not installed' {
        It 'Throws when markdown-link-check binary is missing' {
            Mock Get-MarkdownTarget { return @('file.md') }
            Mock Resolve-Path { return [PSCustomObject]@{ Path = $script:RepoRoot } }
            Mock Test-Path { return $false } -ParameterFilter { $LiteralPath -and $LiteralPath -like '*markdown-link-check*' }

            { Invoke-MarkdownLinkCheck -Path @('file.md') -ConfigPath $script:FixtureConfig } |
                Should -Throw '*markdown-link-check is not installed*'
        }
    }

    Context 'Quiet mode base arguments' {
        It 'Passes -q flag when Quiet switch is set' {
            Mock Get-MarkdownTarget { return @('file.md') }
            Mock Test-Path { return $true } -ParameterFilter { $LiteralPath -and $LiteralPath -like '*markdown-link-check*' }
            Mock Resolve-Path { return [PSCustomObject]@{ Path = "$TestDrive/file.md" } } -ParameterFilter { $LiteralPath -eq 'file.md' }
            Mock Write-Host { }
            Mock Invoke-MarkdownLinkCheckBatch { return @() }

            try {
                Invoke-MarkdownLinkCheck -Path @('file.md') -ConfigPath $script:FixtureConfig -Quiet
            }
            catch {
                Write-Verbose "CLI execution expected to fail in test environment: $_"
            }

            Should -Invoke Get-MarkdownTarget -Times 1
            Should -Invoke Invoke-MarkdownLinkCheckBatch -Times 1 -ParameterFilter {
                $BaseArgument -contains '-q'
            }
        }
    }

    Context 'Timestamp standardization' {
        It 'Uses Get-StandardTimestamp for result JSON timestamp' {
            $src = Get-Content (Join-Path $PSScriptRoot '../../linting/Markdown-Link-Check.ps1') -Raw
            $src | Should -Match 'Timestamp\s*=\s*Get-StandardTimestamp'
            $src | Should -Not -Match 'ToUniversalTime\(\)\.ToString'
        }
    }

    Context 'Batched CLI boundary and aggregation' {
        BeforeEach {
            $script:LedgerDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $script:LedgerDir -Force | Out-Null
            $env:MARKDOWN_LINK_CHECK_TEST_LEDGER = $script:LedgerDir
            $script:MarkdownLinkCheckCliOverride = New-TestMarkdownLinkCheckCli -Directory $TestDrive

            $targetDir = Join-Path $TestDrive 'batch-targets'
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            $script:BatchTargets = @('z.md', 'a.md', 'm.md', 'b.md', 'x.md') | ForEach-Object {
                $targetPath = Join-Path $targetDir $_
                Set-Content -LiteralPath $targetPath -Value '# Test' -Encoding utf8
                $targetPath
            }
            $script:ExpectedRelativeTargets = @($script:BatchTargets | ForEach-Object {
                [System.IO.Path]::GetRelativePath($script:RepoRoot, $_)
            } | Sort-Object)

            $script:ResultsPath = Join-Path $script:RepoRoot 'logs/markdown-link-check-results.json'
            $script:ChangedTargets = @()
            $script:OriginalResults = if (Test-Path -LiteralPath $script:ResultsPath) {
                Get-Content -LiteralPath $script:ResultsPath -Raw
            }
            else {
                $null
            }

            Mock Get-MarkdownTarget { return $script:BatchTargets }
            # The orchestrator resolves scope twice: once for the repository-wide
            # source pass and once, with the switch, for the external-link scope.
            Mock Get-MarkdownTarget { return $script:ChangedTargets } -ParameterFilter { $ChangedFilesOnly }
            Mock Write-CIStepSummary { }
            Mock Write-CIAnnotation { }
            Mock Set-CIEnv { }
            Mock Write-Host { }
        }

        AfterEach {
            Remove-Item Env:MARKDOWN_LINK_CHECK_TEST_LEDGER -ErrorAction SilentlyContinue
            Remove-Item Env:MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET -ErrorAction SilentlyContinue
            Remove-Item Env:MARKDOWN_LINK_CHECK_TEST_URL_MODE -ErrorAction SilentlyContinue
            Remove-Item Env:MARKDOWN_LINK_CHECK_TEST_DEAD_URL -ErrorAction SilentlyContinue
            Remove-Item Env:MARKDOWN_LINK_CHECK_TEST_IGNORED_URL -ErrorAction SilentlyContinue
            Remove-Item Env:MARKDOWN_LINK_CHECK_TEST_AGGREGATE_DEFECT -ErrorAction SilentlyContinue
            Remove-Item Env:MARKDOWN_LINK_CHECK_TEST_DEFECT_URL -ErrorAction SilentlyContinue
            Remove-Variable MarkdownLinkCheckCliOverride -Scope Script -ErrorAction SilentlyContinue
            if ($null -ne $script:OriginalResults) {
                Set-Content -LiteralPath $script:ResultsPath -Value $script:OriginalResults -NoNewline -Encoding utf8
            }
            else {
                Remove-Item -LiteralPath $script:ResultsPath -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Invokes bounded source and aggregate processes without flattening or dropping targets' {
            Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ThrottleLimit 2 -Quiet

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $sourceRecords = @($records | Where-Object Stage -eq 'source')
            $aggregateRecords = @($records | Where-Object Stage -eq 'aggregate')
            $recordedTargets = @($sourceRecords | ForEach-Object { @($_.Targets) })

            $sourceRecords.Count | Should -Be 2
            $aggregateRecords.Count | Should -Be 2
            @($sourceRecords | Where-Object { @($_.Targets).Count -eq 0 }).Count | Should -Be 0
            @($sourceRecords | Where-Object { @($_.Targets).Count -gt 1 }).Count | Should -Be 2
            @($aggregateRecords | Where-Object { @($_.Targets).Count -ne 1 }).Count | Should -Be 0
            @($recordedTargets | Sort-Object) | Should -Be $script:ExpectedRelativeTargets
            foreach ($target in $script:ExpectedRelativeTargets) {
                @($recordedTargets | Where-Object { $_ -eq $target }).Count | Should -Be 1
            }
        }

        It 'Checks one shared exact external URL once and replays a dead result to both source files' {
            $sharedUrl = 'https://dead.example.test/shared'
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            $env:MARKDOWN_LINK_CHECK_TEST_DEAD_URL = $sharedUrl
            $script:BatchTargets = @('first.md', 'second.md') | ForEach-Object {
                $targetPath = Join-Path (Split-Path $script:BatchTargets[0] -Parent) $_
                Set-Content -LiteralPath $targetPath -Value "[Shared]($sharedUrl)" -Encoding utf8
                $targetPath
            }

            $captured = @(& {
                try {
                    Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ThrottleLimit 2 -Quiet
                }
                catch {
                    Write-Output "THREW: $($_.Exception.Message)"
                }
            })

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $aggregateUrls = @($records | ForEach-Object { @($_.AggregateUrls) })
            $fetchedUrls = @($records | ForEach-Object { @($_.FetchedUrls) })
            $result = Get-Content -LiteralPath $script:ResultsPath -Raw | ConvertFrom-Json

            @($aggregateUrls | Where-Object { $_ -eq $sharedUrl }).Count | Should -Be 1
            @($fetchedUrls | Where-Object { $_ -eq $sharedUrl }).Count | Should -Be 1
            $result.summary.total_files | Should -Be 2
            $result.summary.files_with_broken_links | Should -Be 2
            $result.summary.total_links_checked | Should -Be 2
            $result.summary.total_broken_links | Should -Be 2
            @($result.broken_links.Link | Where-Object { $_ -eq $sharedUrl }).Count | Should -Be 2
            @($captured | Where-Object { $_ -like 'THREW:*' }).Count | Should -Be 1
            Should -Invoke Write-CIAnnotation -Times 2 -Exactly -ParameterFilter {
                $Level -eq 'Error' -and $Message -like "Broken link: $sharedUrl*"
            }
        }

        It 'Keeps exact variants disjoint and preserves original ignored-link behavior' {
            $sharedUrl = 'https://example.test/shared'
            $queryUrl = 'https://example.test/shared?view=one'
            $fragmentUrl = 'https://example.test/shared#section'
            $ignoredUrl = 'https://ignored.example.test/link'
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            $env:MARKDOWN_LINK_CHECK_TEST_IGNORED_URL = $ignoredUrl
            $targetDir = Split-Path $script:BatchTargets[0] -Parent
            $script:BatchTargets = @(
                @{ Name = 'first.md'; Content = "[Shared]($sharedUrl)`n[Query]($queryUrl)" }
                @{ Name = 'second.md'; Content = "[Shared]($sharedUrl)`n[Fragment]($fragmentUrl)" }
                @{ Name = 'third.md'; Content = "[Ignored]($ignoredUrl)" }
            ) | ForEach-Object {
                $targetPath = Join-Path $targetDir $_.Name
                Set-Content -LiteralPath $targetPath -Value $_.Content -Encoding utf8
                $targetPath
            }

            Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ThrottleLimit 2 -Quiet

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $aggregateRecords = @($records | Where-Object Stage -eq 'aggregate')
            $aggregateUrls = @($aggregateRecords | ForEach-Object { @($_.AggregateUrls) })
            $fetchedUrls = @($records | ForEach-Object { @($_.FetchedUrls) })
            $result = Get-Content -LiteralPath $script:ResultsPath -Raw | ConvertFrom-Json

            $aggregateRecords.Count | Should -Be 2
            @($aggregateUrls | Sort-Object) | Should -Be @($fragmentUrl, $ignoredUrl, $queryUrl, $sharedUrl | Sort-Object)
            foreach ($url in @($sharedUrl, $queryUrl, $fragmentUrl, $ignoredUrl)) {
                @($aggregateUrls | Where-Object { $_ -eq $url }).Count | Should -Be 1
            }
            @($fetchedUrls | Where-Object { $_ -eq $sharedUrl }).Count | Should -Be 1
            @($fetchedUrls | Where-Object { $_ -eq $queryUrl }).Count | Should -Be 1
            @($fetchedUrls | Where-Object { $_ -eq $fragmentUrl }).Count | Should -Be 1
            @($fetchedUrls | Where-Object { $_ -eq $ignoredUrl }).Count | Should -Be 0
            $result.summary.total_files | Should -Be 3
            $result.summary.total_links_checked | Should -Be 5
            $result.summary.total_broken_links | Should -Be 0
        }

        It 'Supports a checker config that omits ignorePatterns' {
            $configWithoutIgnorePatterns = Join-Path $TestDrive 'config-without-ignore-patterns.json'
            @{
                projectBaseUrl = '.'
                timeout = '20s'
                retryOn429 = $true
                replacementPatterns = @()
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configWithoutIgnorePatterns -Encoding utf8
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            $targetDir = Split-Path $script:BatchTargets[0] -Parent
            $targetPath = Join-Path $targetDir 'without-ignore-patterns.md'
            Set-Content -LiteralPath $targetPath -Value '[Link](https://example.test/config)' -Encoding utf8
            $script:BatchTargets = @($targetPath)

            { Invoke-MarkdownLinkCheck `
                -Path @('unused') `
                -ConfigPath $configWithoutIgnorePatterns `
                -ThrottleLimit 1 `
                -Quiet } | Should -Not -Throw

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $sourceRecord = @($records | Where-Object Stage -eq 'source')
            $sourceRecord.Count | Should -Be 1
            @($sourceRecord[0].IgnorePatterns).Count | Should -Be 1
            $sourceRecord[0].IgnorePatterns[0].pattern | Should -Be '^[Hh][Tt][Tt][Pp][Ss]?://'
        }

        It 'Fails only the source file mapped to an aggregate with <Defect>' -ForEach @(
            @{ Defect = 'missing-url-property' }
            @{ Defect = 'duplicate-url-property' }
            @{ Defect = 'missing-status-property' }
            @{ Defect = 'duplicate-status-property' }
            @{ Defect = 'duplicate-status-code-property' }
            @{ Defect = 'unsupported-status' }
            @{ Defect = 'missing-result' }
            @{ Defect = 'duplicate-result' }
            @{ Defect = 'unexpected-result' }
            @{ Defect = 'unexplained-exit' }
        ) {
            $defectUrl = 'https://example.test/defect'
            $healthyUrl = 'https://example.test/healthy'
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            $env:MARKDOWN_LINK_CHECK_TEST_AGGREGATE_DEFECT = $Defect
            $env:MARKDOWN_LINK_CHECK_TEST_DEFECT_URL = $defectUrl
            $targetDir = Split-Path $script:BatchTargets[0] -Parent
            $script:BatchTargets = @(
                @{ Name = 'defect.md'; Url = $defectUrl }
                @{ Name = 'healthy.md'; Url = $healthyUrl }
            ) | ForEach-Object {
                $targetPath = Join-Path $targetDir $_.Name
                Set-Content -LiteralPath $targetPath -Value "[Link]($($_.Url))" -Encoding utf8
                $targetPath
            }

            $captured = @(& {
                try {
                    Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ThrottleLimit 2 -Quiet
                }
                catch {
                    Write-Output "THREW: $($_.Exception.Message)"
                }
            })

            $result = Get-Content -LiteralPath $script:ResultsPath -Raw | ConvertFrom-Json
            $result.summary.files_with_broken_links | Should -Be 1
            $result.summary.total_broken_links | Should -Be 0
            @($captured | Where-Object { $_ -like 'THREW:*' }).Count | Should -Be 1
            Should -Invoke Write-CIAnnotation -Times 0 -Exactly
        }

        It 'Removes one common task workspace after <Outcome>' -ForEach @(
            @{ Outcome = 'success'; Defect = $null; Dead = $false }
            @{ Outcome = 'dead link'; Defect = $null; Dead = $true }
            @{ Outcome = 'malformed report'; Defect = 'malformed-xml'; Dead = $false }
            @{ Outcome = 'invocation error'; Defect = 'invocation-error'; Dead = $false }
        ) {
            $url = 'https://example.test/cleanup'
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            if ($Dead) {
                $env:MARKDOWN_LINK_CHECK_TEST_DEAD_URL = $url
            }
            if ($Defect) {
                $env:MARKDOWN_LINK_CHECK_TEST_AGGREGATE_DEFECT = $Defect
                $env:MARKDOWN_LINK_CHECK_TEST_DEFECT_URL = $url
            }
            $targetDir = Split-Path $script:BatchTargets[0] -Parent
            $targetPath = Join-Path $targetDir 'cleanup.md'
            Set-Content -LiteralPath $targetPath -Value "[Cleanup]($url)" -Encoding utf8
            $script:BatchTargets = @($targetPath)

            try {
                Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ThrottleLimit 1 -Quiet
            }
            catch {
                Write-Verbose "Expected controlled $Outcome result: $_"
            }

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $derivedConfig = @($records.ConfigPath | Where-Object {
                [System.IO.Path]::GetFileName($_) -eq 'source-config.json'
            } | Select-Object -Unique)
            $derivedConfig.Count | Should -Be 1
            $taskRoot = Split-Path $derivedConfig[0] -Parent
            $taskPaths = @(
                $derivedConfig
                $records.JunitOutput
                $records | Where-Object Stage -eq 'aggregate' | ForEach-Object { @($_.Targets) }
            )
            @($taskPaths | Where-Object { -not $_.StartsWith($taskRoot, [System.StringComparison]::Ordinal) }).Count | Should -Be 0
            Test-Path -LiteralPath $taskRoot | Should -BeFalse
        }

        It 'Preserves mixed batch JSON, annotation, summary, and sorted output semantics' {
            $env:MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET = $script:ExpectedRelativeTargets[2]

            $captured = @(& {
                try {
                    Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ThrottleLimit 2 -Quiet
                }
                catch {
                    Write-Output "THREW: $($_.Exception.Message)"
                }
            })

            $result = Get-Content -LiteralPath $script:ResultsPath -Raw | ConvertFrom-Json
            @($result.PSObject.Properties.Name | Sort-Object) | Should -Be @('broken_links', 'script', 'summary', 'Timestamp')
            $result.summary.total_files | Should -Be 5
            $result.summary.files_with_broken_links | Should -Be 1
            $result.summary.total_links_checked | Should -Be 5
            $result.summary.skipped_links | Should -Be 0
            $result.summary.total_broken_links | Should -Be 1
            $result.broken_links[0].File | Should -Be $env:MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET
            @($captured | Where-Object { $_ -like 'Checking *' } | ForEach-Object { $_ -replace '^Checking ', '' }) |
                Should -Be $script:ExpectedRelativeTargets
            @($captured | Where-Object { $_ -like 'THREW:*' }).Count | Should -Be 1
            Should -Invoke Write-CIAnnotation -Times 1 -Exactly -ParameterFilter {
                $Level -eq 'Error' -and $File -eq $env:MARKDOWN_LINK_CHECK_TEST_DEAD_TARGET
            }
            Should -Invoke Write-CIStepSummary -Times 1 -Exactly -ParameterFilter {
                $Content -match 'Files with broken links:\*\* 1 / 5' -and
                $Content -match 'Total broken links:\*\* 1'
            }
        }

        It 'Validates internal links repository-wide and skips external checks when no markdown changed' {
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            $targetDir = Split-Path $script:BatchTargets[0] -Parent
            $targetPath = Join-Path $targetDir 'unchanged.md'
            Set-Content -LiteralPath $targetPath -Value '[External](https://example.test/unchanged)' -Encoding utf8
            $script:BatchTargets = @($targetPath)
            $script:ChangedTargets = @()

            $output = @(Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ChangedFilesOnly -ThrottleLimit 2 -Quiet)

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $result = Get-Content -LiteralPath $script:ResultsPath -Raw | ConvertFrom-Json

            @($output | Where-Object {
                $_ -eq 'No changed markdown files; external link validation was skipped.'
            }).Count | Should -Be 1
            @($records | Where-Object Stage -eq 'source').Count | Should -BeGreaterThan 0
            @($records | Where-Object Stage -eq 'aggregate').Count | Should -Be 0
            $result.summary.total_files | Should -Be 1
            $result.summary.files_with_broken_links | Should -Be 0
            $result.summary.total_links_checked | Should -Be 0
            $result.summary.skipped_links | Should -Be 1
            $result.summary.total_broken_links | Should -Be 0
        }

        It 'Fetches a shared URL for the changed file and reports the unchanged file as skipped' {
            $sharedUrl = 'https://example.test/shared-scope'
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            $targetDir = Split-Path $script:BatchTargets[0] -Parent
            $script:BatchTargets = @('changed.md', 'unchanged.md') | ForEach-Object {
                $targetPath = Join-Path $targetDir $_
                Set-Content -LiteralPath $targetPath -Value "[Shared]($sharedUrl)" -Encoding utf8
                $targetPath
            }
            $script:ChangedTargets = @($script:BatchTargets[0])

            Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ChangedFilesOnly -ThrottleLimit 2 -Quiet

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $fetchedUrls = @($records | ForEach-Object { @($_.FetchedUrls) })
            $result = Get-Content -LiteralPath $script:ResultsPath -Raw | ConvertFrom-Json

            @($fetchedUrls | Where-Object { $_ -eq $sharedUrl }).Count | Should -Be 1
            $result.summary.total_files | Should -Be 2
            $result.summary.total_links_checked | Should -Be 1
            $result.summary.skipped_links | Should -Be 1
            $result.summary.files_with_broken_links | Should -Be 0
            $result.summary.total_broken_links | Should -Be 0
        }

        It 'Fails an in-scope file closed for a missing aggregate result while an out-of-scope file is unaffected' {
            $env:MARKDOWN_LINK_CHECK_TEST_URL_MODE = 'true'
            $env:MARKDOWN_LINK_CHECK_TEST_AGGREGATE_DEFECT = 'malformed-xml'
            $targetDir = Split-Path $script:BatchTargets[0] -Parent
            $inScope = Join-Path $targetDir 'in-scope.md'
            Set-Content -LiteralPath $inScope -Value '[In](https://example.test/in-scope)' -Encoding utf8
            $outOfScope = Join-Path $targetDir 'out-of-scope.md'
            Set-Content -LiteralPath $outOfScope -Value '[Out](https://example.test/out-of-scope)' -Encoding utf8
            $script:BatchTargets = @($inScope, $outOfScope)
            $script:ChangedTargets = @($inScope)

            $captured = @(& {
                try {
                    Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ChangedFilesOnly -ThrottleLimit 2 -Quiet
                }
                catch {
                    Write-Output "THREW: $($_.Exception.Message)"
                }
            })

            $records = @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json' | ForEach-Object {
                Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            })
            $aggregateUrls = @($records | ForEach-Object { @($_.AggregateUrls) })
            $result = Get-Content -LiteralPath $script:ResultsPath -Raw | ConvertFrom-Json

            @($aggregateUrls | Where-Object { $_ -eq 'https://example.test/out-of-scope' }).Count | Should -Be 0
            $result.summary.total_files | Should -Be 2
            $result.summary.files_with_broken_links | Should -Be 1
            @($captured | Where-Object { $_ -like 'THREW:*' }).Count | Should -Be 1
        }

        It 'Throws when the repository-wide target set is empty even with the changed-files switch' {
            $script:BatchTargets = @()
            $script:ChangedTargets = @()

            { Invoke-MarkdownLinkCheck -Path @('unused') -ConfigPath $script:FixtureConfig -ChangedFilesOnly -ThrottleLimit 2 -Quiet } |
                Should -Throw -ExpectedMessage 'No markdown files were found to validate.'
            @(Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.json').Count | Should -Be 0
        }
    }
}

#endregion
