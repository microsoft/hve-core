#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeDiscovery {
    $Contracts = @(
        @{
            Contract = 'Feasibility identity and consumer boundary'
            GraderName = 'skill-feasibility-profile-knowledge-identity-and-co-62ede39b'
            Clauses = [ordered]@{
                Identity = 'Study and item concept IDs are UUID URNs.'
                Revision = 'Authoritative changes create a new revision ID without changing conceptual identity.'
                Ownership = 'Functional Planner owns its downstream requirement mapping and traceability.'
                NoAssignment = 'The study does not assign FR-### or NFR-### numbers.'
                NoWriteback = 'There is no downstream writeback to the study.'
            }
            Weak = 'UUID revision details remain separate from downstream PRD requirements.'
            Replacements = @(
                @{ Clause = 'Ownership'; Text = 'The PRD owns its downstream requirement mapping and traceability.' }
                @{ Clause = 'NoAssignment'; Text = 'The study assigns FR-### or NFR-### numbers.' }
                @{ Clause = 'NoWriteback'; Text = 'Downstream consumers write back mappings to the study.' }
            )
        }
        @{
            Contract = 'Trained-model ownership'
            GraderName = 'skill-evaluation-design-knowledge-trained-model-boundary'
            Clauses = [ordered]@{
                Scope = 'Trained-model evaluation measures predictive performance rather than assistant responses.'
                Route = 'Route that work to ml-experimentation.'
            }
            Weak = 'Trained model evaluation measures predictive performance.'
            Replacements = @(
                @{ Clause = 'Route'; Text = 'Route that work to evaluation-design.' }
                @{ Clause = 'Route'; Text = 'The ml-experimentation skill is also available.' }
            )
        }
        @{
            Contract = 'Population accounting and provenance'
            GraderName = 'skill-evaluation-design-knowledge-population-and-provenance'
            Clauses = [ordered]@{
                Coverage = 'metadata.population_coverage records pair counts for each confirmed population.'
                Overlap = 'Population counts overlap because one pair may serve several populations and need not sum to total_pairs.'
                ZeroCoverage = 'Retain every confirmed population, including zero-count populations with no pairs.'
                Validation = 'validation_status records validation provenance: ai-generated, expert-reviewed, or mixed.'
                Generation = 'generation_method records the workflow that produced the pairs.'
                Review = 'review_state records authoring progression through draft, sampled, and confirmed.'
            }
            Weak = 'Population coverage serves multiple populations; validate, generate, and review the pairs.'
            Replacements = @(
                @{ Clause = 'Validation'; Text = 'validation_status is recorded.' }
                @{ Clause = 'Generation'; Text = 'generation_method is recorded.' }
                @{ Clause = 'Review'; Text = 'review_state is recorded.' }
            )
        }
        @{
            Contract = 'Consolidated evaluation guide'
            GraderName = 'skill-evaluation-design-knowledge-consolidated-guide'
            Clauses = [ordered]@{
                Guide = 'Produce one sectioned evaluation guide.'
                Curation = 'Include curation notes about the dataset composition and confirmed scope.'
                Selection = 'Document metric selection based on grounding, tool use, and risk.'
                Rationale = 'Give the rationale for each metric and why it fits this system.'
                Tooling = 'Include tooling recommendations matched to the team approach and cadence.'
            }
            Weak = 'One evaluation guide includes a rationale.'
            Replacements = @(
                @{ Clause = 'Rationale'; Text = 'Give the rationale for the document title.' }
            )
        }
    )

    $script:Cases = @(
        foreach ($Contract in $Contracts) {
            $Clauses = @($Contract.Clauses.Values)
            @{
                Contract = $Contract.Contract
                GraderName = $Contract.GraderName
                Scenario = 'accepts the complete contract'
                Response = $Clauses -join ' '
                Expected = $true
            }
            [array]::Reverse($Clauses)
            @{
                Contract = $Contract.Contract
                GraderName = $Contract.GraderName
                Scenario = 'accepts reversed clauses across lines and case changes'
                Response = ($Clauses -join "`n").ToUpperInvariant()
                Expected = $true
            }
            @{
                Contract = $Contract.Contract
                GraderName = $Contract.GraderName
                Scenario = 'rejects generic co-occurrence'
                Response = $Contract.Weak
                Expected = $false
            }
            foreach ($Missing in $Contract.Clauses.Keys) {
                @{
                    Contract = $Contract.Contract
                    GraderName = $Contract.GraderName
                    Scenario = "rejects independently missing $Missing"
                    Response = @(
                        foreach ($Key in $Contract.Clauses.Keys) {
                            if ($Key -ne $Missing) {
                                $Contract.Clauses[$Key]
                            }
                        }
                    ) -join ' '
                    Expected = $false
                }
            }
            foreach ($Replacement in $Contract.Replacements) {
                @{
                    Contract = $Contract.Contract
                    GraderName = $Contract.GraderName
                    Scenario = "rejects an insufficient $($Replacement.Clause) clause: $($Replacement.Text)"
                    Response = @(
                        foreach ($Key in $Contract.Clauses.Keys) {
                            if ($Key -eq $Replacement.Clause) {
                                $Replacement.Text
                            }
                            else {
                                $Contract.Clauses[$Key]
                            }
                        }
                    ) -join ' '
                    Expected = $false
                }
            }
        }
    )
}

BeforeAll {
    Import-Module powershell-yaml -ErrorAction Stop
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $SpecPath = Join-Path $RepoRoot 'evals\behavior-conformance\skill-behavior.eval.yaml'
    $Spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $SpecPath -Raw)
    $script:Graders = @($Spec.stimuli | ForEach-Object { $_.graders })
}

Describe 'Data workstream behavior graders' -Tag 'Unit' {
    # These checks establish contract signals, not semantic correctness of arbitrary prose.
    It '<Contract>: <Scenario>' -ForEach $script:Cases {
        $Grader = @($script:Graders | Where-Object { $_.name -eq $GraderName })
        $Grader | Should -HaveCount 1
        $Grader[0].type | Should -Be 'output-matches'
        $Grader[0].config.pattern | Should -Not -BeNullOrEmpty
        [regex]::IsMatch(
            $Response,
            $Grader[0].config.pattern,
            [System.Text.RegularExpressions.RegexOptions]::None,
            [timespan]::FromSeconds(1)
        ) | Should -Be $Expected
    }
}

AfterAll {
    Remove-Module powershell-yaml -ErrorAction SilentlyContinue
}
