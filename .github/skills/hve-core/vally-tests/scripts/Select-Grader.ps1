#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Emits the canonical Vally grader block for a (kind, check) pair.

.DESCRIPTION
    Reads `references/grader-catalog.md` and `references/<kind>.md` (sibling to
    this script under .github/skills/hve-core/vally-tests/) and emits the
    grader block recommended for the named check. Pure transformation: no
    Vally invocation, no network, no LLM call. The output is a fragment that
    nests cleanly under the `graders:` key of a stimulus block.

.PARAMETER Kind
    Artifact kind. One of: prompt, instructions, agent, skill.

.PARAMETER Check
    Check identifier as named in references/<kind>.md. Matched
    case-insensitively against any heading or anchor.

.PARAMETER GraderType
    Override the grader type. Defaults to the recommendation in the per-kind
    reference. One of: prompt, output-contains, output-matches.

.EXAMPLE
    ./Select-Grader.ps1 -Kind prompt -Check 'agent-attribution'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('prompt', 'instructions', 'agent', 'skill')]
    [string]$Kind,

    [Parameter(Mandatory)]
    [string]$Check,

    [Parameter()]
    [ValidateSet('prompt', 'output-contains', 'output-matches')]
    [string]$GraderType
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$skillRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$referencesDir = Join-Path $skillRoot 'references'
$kindReference = Join-Path $referencesDir "$Kind`s.md"
if ($Kind -eq 'instructions') { $kindReference = Join-Path $referencesDir 'instructions.md' }

if (-not (Test-Path -LiteralPath $kindReference)) {
    throw "Per-kind reference not found: $kindReference"
}

if (-not $PSBoundParameters.ContainsKey('GraderType')) {
    $referenceText = Get-Content -LiteralPath $kindReference -Raw
    $checkPattern = [Regex]::Escape($Check)
    $headingMatch = [Regex]::Match(
        $referenceText,
        "(?im)^\s*#{2,6}\s+.*$checkPattern.*?$"
    )
    if (-not $headingMatch.Success) {
        throw "Check '$Check' not found in $kindReference."
    }
    $tail = $referenceText.Substring($headingMatch.Index)
    $graderMatch = [Regex]::Match(
        $tail,
        '(?im)\b(prompt|output-contains|output-matches|semantic_similarity|contains|regex)\b'
    )
    $token = if ($graderMatch.Success) { $graderMatch.Value.ToLowerInvariant() } else { 'output-matches' }
    $GraderType = switch ($token) {
        'semantic_similarity' { 'prompt' }
        'contains'            { 'output-contains' }
        'regex'               { 'output-matches' }
        default               { $token }
    }
}

switch ($GraderType) {
    'prompt' {
@"
  - type: prompt
    name: $Check
    config:
      prompt: |
        Score 1 if the response satisfies the $Check contract. Score 0 otherwise.
      scoring: scale_1_5
      threshold: 0.85
"@
    }
    'output-contains' {
@"
  - type: output-contains
    name: $Check
    config:
      substring: "<literal phrase>"
"@
    }
    'output-matches' {
@"
  - type: output-matches
    name: $Check
    config:
      pattern: "(?i)<regex-source-of-truth>"
"@
    }
}
