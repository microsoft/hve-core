#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/ArtifactHelpers.psm1') -Force

    # Expected values are authored here independently of the module under test.
    $script:ExpectedVocabulary = @('stable', 'preview', 'experimental', 'deprecated', 'removed')
    $script:ExpectedBeginMarker = '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
    $script:ExpectedEndMarker = '<!-- END AUTO-GENERATED ARTIFACTS -->'
}

Describe 'Get-MaturityVocabulary' -Tag 'Unit' {
    Context 'when the vocabulary is requested' {
        BeforeAll {
            $script:Vocabulary = Get-MaturityVocabulary
        }

        It 'Returns exactly five maturity values' {
            $script:Vocabulary | Should -HaveCount 5
        }

        It 'Orders values from least to most restrictive' {
            ($script:Vocabulary -join '|') | Should -BeExactly 'stable|preview|experimental|deprecated|removed'
        }

        It 'Places <Value> at position <Index>' -ForEach @(
            @{ Index = 0; Value = 'stable' }
            @{ Index = 1; Value = 'preview' }
            @{ Index = 2; Value = 'experimental' }
            @{ Index = 3; Value = 'deprecated' }
            @{ Index = 4; Value = 'removed' }
        ) {
            $script:Vocabulary[$Index] | Should -BeExactly $Value
        }

        It 'Returns a flat string collection rather than a nested array' {
            $script:Vocabulary[0] | Should -BeOfType [string]
        }
    }
}

Describe 'Get-MaturityRank' -Tag 'Unit' {
    Context 'when ranks are derived from the vocabulary' {
        BeforeAll {
            $script:Rank = Get-MaturityRank
        }

        It 'Ranks exactly the five vocabulary values' {
            $script:Rank.Keys | Should -HaveCount 5
            foreach ($maturity in $script:ExpectedVocabulary) {
                $script:Rank.ContainsKey($maturity) | Should -BeTrue -Because "'$maturity' belongs to the vocabulary"
            }
        }

        It 'Assigns <Value> the rank <Expected>' -ForEach @(
            @{ Value = 'stable'; Expected = 0 }
            @{ Value = 'preview'; Expected = 1 }
            @{ Value = 'experimental'; Expected = 2 }
            @{ Value = 'deprecated'; Expected = 3 }
            @{ Value = 'removed'; Expected = 4 }
        ) {
            $script:Rank[$Value] | Should -Be $Expected
        }

        It 'Omits values outside the vocabulary' {
            $script:Rank.ContainsKey('beta') | Should -BeFalse
        }
    }
}

Describe 'Resolve-ArtifactMaturity' -Tag 'Unit' {
    Context 'when maturity metadata is absent' {
        It 'Defaults a null value to stable' {
            Resolve-ArtifactMaturity -Maturity $null | Should -BeExactly 'stable'
        }

        It 'Defaults an empty value to stable' {
            Resolve-ArtifactMaturity -Maturity '' | Should -BeExactly 'stable'
        }

        It 'Defaults a whitespace value to stable' {
            Resolve-ArtifactMaturity -Maturity '   ' | Should -BeExactly 'stable'
        }
    }

    Context 'when maturity metadata is declared' {
        It 'Returns <Value> unchanged' -ForEach @(
            @{ Value = 'stable' }
            @{ Value = 'preview' }
            @{ Value = 'experimental' }
            @{ Value = 'deprecated' }
            @{ Value = 'removed' }
        ) {
            Resolve-ArtifactMaturity -Maturity $Value | Should -BeExactly $Value
        }

        It 'Returns an unrecognized value unchanged' {
            Resolve-ArtifactMaturity -Maturity 'beta' | Should -BeExactly 'beta'
        }
    }
}

