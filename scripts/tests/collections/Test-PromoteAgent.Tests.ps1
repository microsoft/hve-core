#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../collections/Promote-Agent.ps1'
    . $scriptPath

    function script:New-TestAgentRepo {
        param(
            [Parameter(Mandatory = $true)][string]$Root,
            [Parameter(Mandatory = $true)][string]$TargetName
        )

        $agentsDir = Join-Path $Root '.github/agents/security'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

        $targetPath = Join-Path $agentsDir 'target-agent.agent.md'
        $parentPath = Join-Path $agentsDir 'parent-agent.agent.md'
        $siblingPath = Join-Path $agentsDir 'sibling-agent.agent.md'

        $targetContent = @"
---
name: $TargetName
description: Target agent under test.
---

# Target Agent

Body text for $TargetName.
"@
        Set-Content -LiteralPath $targetPath -Value $targetContent -Encoding utf8NoBOM -NoNewline

        $parentContent = @"
---
name: Parent Agent
description: Parent that lists the target in its agents field.
agents:
  - Researcher Subagent
  - $TargetName
---

# Parent Agent

Parent body referring to $TargetName by name.
"@
        Set-Content -LiteralPath $parentPath -Value $parentContent -Encoding utf8NoBOM -NoNewline

        $siblingContent = @"
---
name: Sibling Agent
description: Sibling that hands off to the target.
handoffs:
  - label: "Next"
    agent: $TargetName
    prompt: /next
    send: true
---

# Sibling Agent
"@
        Set-Content -LiteralPath $siblingPath -Value $siblingContent -Encoding utf8NoBOM -NoNewline

        return [pscustomobject]@{
            TargetPath  = $targetPath
            ParentPath  = $parentPath
            SiblingPath = $siblingPath
        }
    }

    function script:New-TestManifest {
        param(
            [Parameter(Mandatory = $true)][string]$Root,
            [Parameter(Mandatory = $true)][string]$TargetMaturity
        )

        $manifestPath = Join-Path $Root 'collections/core-manifest.yml'
        New-Item -ItemType Directory -Path (Split-Path $manifestPath -Parent) -Force | Out-Null

        $manifestContent = @"
artifacts:
  .github/agents/security/parent-agent.agent.md:
    path: .github/agents/security/parent-agent.agent.md
    maturity: stable
    collections:
    - security
  .github/agents/security/target-agent.agent.md:
    path: .github/agents/security/target-agent.agent.md
    maturity: $TargetMaturity
    collections:
    - security
  .github/agents/security/sibling-agent.agent.md:
    path: .github/agents/security/sibling-agent.agent.md
    maturity: stable
    collections:
    - security
"@
        Set-Content -LiteralPath $manifestPath -Value $manifestContent -Encoding utf8NoBOM -NoNewline
        return $manifestPath
    }
}

Describe 'Get-AgentBaseName' {
    It 'Strips (exp) suffix' {
        Get-AgentBaseName -Name 'Foo Bar (exp)' | Should -Be 'Foo Bar'
    }

    It 'Strips (pre) suffix' {
        Get-AgentBaseName -Name 'Foo Bar (pre)' | Should -Be 'Foo Bar'
    }

    It 'Returns unchanged name when no suffix is present' {
        Get-AgentBaseName -Name 'Foo Bar' | Should -Be 'Foo Bar'
    }

    It 'Ignores parenthetical text that is not a maturity suffix' {
        Get-AgentBaseName -Name 'Foo (Bar) Baz' | Should -Be 'Foo (Bar) Baz'
    }
}

