#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeDiscovery {
    $script:Contracts = @(
        @{
            Name = 'skill-root-cause-analysis-complete-gate'
            Canonical = "Status: Complete`nBasis: T-001, T-002"
            Alternatives = @(
                "Status: Complete`nBasis: T-002, T-001"
                "Status: Complete`nBasis: T-001, T-003"
                "Status: Complete`nBasis: T-003, T-001"
                "Status: Complete`nBasis: T-002, T-003"
                "Status: Complete`nBasis: T-003, T-002"
            )
            Incorrect = @(
                'The investigation is not Complete: reproduction and rollback control evidence exist, but an unresolved contradiction remains.'
                "Status: Not Complete`nBasis: T-001, T-002"
                "Status: Provisional`nBasis: T-001, T-002"
                "Status: Complete`nBasis: T-001"
                "Status: Complete`nBasis: T-001, T-001"
                "Status: Complete`nBasis: T-001, T-004"
                "Status: Complete`nBasis: T-001, T-002, T-003"
            )
        }
        @{
            Name = 'skill-root-cause-analysis-regression-incident'
            Canonical = "Status: Complete`nBasis: T-003, T-004"
            Alternatives = @("Status: Complete`nBasis: T-004, T-003")
            Incorrect = @(
                "Status: Inconclusive`nBasis: T-003, T-004"
                "Status: Not Complete`nBasis: T-003, T-004"
                "Status: Complete`nBasis: T-001, T-002"
                "Status: Complete`nBasis: T-003, T-003"
                "Status: Complete`nBasis: T-003"
                "Status: Complete`nBasis: T-003, T-004, T-005"
            )
        }
        @{
            Name = 'skill-root-cause-analysis-regression-data'
            Canonical = "Status: Inconclusive`nBasis: T-003, G-001"
            Alternatives = @(
                "Status: Inconclusive`nBasis: G-001, T-003"
                "Status: Inconclusive`nBasis: T-003"
                "Status: Inconclusive`nBasis: G-001"
            )
            Incorrect = @(
                "Status: Blocked`nBasis: T-003, G-001"
                "Status: Complete`nBasis: T-003, G-001"
                "Status: Inconclusive`nBasis: T-001"
                "Status: Inconclusive`nBasis: G-002"
                "Status: Inconclusive`nBasis: G-001, G-001"
                "Status: Inconclusive`nBasis: T-003, T-003"
                "Status: Inconclusive`nBasis: T-003, G-001, E-001"
            )
        }
        @{
            Name = 'skill-root-cause-analysis-regression-software'
            Canonical = "Disposition: Disproved`nBasis: E-001, E-002"
            Alternatives = @("Disposition: Disproved`nBasis: E-002, E-001")
            Incorrect = @(
                "Disposition: Supported`nBasis: E-001, E-002"
                "Disposition: Not Disproved`nBasis: E-001, E-002"
                "Disposition: Disproved`nBasis: T-001, T-002"
                "Disposition: Disproved`nBasis: E-001, E-001"
                "Disposition: Disproved`nBasis: E-001"
                "Disposition: Disproved`nBasis: E-001, E-002, E-003"
            )
        }
        @{
            Name = 'skill-root-cause-analysis-regression-process'
            Canonical = "Status: Provisional`nBasis: E-001, G-001"
            Alternatives = @("Status: Provisional`nBasis: G-001, E-001")
            Incorrect = @(
                "Status: Complete`nBasis: E-001, G-001"
                "Status: Blocked`nBasis: E-001, G-001"
                "Status: Provisional`nBasis: E-002, G-001"
                "Status: Provisional`nBasis: E-001, E-001"
                "Status: Provisional`nBasis: G-001"
                "Status: Provisional`nBasis: E-001, G-001, E-002"
            )
        }
        @{
            Name = 'skill-statistical-hypothesis-testing-blocks-missing-runtime'
            Canonical = "Status: Blocked`nPackage installation: Prohibited`nNumeric result: None"
            Alternatives = @()
            Incorrect = @(
                'Blocked: do not install packages; no numeric output should be produced. Nevertheless the p-value is 0.01.'
                "Status: Executed`nPackage installation: Prohibited`nNumeric result: None"
                "Status: Blocked`nPackage installation: Allowed`nNumeric result: None"
                "Status: Blocked`nPackage installation: Not Prohibited`nNumeric result: None"
                "Status: Blocked`nPackage installation: Prohibited`nNumeric result: 0.01"
                "Status: Blocked`nNumeric result: None"
                "Status: Blocked`nPackage installation: Prohibited"
            )
        }
    )
}