Describe 'Resolve-StrictSafeMaturity' -Tag 'Unit' {
    BeforeAll {
        Mock Write-CIAnnotation {} -ModuleName ArtifactHelpers
    }

    Context 'when the maturity is rankable' {
        It 'Returns <Value> unchanged' -ForEach @(
            @{ Value = 'stable' }
            @{ Value = 'preview' }
            @{ Value = 'experimental' }
            @{ Value = 'deprecated' }
            @{ Value = 'removed' }
        ) {
            Resolve-StrictSafeMaturity -Maturity $Value -Source 'unit test' | Should -BeExactly $Value
        }

        It 'Emits no CI annotation' {
            Resolve-StrictSafeMaturity -Maturity 'stable' -Source 'unit test' | Out-Null
            Should -Invoke Write-CIAnnotation -ModuleName ArtifactHelpers -Times 0 -Exactly
        }
    }

    Context 'when the maturity is unrankable' {
        It 'Falls back to experimental rather than stable' {
            Resolve-StrictSafeMaturity -Maturity 'beta' -Source 'unit test' | Should -BeExactly 'experimental'
        }

        It 'Falls back to experimental for an empty maturity' {
            Resolve-StrictSafeMaturity -Maturity '' -Source 'unit test' | Should -BeExactly 'experimental'
        }

        It 'Raises exactly one warning-level CI annotation' {
            Resolve-StrictSafeMaturity -Maturity 'beta' -Source 'unit test' | Out-Null
            Should -Invoke Write-CIAnnotation -ModuleName ArtifactHelpers -Times 1 -Exactly -ParameterFilter {
                $Level -eq 'Warning'
            }
        }

        It 'Names the rejected value and the caller-supplied source' {
            Resolve-StrictSafeMaturity -Maturity 'beta' -Source 'catalog entry demo' | Out-Null
            Should -Invoke Write-CIAnnotation -ModuleName ArtifactHelpers -Times 1 -Exactly -ParameterFilter {
                $Message -like "*Unrankable maturity 'beta' from catalog entry demo.*"
            }
        }

        It 'Explains the experimental fallback and lists the full remediation vocabulary' {
            Resolve-StrictSafeMaturity -Maturity 'beta' -Source 'unit test' | Out-Null
            Should -Invoke Write-CIAnnotation -ModuleName ArtifactHelpers -Times 1 -Exactly -ParameterFilter {
                $Message -like "*defaults it to 'experimental'*" -and
                $Message -like '*stable, preview, experimental, deprecated, removed*'
            }
        }

        It 'Uses a descriptive default source when none is supplied' {
            Resolve-StrictSafeMaturity -Maturity 'beta' | Out-Null
            Should -Invoke Write-CIAnnotation -ModuleName ArtifactHelpers -Times 1 -Exactly -ParameterFilter {
                $Message -like '*from an unspecified source.*'
            }
        }
    }
}

Describe 'Set-ContentIfChanged' -Tag 'Unit' {
    Context 'when the target file does not exist' {
        BeforeAll {
            $script:CreatePath = Join-Path $TestDrive 'created/deeply/nested/output.md'
            $script:CreateResult = Set-ContentIfChanged -Path $script:CreatePath -Value 'first write'
        }

        It 'Reports that content was written' {
            $script:CreateResult | Should -BeTrue
        }

        It 'Creates the missing parent directories' {
            Test-Path -LiteralPath (Split-Path -Path $script:CreatePath -Parent) | Should -BeTrue
        }

        It 'Writes the supplied value verbatim' {
            Get-Content -LiteralPath $script:CreatePath -Raw | Should -BeExactly 'first write'
        }
    }

    Context 'when the content is unchanged' {
        BeforeAll {
            $script:NoOpPath = Join-Path $TestDrive 'noop/output.md'
            Set-ContentIfChanged -Path $script:NoOpPath -Value 'stable content' | Out-Null
            $script:FrozenTime = [datetime]::new(2020, 1, 2, 3, 4, 5, [System.DateTimeKind]::Utc)
            [System.IO.File]::SetLastWriteTimeUtc($script:NoOpPath, $script:FrozenTime)
            $script:NoOpResult = Set-ContentIfChanged -Path $script:NoOpPath -Value 'stable content'
        }

        It 'Reports that nothing was written' {
            $script:NoOpResult | Should -BeFalse
        }

        It 'Preserves the last write time' {
            [System.IO.File]::GetLastWriteTimeUtc($script:NoOpPath) | Should -Be $script:FrozenTime
        }

        It 'Preserves the existing content' {
            Get-Content -LiteralPath $script:NoOpPath -Raw | Should -BeExactly 'stable content'
        }
    }

    Context 'when the content differs only by case' {
        BeforeAll {
            $script:OrdinalPath = Join-Path $TestDrive 'ordinal/output.md'
            Set-ContentIfChanged -Path $script:OrdinalPath -Value 'casing matters' | Out-Null
            $script:OrdinalResult = Set-ContentIfChanged -Path $script:OrdinalPath -Value 'CASING MATTERS'
        }

        It 'Compares ordinally and rewrites the file' {
            $script:OrdinalResult | Should -BeTrue
        }

        It 'Stores the new casing' {
            Get-Content -LiteralPath $script:OrdinalPath -Raw | Should -BeExactly 'CASING MATTERS'
        }
    }

    Context 'when non-ASCII content is written' {
        BeforeAll {
            $script:EncodingPath = Join-Path $TestDrive 'encoding/output.md'
            Set-ContentIfChanged -Path $script:EncodingPath -Value "h`u{00E9}llo" | Out-Null
            $script:EncodedBytes = [System.IO.File]::ReadAllBytes($script:EncodingPath)
        }

        It 'Writes UTF-8 bytes without a byte order mark' {
            ($script:EncodedBytes | ForEach-Object { $_.ToString('x2') }) -join ' ' | Should -BeExactly '68 c3 a9 6c 6c 6f'
        }

        It 'Appends no trailing newline' {
            $script:EncodedBytes[-1] | Should -Be ([byte]0x6F)
        }

        It 'Writes exactly six bytes' {
            $script:EncodedBytes | Should -HaveCount 6
        }
    }
}

