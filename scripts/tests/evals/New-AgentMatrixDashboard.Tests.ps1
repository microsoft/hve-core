#Requires -Modules Pester
#Requires -Modules powershell-yaml
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/New-AgentMatrixDashboard.ps1'
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..') | Select-Object -ExpandProperty Path
    $script:FixturesModule = Join-Path $PSScriptRoot '_AgentMatrixFixtures.psm1'

    . $script:ScriptPath
    Import-Module $script:FixturesModule -Force
}

AfterAll {
    Remove-Module _AgentMatrixFixtures -Force -ErrorAction SilentlyContinue
}

Describe 'New-AgentMatrixDashboard.ps1' -Tag 'Unit' {

    BeforeEach {
        $script:Fix = New-FixtureRoot -Base $TestDrive
        New-FixtureInventory -Path $script:Fix.InventoryPath -Agents @(
            @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light' },
            @{ slug = 'task-planner';    class = 'research-writer'; cost_tier = 'light' },
            @{ slug = 'task-reviewer';   class = 'research-writer'; cost_tier = 'standard' }
        )
        # Surface signatures: present for researcher, missing for planner/reviewer.
        Set-Content -LiteralPath (Join-Path $script:Fix.SurfaceRoot 'task-researcher.yml') `
            -Value "required: []`ndisallowed: []`n" -Encoding utf8NoBOM
        $script:OutPath = Join-Path $TestDrive ("dash-" + [Guid]::NewGuid().ToString('N') + '.html')
    }

    Context 'Latest dated folder is auto-selected' {
        BeforeEach {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-24' -Results @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
                @{ slug = 'task-planner';    class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
                @{ slug = 'task-reviewer';   class = 'research-writer'; cost_tier = 'standard'; overall = 'fail'; exitCode = 1 }
            ) | Out-Null
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-25' -Results @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
                @{ slug = 'task-planner';    class = 'research-writer'; cost_tier = 'light'; overall = 'fail'; exitCode = 1 }
                @{ slug = 'task-reviewer';   class = 'research-writer'; cost_tier = 'standard'; overall = 'fail'; exitCode = 1 }
            ) -Overall 'fail' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Writes an HTML file' {
            Test-Path -LiteralPath $script:OutPath | Should -BeTrue
            $script:Html | Should -Match '<!doctype html>'
        }

        It 'Renders one row per inventory agent' {
            $tbody = [regex]::Match($script:Html, '(?s)<tbody>(.*?)</tbody>').Groups[1].Value
            ([regex]::Matches($tbody, '<tr class="row"')).Count | Should -Be 3
        }

        It 'Renders one drill row per inventory agent' {
            $tbody = [regex]::Match($script:Html, '(?s)<tbody>(.*?)</tbody>').Groups[1].Value
            ([regex]::Matches($tbody, '<tr class="drill"')).Count | Should -Be 3
        }

        It 'Pairs every drill row with a matching agent row by slug' {
            $slugSet = [regex]::Matches($script:Html, 'data-slug="([^"]+)"') |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
            $drillForSet = [regex]::Matches($script:Html, 'data-drill-for="([^"]+)"') |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
            $drillForSet | Should -Be $slugSet
        }

        It 'Renders each drill row immediately after its matching agent row' {
            $tbody = [regex]::Match($script:Html, '(?s)<tbody>(.*?)</tbody>').Groups[1].Value
            $pattern = '<tr class="(row|drill)"[^>]*?data-(?:slug|drill-for)="([^"]+)"'
            $trMatches = @([regex]::Matches($tbody, $pattern))
            $trMatches.Count | Should -Be 6
            for ($i = 0; $i -lt $trMatches.Count; $i += 2) {
                $trMatches[$i].Groups[1].Value     | Should -Be 'row'
                $trMatches[$i + 1].Groups[1].Value | Should -Be 'drill'
                $trMatches[$i + 1].Groups[2].Value | Should -Be $trMatches[$i].Groups[2].Value
            }
        }

        It 'Links each agent slug to its per-agent JSON in the same dated folder' {
            $script:Html | Should -Match 'href="task-researcher\.json">task-researcher</a>'
            $script:Html | Should -Match 'href="task-planner\.json">task-planner</a>'
            $script:Html | Should -Match 'href="task-reviewer\.json">task-reviewer</a>'
        }

        It 'Uses the most recent dated folder as the run' {
            $script:Html | Should -Match '2026-05-25'
            $script:Html | Should -Not -Match '<strong>2026-05-24</strong>'
        }

        It 'Computes last functional pass from prior dated folders' {
            # task-planner passed on 2026-05-24 but failed on 2026-05-25.
            $script:Html | Should -Match '<td>2026-05-24</td>'
        }

        It 'Marks surface signature presence per agent' {
            $script:Html | Should -Match 'class="present">present</td>'
            $script:Html | Should -Match 'class="missing">missing</td>'
        }

        It 'Reports the matrix-level overall verdict in the header' {
            $script:Html | Should -Match 'Overall: <strong>fail</strong>'
        }
    }

    Context 'Explicit SummaryPath input' {
        BeforeEach {
            $script:SummaryPath = New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-26' -Results @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
                @{ slug = 'task-planner';    class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
                @{ slug = 'task-reviewer';   class = 'research-writer'; cost_tier = 'standard'; overall = 'pass' }
            )
            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -SummaryPath $script:SummaryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Honors the explicit summary path' {
            $script:Html | Should -Match '2026-05-26'
        }

        It 'Reports overall pass when all rows pass' {
            $script:Html | Should -Match 'Overall: <strong>pass</strong>'
        }
    }

    Context 'Inventory rows missing from summary' {
        BeforeEach {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-27' -Results @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
            ) -Overall 'pass' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Still renders one row per inventory agent' {
            $tbody = [regex]::Match($script:Html, '(?s)<tbody>(.*?)</tbody>').Groups[1].Value
            ([regex]::Matches($tbody, '<tr class="row"')).Count | Should -Be 3
        }

        It 'Still renders one drill row per inventory agent' {
            $tbody = [regex]::Match($script:Html, '(?s)<tbody>(.*?)</tbody>').Groups[1].Value
            ([regex]::Matches($tbody, '<tr class="drill"')).Count | Should -Be 3
        }

        It 'Marks unrun agents as unknown without a per-agent link' {
            $script:Html | Should -Match 'class="unknown">unknown</td>'
            $script:Html | Should -Not -Match 'href="task-planner\.json"'
        }
    }

    Context 'Drill grader content' {
        BeforeEach {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-29' -Results @(
                @{
                    slug      = 'task-researcher'
                    class     = 'research-writer'
                    cost_tier = 'light'
                    overall   = 'pass'
                    graders   = @(
                        @{ name = 'surface'; status = 'pass'; message = 'all clear' },
                        @{ name = 'rubric';  status = 'fail'; message = 'missing intro' }
                    )
                },
                @{ slug = 'task-planner';  class = 'research-writer'; cost_tier = 'light';    overall = 'pass' },
                @{ slug = 'task-reviewer'; class = 'research-writer'; cost_tier = 'standard'; overall = 'pass' }
            ) -Overall 'pass' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Renders a grader table inside the drill row when graders are present' {
            $script:Html | Should -Match '<table class="drill-graders">'
            $script:Html | Should -Match '<th>Grader</th><th>Status</th><th>Evidence / Message</th><th>Pattern</th>'
        }

        It 'Renders one grader row per recorded grader result' {
            $graderTable = [regex]::Match(
                $script:Html,
                '(?s)<table class="drill-graders">.*?</table>'
            ).Value
            ([regex]::Matches($graderTable, '<tr><td>[^<]+</td><td class="[^"]+">[^<]+</td>')).Count |
                Should -Be 2
        }

        It 'Reflects each grader name, status, and message in the rendered cells' {
            $script:Html | Should -Match '<td>surface</td><td class="pass">pass</td><td>all clear</td>'
            $script:Html | Should -Match '<td>rubric</td><td class="fail">fail</td><td>missing intro</td>'
        }

        It 'Shows the drill-empty placeholder for agents with no grader results' {
            $script:Html | Should -Match 'class="drill-empty">No grader results recorded\.'
        }

        It 'Always shows the drill-meta exit code line for every drill row' {
            ([regex]::Matches($script:Html, 'class="drill-meta">Exit code:')).Count |
                Should -Be 3
        }
    }

    Context 'Drill grader HTML escaping' {
        BeforeEach {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-30' -Results @(
                @{
                    slug      = 'task-researcher'
                    class     = 'research-writer'
                    cost_tier = 'light'
                    overall   = 'pass'
                    graders   = @(
                        @{
                            name    = '<script>alert(1)</script>'
                            status  = 'pass'
                            message = 'Tom & "Jerry" <bad>'
                        }
                    )
                },
                @{ slug = 'task-planner';  class = 'research-writer'; cost_tier = 'light';    overall = 'pass' },
                @{ slug = 'task-reviewer'; class = 'research-writer'; cost_tier = 'standard'; overall = 'pass' }
            ) -Overall 'pass' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Escapes the grader name in the rendered table cell' {
            $script:Html | Should -Match '<td>&lt;script&gt;alert\(1\)&lt;/script&gt;</td>'
        }

        It 'Escapes the grader message ampersand, quote, and angle brackets' {
            $script:Html | Should -Match '<td>Tom &amp; &quot;Jerry&quot; &lt;bad&gt;</td>'
        }

        It 'Does not emit the raw injected script payload' {
            $script:Html | Should -Not -Match '<td><script>alert\(1\)</script></td>'
        }
    }

    Context 'Drill grader unknown status fallback' {
        BeforeEach {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-31' -Results @(
                @{
                    slug      = 'task-researcher'
                    class     = 'research-writer'
                    cost_tier = 'light'
                    overall   = 'pass'
                    graders   = @(
                        @{ name = 'experimental'; status = 'flaky'; message = 'needs retry' }
                    )
                },
                @{ slug = 'task-planner';  class = 'research-writer'; cost_tier = 'light';    overall = 'pass' },
                @{ slug = 'task-reviewer'; class = 'research-writer'; cost_tier = 'standard'; overall = 'pass' }
            ) -Overall 'pass' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Renders an unrecognized grader status with the unknown class' {
            $script:Html | Should -Match '<td>experimental</td><td class="unknown">flaky</td><td>needs retry</td>'
        }

        It 'Does not render the unrecognized status with pass, fail, or dry-run classes' {
            $script:Html | Should -Not -Match '<td class="pass">flaky</td>'
            $script:Html | Should -Not -Match '<td class="fail">flaky</td>'
            $script:Html | Should -Not -Match '<td class="dry-run">flaky</td>'
        }
    }

    Context 'Drill-meta exit code per agent' {
        BeforeEach {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-06-03' -Results @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light';    overall = 'pass'; exitCode = 0 }
                @{ slug = 'task-planner';    class = 'research-writer'; cost_tier = 'light';    overall = 'fail'; exitCode = 1 }
                @{ slug = 'task-reviewer';   class = 'research-writer'; cost_tier = 'standard'; overall = 'fail'; exitCode = 42 }
            ) -Overall 'fail' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Renders the exitCode from the per-agent payload in the drill-meta line for <Slug>' -TestCases @(
            @{ Slug = 'task-researcher'; Expected = '0' }
            @{ Slug = 'task-planner';    Expected = '1' }
            @{ Slug = 'task-reviewer';   Expected = '42' }
        ) {
            param($Slug, $Expected)
            $pattern = Get-DrillRowRegex `
                -Slug $Slug `
                -Inner ('class="drill-meta">Exit code: <strong>' + [regex]::Escape($Expected) + '</strong>')
            $script:Html | Should -Match $pattern
        }
    }

    Context 'Drill-empty placeholder when multiple agents have no graders' {
        BeforeEach {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-31' -Results @(
                @{
                    slug      = 'task-researcher'
                    class     = 'research-writer'
                    cost_tier = 'light'
                    overall   = 'pass'
                    graders   = @(
                        @{ name = 'surface'; status = 'pass'; message = 'ok' }
                    )
                }
                @{
                    slug      = 'task-planner'
                    class     = 'research-writer'
                    cost_tier = 'light'
                    overall   = 'pass'
                    graders   = @()
                }
                @{
                    slug      = 'task-reviewer'
                    class     = 'research-writer'
                    cost_tier = 'standard'
                    overall   = 'fail'
                    exitCode  = 2
                    graders   = @()
                }
            ) -Overall 'partial' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Renders one placeholder per agent with no graders' {
            ([regex]::Matches($script:Html, 'class="drill-empty">No grader results recorded\.')).Count |
                Should -Be 2
        }

        It 'Anchors the placeholder inside the drill row for <Slug>' -TestCases @(
            @{ Slug = 'task-planner' }
            @{ Slug = 'task-reviewer' }
        ) {
            param($Slug)
            $pattern = Get-DrillRowRegex `
                -Slug $Slug `
                -Inner 'class="drill-empty">No grader results recorded\.'
            $script:Html | Should -Match $pattern
        }

        It 'Does not emit a drill-graders table for agent <Slug>' -TestCases @(
            @{ Slug = 'task-planner' }
            @{ Slug = 'task-reviewer' }
        ) {
            param($Slug)
            $pattern = Get-DrillRowRegex -Slug $Slug -Inner 'class="drill-graders"'
            $script:Html | Should -Not -Match $pattern
        }

        It 'Still renders the drill-graders table for the agent that has graders' {
            $pattern = Get-DrillRowRegex -Slug 'task-researcher' -Inner 'class="drill-graders"'
            $script:Html | Should -Match $pattern
        }
    }

    Context 'Header overall verdict variants' {
        It 'Renders the matrix-level overall verdict in the header for <Verdict>' -TestCases @(
            @{ Verdict = 'pass';    Date = '2026-06-01' }
            @{ Verdict = 'partial'; Date = '2026-06-02' }
        ) {
            param($Verdict, $Date)
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date $Date -Results @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
            ) -Overall $Verdict | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $html = Get-Content -LiteralPath $script:OutPath -Raw
            $html | Should -Match "Overall: <strong>$Verdict</strong>"
        }
    }

    Context 'Failure modes' {
        It 'Throws when no dated summary exists' {
            { & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath } | Should -Throw -ExpectedMessage '*No agent-matrix-summary.json found*'
        }

        It 'Throws when SummaryPath does not exist' {
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-28' -Results @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light'; overall = 'pass' }
            ) | Out-Null
            { & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -SummaryPath (Join-Path $TestDrive 'does-not-exist.json') `
                -OutPath $script:OutPath } | Should -Throw -ExpectedMessage '*Summary file not found*'
        }
    }
}