Describe 'RCA structured-decision graders' -Tag 'Unit' -ForEach @(@{ Contracts = $script:Contracts }) {
    BeforeAll {
        if (-not $Contracts -or $Contracts.Count -eq 0) {
            throw 'RCA grader contracts are missing from the test runtime.'
        }
        Import-Module powershell-yaml -ErrorAction Stop
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $SpecPath = Join-Path $RepoRoot 'evals\behavior-conformance\skill-behavior.eval.yaml'
        $Spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $SpecPath -Raw)
        $script:Stimuli = @{}
        $Probes = @(
            foreach ($Contract in $Contracts) {
                $Stimulus = @($Spec.stimuli | Where-Object { $_.name -eq $Contract.Name })
                if ($Stimulus.Count -ne 1 -or $Stimulus[0].graders.Count -ne 1) {
                    throw "Expected one stimulus with one grader: $($Contract.Name)"
                }
                $Stimulus = $Stimulus[0]
                $script:Stimuli[$Contract.Name] = $Stimulus
                @{
                    Name = $Contract.Name
                    Pattern = $Stimulus.graders[0].config.pattern
                    Prompt = $Stimulus.prompt
                    Accept = @($Contract.Canonical) + @($Contract.Alternatives) + @(
                        $Contract.Canonical.ToUpperInvariant()
                        " `t$($Contract.Canonical.Replace(': ', ':  ').Replace(', ', ' , ').Replace("`n", " `t`r`n`t"))`r`n`r`n"
                    )
                    Reject = @($Contract.Incorrect) + @(
                        ''
                        $Stimulus.prompt
                        'I cannot find that skill in this workspace.'
                        "Decision follows:`n$($Contract.Canonical)"
                        "$($Contract.Canonical)`nNevertheless, the investigation is Complete and the p-value is 0.01."
                        "$($Contract.Canonical)`nStatus: Complete"
                        "$($Contract.Canonical)`n$($Contract.Canonical)"
                        "``````text`n$($Contract.Canonical)`n``````"
                        ($Contract.Canonical -replace '(?m)^.*:', '')
                        ($Contract.Canonical -replace "`n", ' ')
                    )
                }
            }
        )
        $Code = @'
const crypto = require("node:crypto");
let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => input += chunk);
process.stdin.on("end", () => {
    const results = {};
    for (const probe of JSON.parse(input)) {
        const flags = /^\(\?([ims]+)\)/.exec(probe.Pattern);
        const pattern = new RegExp(
            flags ? probe.Pattern.slice(flags[0].length) : probe.Pattern,
            flags ? flags[1] : ""
        );
        const normalized = probe.Prompt.normalize("NFC").toLowerCase().replace(/\s+/gu, " ").trim();
        results[probe.Name] = {
            hash: crypto.createHash("sha256").update(normalized).digest("hex"),
            accept: probe.Accept.map(response => ({ response, matched: pattern.test(response) })),
            reject: probe.Reject.map(response => ({ response, matched: pattern.test(response) }))
        };
    }
    console.log(JSON.stringify(results));
});
'@
        $Output = ConvertTo-Json -InputObject $Probes -Depth 10 -Compress | & node --eval $Code
        if ($LASTEXITCODE -ne 0) {
            throw "Native JavaScript grader probes failed with exit code $LASTEXITCODE."
        }
        $script:Results = ($Output -join "`n") | ConvertFrom-Json -AsHashtable
        $script:Results.Count | Should -Be $Contracts.Count
    }

    It '<Name>: retains one deterministic full-response grader' -ForEach $Contracts {
        $script:Stimuli[$Name].graders[0].type | Should -Be 'output-matches'
        $script:Stimuli[$Name].tags.shape | Should -Be 'knowledge'
    }

    It '<Name>: records the current normalized prompt hash' -ForEach $Contracts {
        $script:Results[$Name].hash | Should -Be $script:Stimuli[$Name].tags.prompt_sha256
    }

    It '<Name>: accepts correct decisions and harmless formatting variants' -ForEach $Contracts {
        $script:Results[$Name].accept | Should -HaveCount (3 + $Alternatives.Count)
        foreach ($Result in $script:Results[$Name].accept) {
            $Result.matched | Should -BeTrue -Because "the response follows the contract: $($Result.response)"
        }
    }

    It '<Name>: rejects incorrect decisions, prompt echoes, and extra output' -ForEach $Contracts {
        $script:Results[$Name].reject | Should -HaveCount (10 + $Incorrect.Count)
        foreach ($Result in $script:Results[$Name].reject) {
            $Result.matched | Should -BeFalse -Because "the response violates the contract: $($Result.response)"
        }
    }
}
