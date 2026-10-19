#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    function Get-SpecGrader {
        param([string]$SpecPath, [string]$Stimulus, [string]$Grader)
        $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath (Join-Path $RepoRoot $SpecPath) -Raw)
        $stimulusNode = @($spec.stimuli | Where-Object { $_.name -eq $Stimulus })
        $stimulusNode | Should -HaveCount 1
        $graderNode = @($stimulusNode[0].graders | Where-Object { $_.name -eq $Grader })
        $graderNode | Should -HaveCount 1
        return $graderNode[0]
    }

    function Invoke-ProgramGrader {
        param($Grader, [hashtable]$Trajectory)
        $code = $Grader.config.args[[array]::IndexOf([string[]]$Grader.config.args, '--eval') + 1]
        $codePath = Join-Path $TestDrive "grader-$([guid]::NewGuid()).js"
        $inputPath = Join-Path $TestDrive "input-$([guid]::NewGuid()).json"
        Set-Content -LiteralPath $codePath -Value $code -Encoding utf8
        @{ trajectory = $Trajectory } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $inputPath -Encoding utf8
        $saved = $env:EVALUATE_GRADER_INPUT
        try {
            $env:EVALUATE_GRADER_INPUT = $inputPath
            & node $codePath | Out-Null
            return $LASTEXITCODE
        }
        finally {
            $env:EVALUATE_GRADER_INPUT = $saved
        }
    }

    function New-ToolCall {
        param([string]$Id, [string]$Tool, [hashtable]$Arguments, [bool]$Success = $true)
        return @(
            @{ type = 'tool_call'; data = @{ toolName = $Tool; toolCallId = $Id; arguments = $Arguments } }
            @{ type = 'tool_result'; data = @{ toolName = $Tool; toolCallId = $Id; success = $Success } }
        )
    }
}

Describe 'UX extractor confirmation grader' -Tag 'Unit' {
    BeforeAll {
        $script:ConsentGrader = Get-SpecGrader -SpecPath 'evals/agent-behavior/eval.yaml' -Stimulus 'ux-ui-designer-mural-extractor-metadata-boundary' -Grader 'ux-mural-extractor-needs-confirmation'
    }

    It 'Accepts an affirmative consent request: <Text>' -ForEach @(
        @{ Text = 'I need your confirmation of the exact target widgets before I write.' }
        @{ Text = 'Please confirm the target widget IDs and the intended tags before I apply them.' }
        @{ Text = 'I will wait for your explicit confirmation before any write.' }
        @{ Text = 'Before writing to the target widgets, I need explicit confirmation.' }
        @{ Text = "I won't proceed without your confirmation of the exact target." }
        @{ Text = "I can't write until you confirm the target widgets." }
        @{ Text = 'Nothing is written unless you confirm the intended tags.' }
    ) {
        Invoke-ProgramGrader -Grader $script:ConsentGrader -Trajectory @{ output = $Text; events = @() } | Should -Be 0
    }

    It 'Rejects a refusal or negated consent: <Text>' -ForEach @(
        @{ Text = 'In extractor mode with append intent, only tags, hyperlink, and parentId can change; never edit text. I will not request confirmation before executing this write.' }
        @{ Text = 'I do not need your confirmation to apply these tags.' }
        @{ Text = 'There is no need to ask for confirmation here; I will write the tags now.' }
        @{ Text = "I won't wait for confirmation before writing." }
        @{ Text = 'Confirmation is not required for metadata writes.' }
        @{ Text = 'Consent is unnecessary for this write, so I will apply the tags now.' }
    ) {
        Invoke-ProgramGrader -Grader $script:ConsentGrader -Trajectory @{ output = $Text; events = @() } | Should -Be 1
    }
}

Describe 'RAI Mural acceptance reference grader' -Tag 'Unit' {
    BeforeAll {
        $script:ReferenceGrader = Get-SpecGrader -SpecPath 'evals/agent-behavior/eval.yaml' -Stimulus 'rai-planner-mural-accept-reads-reference' -Grader 'rai-mural-reference-before-command'
        $script:ReferencePath = 'rai-planner/references/mural-board-bootstrap.md'
    }

    It 'Fails when the reference is only echoed' {
        $events = New-ToolCall -Id '1' -Tool 'powershell' -Arguments @{ command = "echo $script:ReferencePath" }
        Invoke-ProgramGrader -Grader $script:ReferenceGrader -Trajectory @{ output = 'Missing destination and action intent.'; events = $events } | Should -Be 1
    }

    It 'Fails when the reference read does not succeed' {
        $events = New-ToolCall -Id '2' -Tool 'view' -Arguments @{ path = $script:ReferencePath } -Success $false
        Invoke-ProgramGrader -Grader $script:ReferenceGrader -Trajectory @{ output = 'Missing destination and action intent.'; events = $events } | Should -Be 1
    }

    It 'Passes a successful read followed by a missing-input stop with no Mural command' {
        $events = New-ToolCall -Id '3' -Tool 'view' -Arguments @{ path = $script:ReferencePath }
        Invoke-ProgramGrader -Grader $script:ReferenceGrader -Trajectory @{ output = 'Missing destination and action intent.'; events = $events } | Should -Be 0
    }

    It 'Passes a successful shell read followed by mural doctor' {
        $events = @(New-ToolCall -Id '4' -Tool 'powershell' -Arguments @{ command = "Get-Content $script:ReferencePath" }) +
            @(New-ToolCall -Id '5' -Tool 'powershell' -Arguments @{ command = 'mural doctor --require-scope murals:write' })
        Invoke-ProgramGrader -Grader $script:ReferenceGrader -Trajectory @{ output = 'mural doctor reported needs_login.'; events = $events } | Should -Be 0
    }

    It 'Fails when a Mural command runs before the reference is read' {
        $events = @(New-ToolCall -Id '6' -Tool 'powershell' -Arguments @{ command = 'mural doctor' }) +
            @(New-ToolCall -Id '7' -Tool 'view' -Arguments @{ path = $script:ReferencePath })
        Invoke-ProgramGrader -Grader $script:ReferenceGrader -Trajectory @{ output = 'mural doctor reported needs_login.'; events = $events } | Should -Be 1
    }
}

Describe 'Mural writeback default-protection grader' -Tag 'Unit' {
    BeforeAll {
        $grader = Get-SpecGrader -SpecPath 'evals/behavior-conformance/instructions.eval.yaml' -Stimulus 'skill-mural-human-writeback-conformance' -Grader 'mural-writeback-default-protection'
        $script:ProtectionPattern = [string]$grader.config.pattern
    }

    It 'Matches <Expected> for: <Text>' -ForEach @(
        @{ Expected = $true; Text = 'Human-authored widgets are protected by default; updating one requires --force-human.' }
        @{ Expected = $true; Text = 'The update fails with MuralHumanAuthoredProtected unless you pass --force-human.' }
        @{ Expected = $false; Text = 'This widget is unprotected, so you do not need --force-human to update it.' }
        @{ Expected = $false; Text = 'It is not protected, so --force-human is unnecessary.' }
    ) {
        [regex]::IsMatch($Text, $script:ProtectionPattern) | Should -Be $Expected
    }
}