Describe 'Invoke-AgentPromotion - maturity transitions' {
    BeforeEach {
        $script:testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    It 'Promotes <fromName> to <toName> via maturity <toMaturity>' -ForEach @(
        @{ fromName = 'Target Agent';       toMaturity = 'experimental'; toName = 'Target Agent (exp)' }
        @{ fromName = 'Target Agent';       toMaturity = 'preview';      toName = 'Target Agent (pre)' }
        @{ fromName = 'Target Agent (exp)'; toMaturity = 'preview';      toName = 'Target Agent (pre)' }
        @{ fromName = 'Target Agent (exp)'; toMaturity = 'stable';       toName = 'Target Agent' }
        @{ fromName = 'Target Agent (pre)'; toMaturity = 'stable';       toName = 'Target Agent' }
        @{ fromName = 'Target Agent (pre)'; toMaturity = 'experimental'; toName = 'Target Agent (exp)' }
    ) {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName $fromName

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity $toMaturity `
            -RepoRoot $script:testRoot

        $result.OldName | Should -Be $fromName
        $result.NewName | Should -Be $toName
        $result.NoOp | Should -BeFalse
        $result.FilesChanged | Should -Be 3
        $result.ReferencesRewritten | Should -Be 3

        $targetContent = Get-Content -LiteralPath $paths.TargetPath -Raw
        $targetContent | Should -Match ("(?m)^name: " + [regex]::Escape($toName) + "\s*$")
        $targetContent | Should -Not -Match ("(?m)^name: " + [regex]::Escape($fromName) + "\s*$")

        $parentContent = Get-Content -LiteralPath $paths.ParentPath -Raw
        $parentContent | Should -Match ("(?m)^\s*-\s+" + [regex]::Escape($toName) + "\s*$")
        $parentContent | Should -Not -Match ("(?m)^\s*-\s+" + [regex]::Escape($fromName) + "\s*$")

        $siblingContent = Get-Content -LiteralPath $paths.SiblingPath -Raw
        $siblingContent | Should -Match ("(?m)^\s*agent:\s+" + [regex]::Escape($toName) + "\s*$")
        $siblingContent | Should -Not -Match ("(?m)^\s*agent:\s+" + [regex]::Escape($fromName) + "\s*$")
    }

    It 'Returns NoOp when target maturity matches current suffix' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'experimental' `
            -RepoRoot $script:testRoot

        $result.NoOp | Should -BeTrue
        $result.FilesChanged | Should -Be 0
        $result.ReferencesRewritten | Should -Be 0
    }
}

Describe 'Invoke-AgentPromotion - prose mention handling' {
    BeforeEach {
        $script:testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    It 'Warns about prose mentions when -RewriteProse is omitted' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'preview' `
            -RepoRoot $script:testRoot

        $result.ProseWarnings.Count | Should -BeGreaterThan 0
        $proseFiles = $result.ProseWarnings | ForEach-Object { $_.File }
        $proseFiles | Should -Contain '.github/agents/security/parent-agent.agent.md'

        $parentContent = Get-Content -LiteralPath $paths.ParentPath -Raw
        $parentContent | Should -Match ([regex]::Escape('Parent body referring to Target Agent (exp) by name.'))
    }

    It 'Rewrites prose mentions when -RewriteProse is supplied' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'preview' `
            -RepoRoot $script:testRoot `
            -RewriteProse

        $result.ProseWarnings.Count | Should -Be 0

        $parentContent = Get-Content -LiteralPath $paths.ParentPath -Raw
        $parentContent | Should -Match ([regex]::Escape('Parent body referring to Target Agent (pre) by name.'))
        $parentContent | Should -Not -Match ([regex]::Escape('Target Agent (exp)'))
    }
}

Describe 'Invoke-AgentPromotion - WhatIf behavior' {
    BeforeEach {
        $script:testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    It 'Does not modify files when -WhatIf is used' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'

        $originalTarget = Get-Content -LiteralPath $paths.TargetPath -Raw
        $originalParent = Get-Content -LiteralPath $paths.ParentPath -Raw
        $originalSibling = Get-Content -LiteralPath $paths.SiblingPath -Raw

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'preview' `
            -RepoRoot $script:testRoot `
            -WhatIf

        $result.OldName | Should -Be 'Target Agent (exp)'
        $result.NewName | Should -Be 'Target Agent (pre)'
        $result.ReferencesRewritten | Should -Be 3

        (Get-Content -LiteralPath $paths.TargetPath -Raw)  | Should -Be $originalTarget
        (Get-Content -LiteralPath $paths.ParentPath -Raw)  | Should -Be $originalParent
        (Get-Content -LiteralPath $paths.SiblingPath -Raw) | Should -Be $originalSibling
    }
}

Describe 'Invoke-AgentPromotion - validation' {
    BeforeEach {
        $script:testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    It 'Throws when TargetMaturity is invalid' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'

        {
            Invoke-AgentPromotion -AgentPath $paths.TargetPath `
                -TargetMaturity 'invalid' `
                -RepoRoot $script:testRoot
        } | Should -Throw
    }

    It 'Throws when AgentPath does not exist' {
        {
            Invoke-AgentPromotion -AgentPath (Join-Path $script:testRoot 'missing.agent.md') `
                -TargetMaturity 'preview' `
                -RepoRoot $script:testRoot
        } | Should -Throw
    }

    It 'Throws when AgentPath is not a .agent.md file' {
        $badPath = Join-Path $script:testRoot 'not-an-agent.md'
        Set-Content -LiteralPath $badPath -Value "---`nname: Foo`n---`n" -Encoding utf8NoBOM -NoNewline

        {
            Invoke-AgentPromotion -AgentPath $badPath `
                -TargetMaturity 'preview' `
                -RepoRoot $script:testRoot
        } | Should -Throw
    }

    It 'Throws when target agent is missing the name frontmatter field' {
        $agentsDir = Join-Path $script:testRoot '.github/agents/security'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        $noNamePath = Join-Path $agentsDir 'no-name.agent.md'
        Set-Content -LiteralPath $noNamePath -Value "---`ndescription: missing name`n---`n" -Encoding utf8NoBOM -NoNewline

        {
            Invoke-AgentPromotion -AgentPath $noNamePath `
                -TargetMaturity 'preview' `
                -RepoRoot $script:testRoot
        } | Should -Throw
    }
}

Describe 'Update-CoreManifestAgentMaturity' {
    It 'Updates the maturity value for the matching agent entry' {
        $content = @"
artifacts:
  .github/agents/security/target-agent.agent.md:
    path: .github/agents/security/target-agent.agent.md
    maturity: experimental
    collections:
    - security
"@
        $result = Update-CoreManifestAgentMaturity -Content $content `
            -AgentRelativePath '.github/agents/security/target-agent.agent.md' `
            -NewMaturity 'preview'

        $result.Updated | Should -BeTrue
        $result.OldMaturity | Should -Be 'experimental'
        $result.NewMaturity | Should -Be 'preview'
        $result.Content | Should -Match '(?m)^\s+maturity: preview\s*$'
        $result.Content | Should -Not -Match '(?m)^\s+maturity: experimental\s*$'
    }

    It 'Does not touch other agent entries that share a path prefix' {
        $content = @"
artifacts:
  .github/agents/security/target-agent.agent.md:
    path: .github/agents/security/target-agent.agent.md
    maturity: experimental
    collections:
    - security
  .github/agents/security/target-agent-helper.agent.md:
    path: .github/agents/security/target-agent-helper.agent.md
    maturity: stable
    collections:
    - security
"@
        $result = Update-CoreManifestAgentMaturity -Content $content `
            -AgentRelativePath '.github/agents/security/target-agent.agent.md' `
            -NewMaturity 'preview'

        $result.Updated | Should -BeTrue
        ([regex]::Matches($result.Content, '(?m)^\s+maturity: stable\s*$')).Count | Should -Be 1
        ([regex]::Matches($result.Content, '(?m)^\s+maturity: preview\s*$')).Count | Should -Be 1
    }

    It 'Reports already-aligned when maturity already matches' {
        $content = @"
artifacts:
  .github/agents/security/target-agent.agent.md:
    path: .github/agents/security/target-agent.agent.md
    maturity: preview
    collections:
    - security
"@
        $result = Update-CoreManifestAgentMaturity -Content $content `
            -AgentRelativePath '.github/agents/security/target-agent.agent.md' `
            -NewMaturity 'preview'

        $result.Updated | Should -BeFalse
        $result.Reason | Should -Be 'already-aligned'
        $result.Content | Should -Be $content
    }

    It 'Reports entry-not-found when the agent is absent' {
        $content = @"
artifacts:
  .github/agents/security/other-agent.agent.md:
    path: .github/agents/security/other-agent.agent.md
    maturity: stable
    collections:
    - security
"@
        $result = Update-CoreManifestAgentMaturity -Content $content `
            -AgentRelativePath '.github/agents/security/target-agent.agent.md' `
            -NewMaturity 'preview'

        $result.Updated | Should -BeFalse
        $result.Reason | Should -Be 'entry-not-found'
        $result.Content | Should -Be $content
    }
}

Describe 'Invoke-AgentPromotion - manifest maturity sync' {
    BeforeEach {
        $script:testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    It 'Syncs the manifest maturity when promoting the agent' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'
        $manifestPath = New-TestManifest -Root $script:testRoot -TargetMaturity 'experimental'

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'preview' `
            -RepoRoot $script:testRoot `
            -ManifestPath $manifestPath

        $result.ManifestUpdated | Should -BeTrue
        $result.ManifestOldMaturity | Should -Be 'experimental'
        $result.ManifestNewMaturity | Should -Be 'preview'

        $manifestContent = Get-Content -LiteralPath $manifestPath -Raw
        $manifestContent | Should -Match '(?m)^\s+path: \.github/agents/security/target-agent\.agent\.md\s*\r?\n\s+maturity: preview\s*$'
    }

    It 'Defaults the manifest path to collections/core-manifest.yml under RepoRoot' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'
        $manifestPath = New-TestManifest -Root $script:testRoot -TargetMaturity 'experimental'

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'stable' `
            -RepoRoot $script:testRoot

        $result.ManifestUpdated | Should -BeTrue

        $manifestContent = Get-Content -LiteralPath $manifestPath -Raw
        $manifestContent | Should -Match '(?m)^\s+path: \.github/agents/security/target-agent\.agent\.md\s*\r?\n\s+maturity: stable\s*$'
    }

    It 'Does not modify the manifest when -WhatIf is used' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'
        $manifestPath = New-TestManifest -Root $script:testRoot -TargetMaturity 'experimental'
        $originalManifest = Get-Content -LiteralPath $manifestPath -Raw

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'preview' `
            -RepoRoot $script:testRoot `
            -ManifestPath $manifestPath `
            -WhatIf

        $result.ManifestUpdated | Should -BeTrue
        (Get-Content -LiteralPath $manifestPath -Raw) | Should -Be $originalManifest
    }

    It 'Skips sync with a warning when the manifest is missing' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'preview' `
            -RepoRoot $script:testRoot `
            -ManifestPath (Join-Path $script:testRoot 'collections/core-manifest.yml') `
            -WarningAction SilentlyContinue

        $result.ManifestUpdated | Should -BeFalse
        $result.ManifestReason | Should -Be 'manifest-not-found'
        $result.FilesChanged | Should -Be 3
    }

    It 'Skips sync when the agent is absent from the manifest' {
        $paths = New-TestAgentRepo -Root $script:testRoot -TargetName 'Target Agent (exp)'
        $manifestPath = Join-Path $script:testRoot 'collections/core-manifest.yml'
        New-Item -ItemType Directory -Path (Split-Path $manifestPath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $manifestPath -Value "artifacts:`n  other:`n    path: other`n    maturity: stable`n" -Encoding utf8NoBOM -NoNewline

        $result = Invoke-AgentPromotion -AgentPath $paths.TargetPath `
            -TargetMaturity 'preview' `
            -RepoRoot $script:testRoot `
            -ManifestPath $manifestPath `
            -WarningAction SilentlyContinue

        $result.ManifestUpdated | Should -BeFalse
        $result.ManifestReason | Should -Be 'entry-not-found'
    }
}
