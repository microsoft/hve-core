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
            Name = 'skill-root-cause-analysis-evidence-a'
            Canonical = "Gate: pass`nBasis: E-001, E-002"
            Alternatives = @("Gate: pass`nBasis: E-002, E-001")
            Incorrect = @(
                "Gate: fail`nBasis: E-001, E-002"
                "Gate: not pass`nBasis: E-001, E-002"
                "Gate: pass`nBasis: E-001, E-003"
                "Gate: pass`nBasis: E-001, E-001"
                "Gate: pass`nBasis: E-001"
                "Gate: pass`nBasis: E-001, E-002, E-003"
                "Status: Complete`nBasis: E-001, E-002"
            )
        }
        @{
            Name = 'skill-root-cause-analysis-evidence-b'
            Canonical = "Gate: fail`nBasis: E-001, E-002"
            Alternatives = @("Gate: fail`nBasis: E-002, E-001")
            Incorrect = @(
                "Gate: pass`nBasis: E-001, E-002"
                "Gate: not fail`nBasis: E-001, E-002"
                "Gate: fail`nBasis: E-002, E-003"
                "Gate: fail`nBasis: E-001, E-001"
                "Gate: fail`nBasis: E-001"
                "Gate: fail`nBasis: E-001, E-002, E-003"
                "Status: Complete`nBasis: E-001, E-002"
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
        $script:RcaStimuli = @($Spec.stimuli | Where-Object {
            $_.name -match '^skill-(root-cause-analysis|causal-evidence-likelihood|statistical-hypothesis-testing)-'
        })
        $script:RegressionStimuli = @($script:RcaStimuli | Where-Object {
            $_.name -like 'skill-root-cause-analysis-regression-*'
        })
        $script:EvidenceStimuli = @($script:RcaStimuli | Where-Object {
            $_.name -like 'skill-root-cause-analysis-evidence-*'
        })
        $script:GlobalFiles = @(
            $Spec.agent_environment.files
            $Spec.environment.files
            $Spec.defaults.agent_environment.files
            $Spec.defaults.environment.files
        ) | Where-Object { $null -ne $_ }
        $FixtureRoot = Join-Path (Split-Path $SpecPath) 'fixtures'
        $script:FixtureSets = @{}
        foreach ($FileName in @('rca-regression-corpus.json', 'rca-evidence-record-a.json', 'rca-evidence-record-b.json')) {
            $script:FixtureSets[$FileName] = Get-Content -LiteralPath (Join-Path $FixtureRoot $FileName) -Raw | ConvertFrom-Json
        }
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

    It 'Retains the complete stimulus prefix in every RCA grader name' {
        $script:RcaStimuli.Count | Should -BeGreaterThan 0
        foreach ($Stimulus in $script:RcaStimuli) {
            foreach ($Grader in $Stimulus.graders) {
                $Grader.name.StartsWith($Stimulus.name) | Should -BeTrue -Because "grader $($Grader.name) belongs to $($Stimulus.name)"
            }
        }
    }

    It 'Keeps every RCA grader name within the 60-character schema limit' {
        $script:RcaStimuli.Count | Should -BeGreaterThan 0
        foreach ($Stimulus in $script:RcaStimuli) {
            foreach ($Grader in $Stimulus.graders) {
                $Grader.name.Length | Should -BeLessOrEqual 60 -Because "grader $($Grader.name) must fit the identifier limit"
            }
        }
    }

    It 'Uses one versioned case structure across both assessment modes' {
        $script:FixtureSets.Count | Should -Be 3
        $CaseFields = @('id', 'failure_type', 'question', 'scope', 'sources', 'hypotheses', 'tests', 'evidence', 'gaps', 'human_review')
        foreach ($Fixture in $script:FixtureSets.Values) {
            $Fixture.schema_version | Should -Be 2
            $Fixture.assessment_mode | Should -BeIn @('decision-rule-application', 'evidence-assessment')
            ($Fixture.cases -is [array]) | Should -BeTrue
            $Fixture.cases.Count | Should -BeGreaterThan 0
            @($Fixture.cases.id | Sort-Object -Unique).Count | Should -Be $Fixture.cases.Count
            foreach ($Case in $Fixture.cases) {
                ($Case.PSObject.Properties.Name | Sort-Object) -join ',' | Should -Be (($CaseFields | Sort-Object) -join ',')
                $Case.id | Should -Not -BeNullOrEmpty
                $Case.failure_type | Should -BeIn @('incident', 'data', 'software', 'process')
                $Case.question | Should -Not -BeNullOrEmpty
                $Case.scope.affected | Should -Not -BeNullOrEmpty
                $Case.scope.unaffected | Should -Not -BeNullOrEmpty
                foreach ($Collection in @('sources', 'hypotheses', 'tests', 'evidence', 'gaps')) {
                    ($Case.$Collection -is [array]) | Should -BeTrue
                    @($Case.$Collection.id | Sort-Object -Unique).Count | Should -Be $Case.$Collection.Count
                }
                foreach ($Collection in @('sources', 'hypotheses', 'tests', 'evidence')) {
                    $Case.$Collection.Count | Should -BeGreaterThan 0
                }
                foreach ($Source in $Case.sources) {
                    $Source.id | Should -Match '^S-\d{3}$'
                    $Source.description | Should -Not -BeNullOrEmpty
                }
                foreach ($Hypothesis in $Case.hypotheses) {
                    $Hypothesis.id | Should -Match '^H-\d{3}$'
                    $Hypothesis.statement | Should -Not -BeNullOrEmpty
                    $Hypothesis.necessary_prediction | Should -Not -BeNullOrEmpty
                }
                foreach ($Test in $Case.tests) {
                    $Test.id | Should -Match '^T-\d{3}$'
                    $Test.status | Should -Be 'Executed'
                    $Test.result | Should -Not -BeNullOrEmpty
                }
                foreach ($Evidence in $Case.evidence) {
                    $Evidence.id | Should -Match '^E-\d{3}$'
                    $Evidence.source | Should -BeIn $Case.sources.id
                    $Evidence.observation | Should -Not -BeNullOrEmpty
                }
                foreach ($Gap in $Case.gaps) {
                    $Gap.id | Should -Match '^G-\d{3}$'
                    $Gap.description | Should -Not -BeNullOrEmpty
                }
                $Case.human_review.reviewer_role | Should -Not -BeNullOrEmpty
                $Case.human_review.sign_off | Should -BeIn @('recorded', 'not recorded')
            }
        }
    }

    It 'Declares the existing four cases as stipulated decision-rule premises' {
        $Fixture = $script:FixtureSets['rca-regression-corpus.json']
        $Fixture.assessment_mode | Should -Be 'decision-rule-application'
        $Fixture.cases | Should -HaveCount 4
        $script:RegressionStimuli | Should -HaveCount 4
        foreach ($Stimulus in $script:RegressionStimuli) {
            $Stimulus.prompt | Should -Match 'decision-rule application test'
            $Stimulus.prompt | Should -Match 'assessments as stipulated premises'
            $Stimulus.agent_environment.files | Should -HaveCount 1
            $Stimulus.agent_environment.files[0].src | Should -Be 'fixtures/rca-regression-corpus.json'
        }
        $Gaps = @($Fixture.cases | ForEach-Object { $_.gaps })
        $Gaps | Should -HaveCount 2
        foreach ($Gap in $Gaps) {
            $Gap.classification | Should -BeIn @('non-blocking coverage limit', 'material unverified link')
            $Gap.access_approval_or_integrity_blocker | Should -BeOfType ([bool])
            $Gap.useful_authorized_test_remaining | Should -BeOfType ([bool])
        }
    }

    It 'Isolates each evidence-assessment stimulus from the interpreted corpus and its counterpart' {
        @($script:GlobalFiles).Count | Should -Be 0
        $script:EvidenceStimuli | Should -HaveCount 2
        foreach ($Variant in @('a', 'b')) {
            $Stimulus = $script:Stimuli["skill-root-cause-analysis-evidence-$Variant"]
            $Stimulus | Should -Not -BeNullOrEmpty
            $Stimulus.environment | Should -BeNullOrEmpty
            $Stimulus.agent_environment.skills | Should -HaveCount 1
            $Stimulus.agent_environment.skills[0] | Should -Be '../../.github/skills/root-cause-analysis/root-cause-analysis'
            $Stimulus.agent_environment.files | Should -HaveCount 1
            $Stimulus.agent_environment.files[0].src | Should -Be "fixtures/rca-evidence-record-$Variant.json"
            $Stimulus.agent_environment.files[0].dest | Should -Be "rca-evidence-record-$Variant.json"
            $Stimulus.prompt | Should -Match 'Independently assess'
            $Stimulus.prompt | Should -Match 'do not select a final\s+stop state or assess human sign-off'
        }
    }

    It 'Keeps interpretations and expected decisions out of evidence-assessment records' {
        foreach ($Variant in @('a', 'b')) {
            $Fixture = $script:FixtureSets["rca-evidence-record-$Variant.json"]
            $Fixture.assessment_mode | Should -Be 'evidence-assessment'
            $Fixture.cases | Should -HaveCount 1
            $Json = $Fixture | ConvertTo-Json -Depth 20
            $Json | Should -Not -Match '"(?:classification|access_approval_or_integrity_blocker|useful_authorized_test_remaining|alternatives_excluded|counterfactual_observed|causal_account|disposition|expected_gate|expected_status|gate_outcome)"\s*:'
            $Json | Should -Not -Match '(?i)Gate:\s*(?:pass|fail)|Status:\s*(?:Complete|Provisional|Inconclusive|Blocked|Paused)'
        }
    }

    It 'Resolves evidence-assessment locators to the supplied observations' {
        foreach ($Variant in @('a', 'b')) {
            $Fixture = $script:FixtureSets["rca-evidence-record-$Variant.json"]
            $EvidenceRecords = $Fixture.cases[0].evidence
            $EvidenceRecords | Should -HaveCount 3
            for ($Index = 0; $Index -lt $EvidenceRecords.Count; $Index++) {
                $EvidenceRecords[$Index].locator | Should -Be "#/cases/0/evidence/$Index/observation"
                $EvidenceRecords[$Index].observation | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'Changes only the incident observation between the two evidence variants' {
        $First = $script:FixtureSets['rca-evidence-record-a.json'] | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $Second = $script:FixtureSets['rca-evidence-record-b.json']
        $First.cases[0].evidence[0].id | Should -Be 'E-001'
        $Second.cases[0].evidence[0].id | Should -Be 'E-001'
        $First.cases[0].evidence[0].observation | Should -Not -BeExactly $Second.cases[0].evidence[0].observation
        $First.cases[0].evidence[0].observation = $Second.cases[0].evidence[0].observation
        ($First | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly ($Second | ConvertTo-Json -Depth 20 -Compress)
    }

    It 'Requires opposite gate decisions for the paired evidence variants' {
        $script:Results['skill-root-cause-analysis-evidence-a'].reject.response | Should -Contain "Gate: fail`nBasis: E-001, E-002"
        $script:Results['skill-root-cause-analysis-evidence-b'].reject.response | Should -Contain "Gate: pass`nBasis: E-001, E-002"
        $script:Results['skill-root-cause-analysis-evidence-a'].accept.response | Should -Contain "Gate: pass`nBasis: E-001, E-002"
        $script:Results['skill-root-cause-analysis-evidence-b'].accept.response | Should -Contain "Gate: fail`nBasis: E-001, E-002"
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