Describe 'Get-PackageDocArtifactHeadingPattern' -Tag 'Unit' {
    BeforeAll {
        $script:HeadingPattern = Get-PackageDocArtifactHeadingPattern
    }

    It 'Carries its own case-insensitivity flag' {
        # Consumers evaluate this pattern through both the match operator and
        # [regex]::Match. The operator ignores case by default and the API does
        # not, so the flag must travel with the pattern rather than the caller.
        $script:HeadingPattern | Should -Match '\(\?[a-z]*i[a-z]*\)'
    }

    It 'Matches <Label> through the case-sensitive regex API' -ForEach @(
        @{ Label = 'the canonical heading'; Line = '## Included Artifacts' }
        @{ Label = 'a lowercase variant'; Line = '## Included artifacts' }
        @{ Label = 'an uppercase variant'; Line = '## INCLUDED ARTIFACTS' }
        @{ Label = 'a multi-space variant'; Line = '##  Included Artifacts' }
    ) {
        [regex]::Match("Intro`n$Line`nRest", $script:HeadingPattern).Success | Should -BeTrue
    }

    It 'Rejects <Label> through the case-sensitive regex API' -ForEach @(
        @{ Label = 'an inline mention'; Line = 'see ## Included Artifacts below' }
        @{ Label = 'a third-level heading'; Line = '### Included Artifacts' }
        @{ Label = 'a heading with trailing punctuation'; Line = '## Included Artifacts:' }
    ) {
        [regex]::Match("Intro`n$Line`nRest", $script:HeadingPattern).Success | Should -BeFalse
    }

    It 'Reports an offset a caller can truncate at' {
        $document = "Intro prose.`n`n## Included artifacts`n`nstale table"
        $headingMatch = [regex]::Match($document, $script:HeadingPattern)
        $headingMatch.Success | Should -BeTrue
        $document.Substring(0, $headingMatch.Index).Trim() | Should -BeExactly 'Intro prose.'
    }
}