Describe 'New-AgentMatrixDashboard helpers' -Tag 'Unit' {

    Context 'Edit-HtmlEscape via dot-sourced module' {
        It 'Is available after dot-sourcing the script' {
            Get-Command Edit-HtmlEscape -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ConvertTo-AgentMatrixRows' {
        BeforeEach {
            $script:Inventory = [System.Collections.Generic.List[hashtable]]::new()
            $script:Inventory.Add(@{ slug = 'a'; class = 'c1'; cost_tier = 'light' })
            $script:Inventory.Add(@{ slug = 'b'; class = 'c2'; cost_tier = 'standard' })

            $script:Summary = [pscustomobject]@{
                results = @(
                    [pscustomobject]@{ slug = 'a'; overall = 'pass'; exitCode = 0 }
                )
            }

            $script:SummaryDir = Join-Path $TestDrive ("sumdir-" + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $script:SummaryDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:SummaryDir 'a.json') -Value '{}' -Encoding utf8NoBOM

            $script:SurfaceDir = Join-Path $TestDrive ("surf-" + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $script:SurfaceDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:SurfaceDir 'a.yml') -Value 'required: []' -Encoding utf8NoBOM
        }

        It 'Returns one row per inventory agent regardless of summary coverage' {
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:Inventory -Summary $script:Summary -SummaryDir $script:SummaryDir -SurfaceSignaturesRoot $script:SurfaceDir -LastPassBySlug @{}
            $rows.Count | Should -Be 2
            $rows[0].slug | Should -Be 'a'
            $rows[0].functional | Should -Be 'pass'
            $rows[0].perAgentHref | Should -Be 'a.json'
            $rows[0].surface | Should -Be 'present'
            $rows[1].slug | Should -Be 'b'
            $rows[1].functional | Should -Be 'unknown'
            $rows[1].perAgentHref | Should -Be ''
            $rows[1].surface | Should -Be 'missing'
        }
    }

    Context 'ConvertTo-AgentMatrixRows negative paths' {
        BeforeEach {
            $script:NegInventory = [System.Collections.Generic.List[hashtable]]::new()
            $script:NegInventory.Add(@{ slug = 'a'; class = 'c1'; cost_tier = 'light' })
            $script:NegInventory.Add(@{ slug = 'b'; class = 'c2'; cost_tier = 'standard' })

            $script:NegSummaryDir = Join-Path $TestDrive ("negsumdir-" + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $script:NegSummaryDir -Force | Out-Null

            $script:NegSurfaceDir = Join-Path $TestDrive ("negsurf-" + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $script:NegSurfaceDir -Force | Out-Null
        }

        It 'Treats a summary without a results property as zero coverage' {
            $summary = [pscustomobject]@{ generatedAt = '2026-05-01T00:00:00Z' }
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:NegInventory -Summary $summary -SummaryDir $script:NegSummaryDir -SurfaceSignaturesRoot $script:NegSurfaceDir -LastPassBySlug @{}
            $rows.Count | Should -Be 2
            $rows[0].functional | Should -Be 'unknown'
            $rows[1].functional | Should -Be 'unknown'
        }

        It 'Skips summary entries that have no slug property' {
            $summary = [pscustomobject]@{
                results = @(
                    [pscustomobject]@{ overall = 'pass'; exitCode = 0 }
                    [pscustomobject]@{ slug = 'a'; overall = 'fail'; exitCode = 1 }
                )
            }
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:NegInventory -Summary $summary -SummaryDir $script:NegSummaryDir -SurfaceSignaturesRoot $script:NegSurfaceDir -LastPassBySlug @{}
            ($rows | Where-Object { $_.slug -eq 'a' }).functional | Should -Be 'fail'
            ($rows | Where-Object { $_.slug -eq 'b' }).functional | Should -Be 'unknown'
        }

        It 'Defaults exitCode to -1 when the summary row omits it' {
            $summary = [pscustomobject]@{
                results = @([pscustomobject]@{ slug = 'a'; overall = 'pass' })
            }
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:NegInventory -Summary $summary -SummaryDir $script:NegSummaryDir -SurfaceSignaturesRoot $script:NegSurfaceDir -LastPassBySlug @{}
            ($rows | Where-Object { $_.slug -eq 'a' }).exitCode | Should -Be -1
        }

        It 'Defaults logPath and perAgentHref to empty strings when artifacts are missing' {
            $summary = [pscustomobject]@{
                results = @([pscustomobject]@{ slug = 'a'; overall = 'pass'; exitCode = 0 })
            }
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:NegInventory -Summary $summary -SummaryDir $script:NegSummaryDir -SurfaceSignaturesRoot $script:NegSurfaceDir -LastPassBySlug @{}
            $a = $rows | Where-Object { $_.slug -eq 'a' }
            $a.logPath      | Should -Be ''
            $a.perAgentHref | Should -Be ''
        }

        It 'Returns an array with zero graders when the summary row omits graders' {
            $summary = [pscustomobject]@{
                results = @([pscustomobject]@{ slug = 'a'; overall = 'pass'; exitCode = 0 })
            }
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:NegInventory -Summary $summary -SummaryDir $script:NegSummaryDir -SurfaceSignaturesRoot $script:NegSurfaceDir -LastPassBySlug @{}
            $a = $rows | Where-Object { $_.slug -eq 'a' }
            ,$a.graders       | Should -BeOfType ([array])
            $a.graders.Count  | Should -Be 0
        }

        It 'Skips $null grader entries and tolerates missing grader properties' {
            $summary = [pscustomobject]@{
                results = @(
                    [pscustomobject]@{
                        slug    = 'a'
                        overall = 'pass'
                        graders = @(
                            $null,
                            [pscustomobject]@{ name = 'rubric' }
                        )
                    }
                )
            }
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:NegInventory -Summary $summary -SummaryDir $script:NegSummaryDir -SurfaceSignaturesRoot $script:NegSurfaceDir -LastPassBySlug @{}
            $a = $rows | Where-Object { $_.slug -eq 'a' }
            $a.graders.Count   | Should -Be 1
            $a.graders[0].name | Should -Be 'rubric'
            $a.graders[0].status  | Should -Be 'unknown'
            $a.graders[0].message | Should -Be ''
        }

        It 'Uses LastPassBySlug only for matching slugs' {
            $summary = [pscustomobject]@{
                results = @([pscustomobject]@{ slug = 'a'; overall = 'pass'; exitCode = 0 })
            }
            $rows = ConvertTo-AgentMatrixRows -Inventory $script:NegInventory -Summary $summary -SummaryDir $script:NegSummaryDir -SurfaceSignaturesRoot $script:NegSurfaceDir -LastPassBySlug @{ 'a' = '2026-05-01' }
            ($rows | Where-Object { $_.slug -eq 'a' }).lastPass | Should -Be '2026-05-01'
            ($rows | Where-Object { $_.slug -eq 'b' }).lastPass | Should -Be ''
        }
    }

    Context 'Filter controls' {
        BeforeEach {
            $script:Fix = New-FixtureRoot -Base $TestDrive
            New-FixtureInventory -Path $script:Fix.InventoryPath -Agents @(
                @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light' },
                @{ slug = 'task-planner';    class = 'research-writer'; cost_tier = 'light' },
                @{ slug = 'task-reviewer';   class = 'research-writer'; cost_tier = 'standard' }
            )
            $script:OutPath = Join-Path $TestDrive ("dash-" + [Guid]::NewGuid().ToString('N') + '.html')
            New-FixtureDatedRun -MatrixRoot $script:Fix.MatrixRoot -Date '2026-05-30' -Results @(
                @{
                    slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light'; overall = 'fail'; exitCode = 1
                    graders = @(
                        @{ name = 'grader-a'; status = 'fail'; message = 'a1' },
                        @{ name = 'grader-a'; status = 'fail'; message = 'a2' },
                        @{ name = 'grader-b'; status = 'fail'; message = 'b1' }
                    )
                },
                @{
                    slug = 'task-planner'; class = 'research-writer'; cost_tier = 'light'; overall = 'fail'; exitCode = 1
                    graders = @(
                        @{ name = 'grader-a'; status = 'fail'; message = 'a3' },
                        @{ name = 'grader-c'; status = 'fail'; message = 'c1' }
                    )
                },
                @{
                    slug = 'task-reviewer'; class = 'research-writer'; cost_tier = 'standard'; overall = 'pass'
                    graders = @(
                        @{ name = 'grader-a'; status = 'fail'; message = 'a4' },
                        @{ name = 'grader-b'; status = 'pass'; message = 'ok' }
                    )
                }
            ) -Overall 'fail' | Out-Null

            & $script:ScriptPath `
                -RepoRoot $script:Fix.Root `
                -AgentMatrixRoot $script:Fix.MatrixRoot `
                -SurfaceSignaturesRoot $script:Fix.SurfaceRoot `
                -InventoryPath $script:Fix.InventoryPath `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Sorts the failing-grader dropdown by frequency descending' {
            $select = [regex]::Match(
                $script:Html,
                '(?s)<select\s+id="filter-failing-grader"[^>]*>(.*?)</select>'
            ).Groups[1].Value
            $select | Should -Not -BeNullOrEmpty
            $values = [regex]::Matches($select, '<option\s+value="([^"]+)"') |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -ne '' }
            $values[0] | Should -Be 'grader-a'
            # grader-b and grader-c tie at count 1, sorted alphabetically.
            $values[1] | Should -Be 'grader-b'
            $values[2] | Should -Be 'grader-c'
        }

        It 'Renders the failing-grader option labels with count suffixes' {
            $script:Html | Should -Match '<option value="grader-a">grader-a \(3\)</option>'
            $script:Html | Should -Match '<option value="grader-b">grader-b \(1\)</option>'
            $script:Html | Should -Match '<option value="grader-c">grader-c \(1\)</option>'
        }

        It 'De-duplicates failing grader names per row when counting frequency' {
            # task-researcher fails grader-a twice; it must contribute only 1 to grader-a's count.
            # Total grader-a fails would be 4 raw, but de-duped per row is 3.
            $script:Html | Should -Match '<option value="grader-a">grader-a \(3\)</option>'
            $script:Html | Should -Not -Match '<option value="grader-a">grader-a \(4\)</option>'
        }

        It 'De-duplicates failing grader names per row in the data attribute' {
            $researcherRow = [regex]::Match(
                $script:Html,
                '<tr class="row"[^>]*data-slug="task-researcher"[^>]*data-failing-graders="([^"]*)"'
            ).Groups[1].Value
            $researcherRow | Should -Be 'grader-a,grader-b'
        }

        It 'Renders the failures-only checkbox in the controls' {
            $script:Html | Should -Match '<input type="checkbox" id="filter-failures-only">'
            $script:Html | Should -Match 'Failures only'
        }

        It 'Wires the failures-only checkbox into the filter JS' {
            $script:Html | Should -Match "var failOnly = document\.getElementById\('filter-failures-only'\);"
            $script:Html | Should -Match "onlyFailures && rverdict !== 'fail'"
            $script:Html | Should -Match "failOnly\.addEventListener\('change', applyFilters\)"
        }
    }
}

Describe 'Get-DrillRowRegex' -Tag 'Unit' {
    BeforeAll {
        $script:FixturesModule = Join-Path $PSScriptRoot '_AgentMatrixFixtures.psm1'
        Import-Module $script:FixturesModule -Force
    }

    AfterAll {
        Remove-Module _AgentMatrixFixtures -Force -ErrorAction SilentlyContinue
    }

    It 'Returns a string' {
        Get-DrillRowRegex -Slug 'a' -Inner 'x' | Should -BeOfType ([string])
    }

    It 'Starts with the singleline regex flag' {
        (Get-DrillRowRegex -Slug 'a' -Inner 'x').StartsWith('(?s)') | Should -BeTrue
    }

    It 'Escapes regex metacharacters in the slug' {
        $pattern = Get-DrillRowRegex -Slug 'task.a+b' -Inner 'x'
        $pattern | Should -Match 'data-drill-for="task\\\.a\\\+b"'
    }

    It 'Appends Inner without escaping (subpattern composition is intentional)' {
        $pattern = Get-DrillRowRegex -Slug 'a' -Inner 'class="drill-meta">.*'
        $pattern.EndsWith('class="drill-meta">.*') | Should -BeTrue
    }

    It 'Matches the actual dashboard drill-row markup' {
        $sample = '<tr class="drill" data-drill-for="task-researcher" hidden><td colspan="9"><div class="drill-empty">No grader results recorded.</div></td></tr>'
        $sample | Should -Match (Get-DrillRowRegex -Slug 'task-researcher' -Inner 'class="drill-empty">No grader results recorded\.')
    }

    It 'Does not match a drill row for a different slug' {
        $sample = '<tr class="drill" data-drill-for="task-planner" hidden><td colspan="9"><div class="drill-empty">No grader results recorded.</div></td></tr>'
        $sample | Should -Not -Match (Get-DrillRowRegex -Slug 'task-researcher' -Inner 'class="drill-empty"')
    }
}
