#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Scaffolds a Vally stimulus YAML block from a target artifact path.

.DESCRIPTION
    Emits a single stimulus block for the routed Vally eval suite using the
    template at assets/stimulus-template.yml. Pure transformation: no Vally
    invocation, no network, no LLM call. The dedupe contract (SHA-256 of the
    normalized prompt text after NFC + lowercase + whitespace collapse) is
    computed and surfaced on stdout so the caller can refuse duplicates.

.PARAMETER ArtifactPath
    Repo-relative path to the artifact under test (prompt, instructions file,
    agent, or skill SKILL.md).

.PARAMETER Kind
    Artifact kind. One of: prompt, instructions, agent, skill.

.PARAMETER PromptText
    Literal prompt text the stimulus exercises. Goes into the YAML `prompt:`
    block scalar.

.PARAMETER OutputPath
    Optional path to append the emitted block to. When omitted the block is
    written to stdout.

.PARAMETER GraderType
    Optional Vally CLI 0.4.0 grader type to seed the `graders:` array. One of
    prompt, output-contains, output-matches. Defaults to output-matches.

.EXAMPLE
    ./New-Stimulus.ps1 -ArtifactPath .github/prompts/hve-core/task-research.prompt.md `
        -Kind prompt -PromptText 'Invoke task-research with topic=X.'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArtifactPath,

    [Parameter(Mandatory)]
    [ValidateSet('prompt', 'instructions', 'agent', 'skill')]
    [string]$Kind,

    [Parameter(Mandatory)]
    [string]$PromptText,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [ValidateSet('prompt', 'output-contains', 'output-matches')]
    [string]$GraderType = 'output-matches'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-NormalizedPromptHash {
    param([Parameter(Mandatory)][string]$Text)

    $normalized = $Text.Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
    $normalized = ($normalized -replace '\s+', ' ').Trim()
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    }
    finally {
        $sha.Dispose()
    }
}

function Get-StimulusName {
    param(
        [Parameter(Mandatory)][string]$ArtifactPath,
        [Parameter(Mandatory)][string]$Hash
    )

    $leaf = [IO.Path]::GetFileName($ArtifactPath)
    $leaf = $leaf -replace '\.(prompt|instructions|agent)\.md$', ''
    $leaf = $leaf -replace '[^a-z0-9]+', '-'
    "$leaf-conformance-$($Hash.Substring(0, 8))"
}

function Get-CategoryForKind {
    param([Parameter(Mandatory)][string]$Kind)

    if ($Kind -eq 'agent') { 'agent-behavior' } else { 'behavior-conformance' }
}

$hash = Get-NormalizedPromptHash -Text $PromptText
$name = Get-StimulusName -ArtifactPath $ArtifactPath -Hash $hash
$category = Get-CategoryForKind -Kind $Kind

$promptYaml = ($PromptText -split "`r?`n" | ForEach-Object { "      $_" }) -join "`n"
$promptYaml = "    prompt: |`n$promptYaml"

$graderBlock = switch ($GraderType) {
    'prompt' {
@'
    graders:
      - type: prompt
        name: rubric-match
        config:
          prompt: |
            Score 1 if the response satisfies the contract. Score 0 otherwise.
          scoring: scale_1_5
          threshold: 0.85
'@
    }
    'output-contains' {
@'
    graders:
      - type: output-contains
        name: literal-phrase-present
        config:
          substring: "<literal phrase>"
'@
    }
    default {
@'
    graders:
      - type: output-matches
        name: pattern-present
        config:
          pattern: "(?i)<regex-source-of-truth>"
'@
    }
}

$artifactPathYaml = '"' + ($ArtifactPath -replace '\\', '\\' -replace '"', '\"') + '"'

$block = @"
  - name: $name
$promptYaml
    tags:
      category: $category
      kind: $Kind
      target_artifact: $artifactPathYaml
      advisory: "true"
      prompt_sha256: $hash
$graderBlock
"@

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $block
}
else {
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        Set-Content -LiteralPath $OutputPath -Value "stimuli:`n" -Encoding utf8
    }
    Add-Content -LiteralPath $OutputPath -Value $block -Encoding utf8
    Write-Output "Appended stimulus '$name' (sha256=$hash) to $OutputPath"
}