Describe 'Split-PackageDocByMarkers' -Tag 'Unit' {
    Context 'when the module exports its markers' {
        BeforeAll {
            $script:ExportedVariables = (Get-Module ArtifactHelpers).ExportedVariables
        }

        It 'Exports exactly the two marker variables' {
            ($script:ExportedVariables.Keys | Sort-Object) -join ',' | Should -BeExactly 'PackageDocBeginMarker,PackageDocEndMarker'
        }

        It 'Exposes the begin marker text' {
            $script:ExportedVariables['PackageDocBeginMarker'].Value | Should -BeExactly $script:ExpectedBeginMarker
        }

        It 'Exposes the end marker text' {
            $script:ExportedVariables['PackageDocEndMarker'].Value | Should -BeExactly $script:ExpectedEndMarker
        }
    }

    Context 'when both markers are present in order' {
        BeforeAll {
            $script:MarkedContent = @(
                '# Package',
                '',
                'Hand-written intro.',
                '',
                $script:ExpectedBeginMarker,
                '| Artifact | Description |',
                $script:ExpectedEndMarker,
                '',
                '## Footer',
                'Hand-written footer.',
                ''
            ) -join "`n"
            $script:MarkedResult = Split-PackageDocByMarkers -Content $script:MarkedContent
        }

        It 'Reports that markers were found' {
            $script:MarkedResult.HasMarkers | Should -BeTrue
        }

        It 'Returns the intro with trailing whitespace trimmed' {
            $script:MarkedResult.Intro | Should -BeExactly "# Package`n`nHand-written intro."
        }

        It 'Preserves the footer without its leading blank line' {
            $script:MarkedResult.Footer | Should -BeExactly "## Footer`nHand-written footer.`n"
        }

        It 'Drops the generated region between the markers' {
            $script:MarkedResult.Intro | Should -Not -Match 'Artifact'
            $script:MarkedResult.Footer | Should -Not -Match 'Artifact'
        }
    }

    Context 'when the end marker terminates the document' {
        BeforeAll {
            $script:NoFooterResult = Split-PackageDocByMarkers -Content "Intro`n$($script:ExpectedBeginMarker)`ngenerated`n$($script:ExpectedEndMarker)"
        }

        It 'Reports that markers were found' {
            $script:NoFooterResult.HasMarkers | Should -BeTrue
        }

        It 'Returns an empty footer' {
            $script:NoFooterResult.Footer | Should -BeExactly ''
        }
    }

    Context 'when markers are missing or malformed' {
        It 'Returns the whole document untrimmed when no markers are present' {
            $result = Split-PackageDocByMarkers -Content "Plain document.`n`n"
            $result.HasMarkers | Should -BeFalse
            $result.Intro | Should -BeExactly "Plain document.`n`n"
            $result.Footer | Should -BeExactly ''
        }

        It 'Returns no markers when only the begin marker is present' {
            $result = Split-PackageDocByMarkers -Content "Intro`n$($script:ExpectedBeginMarker)`ngenerated`n"
            $result.HasMarkers | Should -BeFalse
            $result.Intro | Should -BeExactly "Intro`n$($script:ExpectedBeginMarker)`ngenerated`n"
        }

        It 'Returns no markers when only the end marker is present' {
            $result = Split-PackageDocByMarkers -Content "Intro`n$($script:ExpectedEndMarker)`n"
            $result.HasMarkers | Should -BeFalse
            $result.Intro | Should -BeExactly "Intro`n$($script:ExpectedEndMarker)`n"
        }

        It 'Returns no markers when the markers appear in reverse order' {
            $reversed = "Intro`n$($script:ExpectedEndMarker)`nmiddle`n$($script:ExpectedBeginMarker)`n"
            $result = Split-PackageDocByMarkers -Content $reversed
            $result.HasMarkers | Should -BeFalse
            $result.Intro | Should -BeExactly $reversed
            $result.Footer | Should -BeExactly ''
        }

        It 'Rejects empty content' {
            { Split-PackageDocByMarkers -Content '' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }
    }
}

Describe 'Get-ArtifactKey' -Tag 'Unit' {
    It 'Derives <Expected> for kind <Kind>' -ForEach @(
        @{ Kind = 'agent'; Path = '.github/agents/rpi/rpi-agent.agent.md'; Expected = 'rpi-agent' }
        @{ Kind = 'prompt'; Path = '.github/prompts/ado/create-pull-request.prompt.md'; Expected = 'create-pull-request' }
        @{ Kind = 'instruction'; Path = '.github/instructions/hve-core/markdown.instructions.md'; Expected = 'hve-core/markdown' }
        @{ Kind = 'skill'; Path = '.github/skills/rpi/rpi-plan'; Expected = 'rpi-plan' }
        @{ Kind = 'hook'; Path = '.github/hooks/hve-core/hooks.json'; Expected = 'hooks' }
    ) {
        Get-ArtifactKey -Kind $Kind -Path $Path | Should -BeExactly $Expected
    }

    It 'Strips a trailing slash from a skill directory path' {
        Get-ArtifactKey -Kind 'skill' -Path '.github/skills/rpi/rpi-plan/' | Should -BeExactly 'rpi-plan'
    }

    It 'Keeps nested instruction subpaths in the key' {
        Get-ArtifactKey -Kind 'instruction' -Path '.github/instructions/security/vex/rules.instructions.md' |
            Should -BeExactly 'security/vex/rules'
    }

    Context 'when the kind has no dedicated rule' {
        It 'Strips a suffix matching the kind' {
            Get-ArtifactKey -Kind 'chatmode' -Path '.github/chatmodes/demo/planner.chatmode.md' | Should -BeExactly 'planner'
        }

        It 'Strips the markdown extension when the suffix does not match the kind' {
            Get-ArtifactKey -Kind 'widget' -Path '.github/widgets/demo/panel.md' | Should -BeExactly 'panel'
        }

        It 'Returns the file name for non-markdown paths' {
            Get-ArtifactKey -Kind 'widget' -Path '.github/widgets/demo/panel.json' | Should -BeExactly 'panel.json'
        }
    }
}

Describe 'Get-ArtifactFrontmatter' -Tag 'Unit' {
    BeforeAll {
        $script:FrontmatterRoot = Join-Path $TestDrive 'frontmatter'
        New-Item -ItemType Directory -Path $script:FrontmatterRoot -Force | Out-Null

        $script:WithDescription = Join-Path $script:FrontmatterRoot 'described.agent.md'
        Set-Content -LiteralPath $script:WithDescription -Value "---`ndescription: Reviews pull requests`nname: Reviewer`n---`n`n# Body`n" -NoNewline

        $script:WithoutDescription = Join-Path $script:FrontmatterRoot 'undescribed.agent.md'
        Set-Content -LiteralPath $script:WithoutDescription -Value "---`nname: Reviewer`n---`n`n# Body`n" -NoNewline

        $script:WithoutFrontmatter = Join-Path $script:FrontmatterRoot 'bare.agent.md'
        Set-Content -LiteralPath $script:WithoutFrontmatter -Value "# Body only`n" -NoNewline

        $script:MalformedFrontmatter = Join-Path $script:FrontmatterRoot 'malformed.agent.md'
        Set-Content -LiteralPath $script:MalformedFrontmatter -Value "---`ndescription: value`n  bad: indentation`n---`n" -NoNewline
    }

    It 'Reads the description from frontmatter' {
        (Get-ArtifactFrontmatter -FilePath $script:WithDescription).description | Should -BeExactly 'Reviews pull requests'
    }

    It 'Prefers the frontmatter description over the fallback' {
        (Get-ArtifactFrontmatter -FilePath $script:WithDescription -FallbackDescription 'unused').description |
            Should -BeExactly 'Reviews pull requests'
    }

    It 'Uses the fallback when frontmatter omits a description' {
        (Get-ArtifactFrontmatter -FilePath $script:WithoutDescription -FallbackDescription 'fallback text').description |
            Should -BeExactly 'fallback text'
    }

    It 'Uses the fallback when no frontmatter is present' {
        (Get-ArtifactFrontmatter -FilePath $script:WithoutFrontmatter -FallbackDescription 'fallback text').description |
            Should -BeExactly 'fallback text'
    }

    It 'Returns an empty description when no fallback is supplied' {
        (Get-ArtifactFrontmatter -FilePath $script:WithoutFrontmatter).description | Should -BeExactly ''
    }

    It 'Warns and falls back when frontmatter cannot be parsed' {
        $warnings = @()
        $result = Get-ArtifactFrontmatter -FilePath $script:MalformedFrontmatter -FallbackDescription 'fallback text' -WarningVariable warnings -WarningAction SilentlyContinue
        $result.description | Should -BeExactly 'fallback text'
        $warnings | Should -Not -BeNullOrEmpty
        $warnings[0].Message | Should -BeLike 'Failed to parse YAML frontmatter in malformed.agent.md*'
    }
}

Describe 'Get-ArtifactDescription' -Tag 'Unit' {
    BeforeAll {
        $script:DescriptionRoot = Join-Path $TestDrive 'descriptions'
        New-Item -ItemType Directory -Path $script:DescriptionRoot -Force | Out-Null

        $script:MarkdownArtifact = Join-Path $script:DescriptionRoot 'agent.agent.md'
        Set-Content -LiteralPath $script:MarkdownArtifact -Value "---`ndescription: '  Padded description  '`n---`n" -NoNewline

        $script:MarkdownWithoutFrontmatter = Join-Path $script:DescriptionRoot 'bare.agent.md'
        Set-Content -LiteralPath $script:MarkdownWithoutFrontmatter -Value "# No frontmatter`n" -NoNewline

        $script:HookManifest = Join-Path $script:DescriptionRoot 'hooks.json'
        Set-Content -LiteralPath $script:HookManifest -Value '{ "description": "  Hook manifest  ", "hooks": {} }' -NoNewline

        $script:HookWithoutDescription = Join-Path $script:DescriptionRoot 'silent.json'
        Set-Content -LiteralPath $script:HookWithoutDescription -Value '{ "hooks": {} }' -NoNewline

        $script:MalformedJson = Join-Path $script:DescriptionRoot 'broken.json'
        Set-Content -LiteralPath $script:MalformedJson -Value '{ "description": ' -NoNewline
    }

    It 'Trims the Markdown frontmatter description' {
        Get-ArtifactDescription -FilePath $script:MarkdownArtifact | Should -BeExactly 'Padded description'
    }

    It 'Trims the JSON hook description' {
        Get-ArtifactDescription -FilePath $script:HookManifest | Should -BeExactly 'Hook manifest'
    }

    It 'Returns an empty string when JSON omits a description' {
        Get-ArtifactDescription -FilePath $script:HookWithoutDescription | Should -BeExactly ''
    }

    It 'Returns an empty string when JSON cannot be parsed' {
        Get-ArtifactDescription -FilePath $script:MalformedJson | Should -BeExactly ''
    }

    It 'Returns an empty string when Markdown has no frontmatter' {
        Get-ArtifactDescription -FilePath $script:MarkdownWithoutFrontmatter | Should -BeExactly ''
    }

    It 'Returns an empty string when the file is missing' {
        Get-ArtifactDescription -FilePath (Join-Path $script:DescriptionRoot 'absent.agent.md') | Should -BeExactly ''
    }
}

Describe 'Artifact path predicates' -Tag 'Unit' {
    Context 'Test-DeprecatedPath' {
        It 'Flags <Path>' -ForEach @(
            @{ Path = '.github/agents/deprecated/old.agent.md' }
            @{ Path = '.github/skills/demo/deprecated/retired/SKILL.md' }
            @{ Path = '.github\agents\deprecated\old.agent.md' }
        ) {
            Test-DeprecatedPath -Path $Path | Should -BeTrue
        }

        It 'Allows <Path>' -ForEach @(
            @{ Path = '.github/agents/demo/current.agent.md' }
            @{ Path = '.github/agents/deprecated-review/current.agent.md' }
            @{ Path = '.github/skills/deprecation-policy/SKILL.md' }
        ) {
            Test-DeprecatedPath -Path $Path | Should -BeFalse
        }
    }

    Context 'Test-HveCoreRepoSpecificPath' {
        It 'Flags a type-relative root file' {
            Test-HveCoreRepoSpecificPath -RelativePath 'code-review.agent.md' | Should -BeTrue
        }

        It 'Allows a package-scoped type-relative path' {
            Test-HveCoreRepoSpecificPath -RelativePath 'coding-standards/code-review.agent.md' | Should -BeFalse
        }
    }

    Context 'Test-HveCoreRepoRelativePath' {
        It 'Flags root-level <Path>' -ForEach @(
            @{ Path = '.github/agents/code-review.agent.md' }
            @{ Path = '.github/instructions/pull-request.instructions.md' }
            @{ Path = '.github/prompts/commit.prompt.md' }
            @{ Path = '.github/hooks/hooks.json' }
            @{ Path = '.github/skills/orphan-skill' }
        ) {
            Test-HveCoreRepoRelativePath -Path $Path | Should -BeTrue
        }

        It 'Allows package-scoped <Path>' -ForEach @(
            @{ Path = '.github/agents/coding-standards/code-review.agent.md' }
            @{ Path = '.github/instructions/hve-core/pull-request.instructions.md' }
            @{ Path = '.github/prompts/ado/commit.prompt.md' }
            @{ Path = '.github/hooks/hve-core/hooks.json' }
            @{ Path = '.github/skills/rpi/rpi-plan' }
        ) {
            Test-HveCoreRepoRelativePath -Path $Path | Should -BeFalse
        }

        It 'Ignores directories outside the artifact roots' {
            Test-HveCoreRepoRelativePath -Path '.github/workflows/ci.yml' | Should -BeFalse
        }
    }
}

Describe 'Get-ArtifactFiles' -Tag 'Unit' {
    BeforeAll {
        $script:DiscoveryRoot = Join-Path $TestDrive 'discovery-repo'

        # Distributable artifacts that discovery must return.
        $script:IncludedPaths = @(
            '.github/agents/demo/packaged.agent.md'
            '.github/prompts/demo/packaged.prompt.md'
            '.github/instructions/demo/packaged.instructions.md'
            '.github/skills/demo/packaged-skill/SKILL.md'
            '.github/hooks/demo/hooks.json'
            '.github/hooks/demo/extra.json'
        )

        # Sentinels that discovery must exclude; each one would otherwise match a discovery glob.
        $script:SentinelPaths = @(
            '.github/agents/root-repo-specific.agent.md'
            '.github/prompts/root-repo-specific.prompt.md'
            '.github/instructions/root-repo-specific.instructions.md'
            '.github/agents/deprecated/retired.agent.md'
            '.github/skills/orphan-skill/SKILL.md'
            '.github/skills/demo/deprecated/retired-skill/SKILL.md'
            '.github/hooks/demo/nested/implementation.json'
        )

        foreach ($relativePath in ($script:IncludedPaths + $script:SentinelPaths)) {
            $absolutePath = Join-Path $script:DiscoveryRoot $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Path $absolutePath -Parent) -Force | Out-Null
            Set-Content -LiteralPath $absolutePath -Value "---`ndescription: sentinel`n---`n" -NoNewline
        }

        $script:Discovered = @(Get-ArtifactFiles -RepoRoot $script:DiscoveryRoot)
        $script:DiscoveredPaths = @($script:Discovered | ForEach-Object { $_.path } | Sort-Object)
    }

    It 'Plants every sentinel on disk so exclusions are not vacuous' {
        $script:SentinelPaths | Should -HaveCount 7
        foreach ($relativePath in $script:SentinelPaths) {
            Test-Path -LiteralPath (Join-Path $script:DiscoveryRoot $relativePath) |
                Should -BeTrue -Because "sentinel '$relativePath' must exist for its exclusion to be meaningful"
        }
    }

    It 'Returns exactly the six distributable artifacts' {
        $script:Discovered | Should -HaveCount 6
    }

    It 'Returns the distributable paths in canonical form' {
        ($script:DiscoveredPaths -join "`n") | Should -BeExactly (@(
                '.github/agents/demo/packaged.agent.md'
                '.github/hooks/demo/extra.json'
                '.github/hooks/demo/hooks.json'
                '.github/instructions/demo/packaged.instructions.md'
                '.github/prompts/demo/packaged.prompt.md'
                '.github/skills/demo/packaged-skill'
            ) -join "`n")
    }

    It 'Maps <Path> to kind <Kind>' -ForEach @(
        @{ Path = '.github/agents/demo/packaged.agent.md'; Kind = 'agent' }
        @{ Path = '.github/prompts/demo/packaged.prompt.md'; Kind = 'prompt' }
        @{ Path = '.github/instructions/demo/packaged.instructions.md'; Kind = 'instruction' }
        @{ Path = '.github/skills/demo/packaged-skill'; Kind = 'skill' }
        @{ Path = '.github/hooks/demo/hooks.json'; Kind = 'hook' }
    ) {
        $match = @($script:Discovered | Where-Object { $_.path -eq $Path })
        $match | Should -HaveCount 1
        $match[0].kind | Should -BeExactly $Kind
    }

    It 'Excludes root-level repository-specific <Path>' -ForEach @(
        @{ Path = '.github/agents/root-repo-specific.agent.md' }
        @{ Path = '.github/prompts/root-repo-specific.prompt.md' }
        @{ Path = '.github/instructions/root-repo-specific.instructions.md' }
        @{ Path = '.github/skills/orphan-skill' }
    ) {
        $script:DiscoveredPaths | Should -Not -Contain $Path
    }

    It 'Excludes deprecated <Path>' -ForEach @(
        @{ Path = '.github/agents/deprecated/retired.agent.md' }
        @{ Path = '.github/skills/demo/deprecated/retired-skill' }
    ) {
        $script:DiscoveredPaths | Should -Not -Contain $Path
    }

    It 'Excludes hook implementation files nested below the package manifest level' {
        $script:DiscoveredPaths | Should -Not -Contain '.github/hooks/demo/nested/implementation.json'
        @($script:Discovered | Where-Object { $_.kind -eq 'hook' }) | Should -HaveCount 2
    }

    It 'Returns nothing for a repository without a .github directory' {
        $emptyRoot = Join-Path $TestDrive 'empty-repo'
        New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
        @(Get-ArtifactFiles -RepoRoot $emptyRoot) | Should -HaveCount 0
    }
}

AfterAll {
    Remove-Module ArtifactHelpers -Force -ErrorAction SilentlyContinue
}
