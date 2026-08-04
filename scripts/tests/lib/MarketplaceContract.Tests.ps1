#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force

    # Expected values are authored here independently of the module under test.
    $script:ExpectedFields = @('agents', 'commands', 'rules', 'skills', 'hooks')
    $script:ExpectedKinds = @('agent', 'prompt', 'instruction', 'skill', 'hook')
    $script:ExpectedMetadataKeys = @('displayName', 'maturity', 'componentMaturity', 'documentation', 'profiles')
}

Describe 'Get-MarketplaceComponentFieldMap' -Tag 'Unit' {
    BeforeAll {
        $script:FieldMap = Get-MarketplaceComponentFieldMap
    }

    It 'Declares exactly five component fields' {
        $script:FieldMap.Count | Should -Be 5
    }

    It 'Preserves the canonical field order' {
        ($script:FieldMap.Keys -join '|') | Should -BeExactly 'agents|commands|rules|skills|hooks'
    }

    It 'Preserves the canonical kind order' {
        ($script:FieldMap.Values -join '|') | Should -BeExactly 'agent|prompt|instruction|skill|hook'
    }

    It 'Maps field <Field> to kind <Kind>' -ForEach @(
        @{ Field = 'agents'; Kind = 'agent' }
        @{ Field = 'commands'; Kind = 'prompt' }
        @{ Field = 'rules'; Kind = 'instruction' }
        @{ Field = 'skills'; Kind = 'skill' }
        @{ Field = 'hooks'; Kind = 'hook' }
    ) {
        $script:FieldMap[$Field] | Should -BeExactly $Kind
    }

    It 'Returns an ordered dictionary' {
        $script:FieldMap | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
    }
}

Describe 'Get-MarketplaceMetadataKey' -Tag 'Unit' {
    BeforeAll {
        $script:MetadataKeys = Get-MarketplaceMetadataKey
    }

    It 'Returns a flat collection of five keys' {
        $script:MetadataKeys.Count | Should -Be 5
        $script:MetadataKeys[0] | Should -BeOfType [string]
    }

    It 'Returns the closed metadata key set in declaration order' {
        ($script:MetadataKeys -join '|') | Should -BeExactly 'displayName|maturity|componentMaturity|documentation|profiles'
    }

    It 'Includes metadata key <Key>' -ForEach @(
        @{ Key = 'displayName' }
        @{ Key = 'maturity' }
        @{ Key = 'componentMaturity' }
        @{ Key = 'documentation' }
        @{ Key = 'profiles' }
    ) {
        $script:MetadataKeys | Should -Contain $Key
    }

    It 'Keeps metadata keys disjoint from component field <Field>' -ForEach @(
        @{ Field = 'agents' }
        @{ Field = 'commands' }
        @{ Field = 'rules' }
        @{ Field = 'skills' }
        @{ Field = 'hooks' }
    ) {
        $script:MetadataKeys | Should -Not -Contain $Field
    }

    It 'Keeps component fields disjoint from the metadata key set' {
        foreach ($metadataKey in $script:ExpectedMetadataKeys) {
            $script:ExpectedFields | Should -Not -Contain $metadataKey
        }
    }
}

Describe 'Get-MarketplaceComponentSourceRoot' -Tag 'Unit' {
    BeforeAll {
        $script:SourceRoots = Get-MarketplaceComponentSourceRoot
    }

    It 'Describes exactly the five component fields in order' {
        $script:SourceRoots.Count | Should -Be 5
        ($script:SourceRoots.Keys -join '|') | Should -BeExactly 'agents|commands|rules|skills|hooks'
    }

    It 'Describes <Field> as <Kind> rooted at <SourceRoot>' -ForEach @(
        @{ Field = 'agents'; Kind = 'agent'; SourceRoot = '.github/agents'; SourceSuffix = '.agent.md'; PackageSuffix = '.md' }
        @{ Field = 'commands'; Kind = 'prompt'; SourceRoot = '.github/prompts'; SourceSuffix = '.prompt.md'; PackageSuffix = '.md' }
        @{ Field = 'rules'; Kind = 'instruction'; SourceRoot = '.github/instructions'; SourceSuffix = '.instructions.md'; PackageSuffix = '.instructions.md' }
        @{ Field = 'skills'; Kind = 'skill'; SourceRoot = '.github/skills'; SourceSuffix = ''; PackageSuffix = '' }
        @{ Field = 'hooks'; Kind = 'hook'; SourceRoot = '.github/hooks'; SourceSuffix = '.json'; PackageSuffix = '.json' }
    ) {
        $descriptor = $script:SourceRoots[$Field]
        $descriptor.Kind | Should -BeExactly $Kind
        $descriptor.SourceRoot | Should -BeExactly $SourceRoot
        $descriptor.SourceSuffix | Should -BeExactly $SourceSuffix
        $descriptor.PackageSuffix | Should -BeExactly $PackageSuffix
    }
}

Describe 'Get-PluginSubdirectory and Get-MarketplaceComponentField' -Tag 'Unit' {
    It 'Places kind <Kind> in package directory <Field>' -ForEach @(
        @{ Kind = 'agent'; Field = 'agents' }
        @{ Kind = 'prompt'; Field = 'commands' }
        @{ Kind = 'instruction'; Field = 'rules' }
        @{ Kind = 'skill'; Field = 'skills' }
        @{ Kind = 'hook'; Field = 'hooks' }
    ) {
        Get-PluginSubdirectory -Kind $Kind | Should -BeExactly $Field
        Get-MarketplaceComponentField -Kind $Kind | Should -BeExactly $Field
    }

    It 'Rejects an unsupported kind' {
        { Get-PluginSubdirectory -Kind 'workflow' } | Should -Throw -ExpectedMessage '*does not belong to the set*'
    }
}

Describe 'Get-PluginItemName' -Tag 'Unit' {
    It 'Renames <FileName> for kind <Kind> to <Expected>' -ForEach @(
        @{ Kind = 'agent'; FileName = 'code-review.agent.md'; Expected = 'code-review.md' }
        @{ Kind = 'prompt'; FileName = 'create-pull-request.prompt.md'; Expected = 'create-pull-request.md' }
        @{ Kind = 'instruction'; FileName = 'markdown.instructions.md'; Expected = 'markdown.instructions.md' }
        @{ Kind = 'skill'; FileName = 'rpi-plan'; Expected = 'rpi-plan' }
        @{ Kind = 'hook'; FileName = 'hooks.json'; Expected = 'hooks.json' }
    ) {
        Get-PluginItemName -FileName $FileName -Kind $Kind | Should -BeExactly $Expected
    }

    It 'Only strips the kind suffix at the end of the name' {
        Get-PluginItemName -FileName 'agent.md.agent.md' -Kind 'agent' | Should -BeExactly 'agent.md.md'
    }
}

Describe 'Get-PluginItemSubpath' -Tag 'Unit' {
    It 'Extracts <Expected> from <Path>' -ForEach @(
        @{ Kind = 'agent'; Path = '.github/agents/coding-standards/code-review.agent.md'; Expected = 'coding-standards' }
        @{ Kind = 'agent'; Path = '.github/agents/hve-core/subagents/rpi-researcher.agent.md'; Expected = 'hve-core/subagents' }
        @{ Kind = 'prompt'; Path = '.github/prompts/ado/create-pull-request.prompt.md'; Expected = 'ado' }
        @{ Kind = 'instruction'; Path = '.github/instructions/security/vex/rules.instructions.md'; Expected = 'security/vex' }
        @{ Kind = 'skill'; Path = '.github/skills/rpi/rpi-plan'; Expected = 'rpi' }
        @{ Kind = 'hook'; Path = '.github/hooks/hve-core/hooks.json'; Expected = 'hve-core' }
    ) {
        Get-PluginItemSubpath -Path $Path -Kind $Kind | Should -BeExactly $Expected
    }

    It 'Normalizes backslash separators before extracting the subpath' {
        Get-PluginItemSubpath -Path '.github\agents\coding-standards\code-review.agent.md' -Kind 'agent' |
            Should -BeExactly 'coding-standards'
    }

    It 'Returns an empty subpath for a root-level artifact' {
        Get-PluginItemSubpath -Path '.github/agents/code-review.agent.md' -Kind 'agent' | Should -BeExactly ''
    }

    It 'Returns an empty subpath when the path is outside the canonical root' {
        Get-PluginItemSubpath -Path 'docs/agents/coding-standards/code-review.agent.md' -Kind 'agent' | Should -BeExactly ''
    }
}

Describe 'Resolve-MarketplaceComponentPath' -Tag 'Unit' {
    Context 'when the path is acceptable' {
        It 'Returns the path unchanged and reports no error' {
            $resolved = Resolve-MarketplaceComponentPath -Path 'agents/coding-standards/code-review.md'
            $resolved.Path | Should -BeExactly 'agents/coding-standards/code-review.md'
            $resolved.Error | Should -BeExactly ''
        }

        It 'Trims surrounding whitespace' {
            $resolved = Resolve-MarketplaceComponentPath -Path '   agents/demo/first.md   '
            $resolved.Path | Should -BeExactly 'agents/demo/first.md'
            $resolved.Error | Should -BeExactly ''
        }

        It 'Trims a trailing slash from a directory component' {
            $resolved = Resolve-MarketplaceComponentPath -Path 'skills/rpi/rpi-plan/'
            $resolved.Path | Should -BeExactly 'skills/rpi/rpi-plan'
            $resolved.Error | Should -BeExactly ''
        }
    }

    Context 'when the path is rejected' {
        It 'Rejects <Description>' -ForEach @(
            @{ Description = 'an empty path'; Path = ''; Expected = 'component path must be a non-empty string' }
            @{ Description = 'a whitespace-only path'; Path = '    '; Expected = 'component path must be a non-empty string' }
            @{ Description = 'a backslash separator'; Path = 'agents\demo\first.md'; Expected = "component path 'agents\demo\first.md' must use forward slashes" }
            @{ Description = 'a rooted POSIX path'; Path = '/agents/demo/first.md'; Expected = "component path '/agents/demo/first.md' must be relative to the package root" }
            @{ Description = 'a Windows drive path'; Path = 'C:/agents/demo/first.md'; Expected = "component path 'C:/agents/demo/first.md' must be relative to the package root" }
            @{ Description = 'an empty path segment'; Path = 'agents//first.md'; Expected = "component path 'agents//first.md' must not contain empty path segments" }
            @{ Description = 'a parent traversal segment'; Path = 'agents/../../secrets.md'; Expected = "component path 'agents/../../secrets.md' must not escape the package root" }
            @{ Description = 'a current-directory segment'; Path = 'agents/./first.md'; Expected = "component path 'agents/./first.md' must not contain relative path segments" }
        ) {
            $resolved = Resolve-MarketplaceComponentPath -Path $Path
            $resolved.Error | Should -BeExactly $Expected
            $resolved.Path | Should -BeExactly ''
        }

        It 'Rejects an embedded control character' {
            $candidate = "agents/demo/$([char]9)first.md"
            $resolved = Resolve-MarketplaceComponentPath -Path $candidate
            $resolved.Error | Should -BeExactly "component path '$candidate' must not contain control characters"
            $resolved.Path | Should -BeExactly ''
        }

        It 'Rejects a null path' {
            $resolved = Resolve-MarketplaceComponentPath -Path $null
            $resolved.Error | Should -BeExactly 'component path must be a non-empty string'
        }
    }
}

Describe 'Marketplace source and package path round-trip' -Tag 'Unit' {
    It 'Projects <SourcePath> to <PackagePath> and back' -ForEach @(
        @{ Kind = 'agent'; Field = 'agents'; SourcePath = '.github/agents/rpi/rpi-agent.agent.md'; PackagePath = 'agents/rpi/rpi-agent.md' }
        @{ Kind = 'prompt'; Field = 'commands'; SourcePath = '.github/prompts/ado/create-pull-request.prompt.md'; PackagePath = 'commands/ado/create-pull-request.md' }
        @{ Kind = 'instruction'; Field = 'rules'; SourcePath = '.github/instructions/hve-core/markdown.instructions.md'; PackagePath = 'rules/hve-core/markdown.instructions.md' }
        @{ Kind = 'skill'; Field = 'skills'; SourcePath = '.github/skills/rpi/rpi-plan'; PackagePath = 'skills/rpi/rpi-plan' }
        @{ Kind = 'hook'; Field = 'hooks'; SourcePath = '.github/hooks/hve-core/hooks.json'; PackagePath = 'hooks/hve-core/hooks.json' }
    ) {
        Get-MarketplacePackagePath -SourcePath $SourcePath -Kind $Kind | Should -BeExactly $PackagePath

        $component = Resolve-MarketplaceComponentSource -PackagePath $PackagePath -Field $Field
        $component.SourcePath | Should -BeExactly $SourcePath
        $component.PackagePath | Should -BeExactly $PackagePath
        $component.Kind | Should -BeExactly $Kind
    }

    It 'Projects a root-level source without inventing a subdirectory' {
        Get-MarketplacePackagePath -SourcePath '.github/agents/code-review.agent.md' -Kind 'agent' |
            Should -BeExactly 'agents/code-review.md'
    }

    It 'Normalizes backslash separators in the source path' {
        Get-MarketplacePackagePath -SourcePath '.github\agents\rpi\rpi-agent.agent.md' -Kind 'agent' |
            Should -BeExactly 'agents/rpi/rpi-agent.md'
    }

    It 'Rejects a source path outside the canonical root' {
        { Get-MarketplacePackagePath -SourcePath 'docs/agents/rpi-agent.agent.md' -Kind 'agent' } |
            Should -Throw -ExpectedMessage "Source path 'docs/agents/rpi-agent.agent.md' is not under the canonical '.github/agents' root for kind 'agent'."
    }

    It 'Rejects a package path that does not start with its field directory' {
        { Resolve-MarketplaceComponentSource -PackagePath 'commands/demo/first.md' -Field 'agents' } |
            Should -Throw -ExpectedMessage "Component path 'commands/demo/first.md' must start with the 'agents/' package directory."
    }

    It 'Rejects a package path with the wrong extension' {
        { Resolve-MarketplaceComponentSource -PackagePath 'agents/demo/first.txt' -Field 'agents' } |
            Should -Throw -ExpectedMessage "Component path 'agents/demo/first.txt' must end with '.md'."
    }

    It 'Rejects a rules path that does not carry the instruction suffix' {
        { Resolve-MarketplaceComponentSource -PackagePath 'rules/demo/style.md' -Field 'rules' } |
            Should -Throw -ExpectedMessage "Component path 'rules/demo/style.md' must end with '.instructions.md'."
    }

    It 'Surfaces path validation failures with the field name' {
        { Resolve-MarketplaceComponentSource -PackagePath 'agents\demo\first.md' -Field 'agents' } |
            Should -Throw -ExpectedMessage "Component field 'agents': component path 'agents\demo\first.md' must use forward slashes"
    }
}

Describe 'Test-MarketplaceEntryContract component membership' -Tag 'Unit' {
    Context 'when the entry is fully valid' {
        BeforeAll {
            $script:ValidEntry = @{
                name     = 'demo'
                agents   = @('agents/demo/first.md', 'agents/demo/second.md')
                commands = @('commands/demo/run.md')
                rules    = @('rules/demo/style.instructions.md')
                skills   = @('skills/demo/toolkit')
                hooks    = 'hooks/demo/hooks.json'
                author   = @{ name = 'Contoso'; url = 'https://example.invalid/contoso' }
                'x-hve'  = @{
                    displayName       = 'Demo Package'
                    maturity          = 'preview'
                    componentMaturity = @{ 'agents/demo/second.md' = 'experimental' }
                    documentation     = 'docs/plugins/demo.md'
                    profiles          = @{ starter = @('agents/demo/first.md', 'skills/demo/toolkit') }
                }
            }
            $script:ValidErrors = @(Test-MarketplaceEntryContract -Entry $script:ValidEntry)
        }

        It 'Reports no contract errors' {
            $script:ValidErrors.Count | Should -Be 0
        }
    }

    Context 'when membership declarations are malformed' {
        It 'Rejects a null field value' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; agents = $null })
            $errors | Should -Contain "component field 'agents' must be a path string or an array of path strings"
        }

        It 'Rejects a non-string, non-collection field value' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; agents = 42 })
            $errors | Should -Contain "component field 'agents' must be a path string or an array of path strings"
        }

        It 'Rejects an empty array' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; skills = @() })
            $errors | Should -Contain "component field 'skills' must declare at least one path"
        }

        It 'Rejects a non-string element inside an array' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; agents = @('agents/demo/first.md', 42) })
            $errors | Should -Contain "component field 'agents' must contain only path strings"
        }

        It 'Rejects an invalid path and names the offending field' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; commands = @('commands/../escape.md') })
            $errors | Should -Contain "component field 'commands': component path 'commands/../escape.md' must not escape the package root"
        }

        It 'Rejects a duplicate path within one field' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; agents = @('agents/demo/first.md', 'agents/demo/first.md') })
            $errors | Should -Contain "component field 'agents' declares duplicate path 'agents/demo/first.md'"
        }

        It 'Treats paths that normalize to the same value as duplicates' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; skills = @('skills/demo/toolkit', 'skills/demo/toolkit/') })
            $errors | Should -Contain "component field 'skills' declares duplicate path 'skills/demo/toolkit'"
        }

        It 'Rejects the same path declared across two fields' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{
                    name     = 'demo'
                    agents   = @('agents/demo/first.md')
                    commands = @('agents/demo/first.md')
                })
            $errors | Should -Contain "component path 'agents/demo/first.md' is declared in both 'agents' and 'commands'"
        }

        It 'Accepts a single hooks path string' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; hooks = 'hooks/demo/hooks.json' })
            $errors.Count | Should -Be 0
        }

        It 'Rejects a hooks array' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; hooks = @('hooks/demo/hooks.json') })
            $errors | Should -Contain "component field 'hooks' must be a single path string"
        }

        It 'Accepts an entry that declares no component membership' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo' })
            $errors.Count | Should -Be 0
        }
    }
}

Describe 'Test-MarketplaceEntryContract membership hygiene' -Tag 'Unit' {
    Context 'when a root-level repository artifact is declared' {
        It 'Rejects root-level <PackagePath> in field <Field>' -ForEach @(
            @{ Field = 'agents'; PackagePath = 'agents/first.md' }
            @{ Field = 'commands'; PackagePath = 'commands/run.md' }
            @{ Field = 'rules'; PackagePath = 'rules/style.instructions.md' }
            @{ Field = 'skills'; PackagePath = 'skills/toolkit' }
        ) {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; $Field = @($PackagePath) })
            $errors | Should -Contain "component path '$PackagePath' is a root-level repository artifact and must not be declared"
        }

        It 'Rejects a root-level hooks manifest' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; hooks = 'hooks/hooks.json' })
            $errors | Should -Contain "component path 'hooks/hooks.json' is a root-level repository artifact and must not be declared"
        }

        It 'Accepts a namespaced artifact' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; agents = @('agents/demo/first.md') })
            $errors.Count | Should -Be 0
        }
    }

    Context 'when an experimental namespace is declared' {
        It 'Rejects <PackagePath> when no componentMaturity is declared' -ForEach @(
            @{ Field = 'agents'; PackagePath = 'agents/experimental/first.md' }
            @{ Field = 'commands'; PackagePath = 'commands/experimental/run.md' }
            @{ Field = 'rules'; PackagePath = 'rules/experimental/style.instructions.md' }
            @{ Field = 'skills'; PackagePath = 'skills/experimental/toolkit' }
        ) {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; $Field = @($PackagePath) })
            $errors | Should -Contain "component path '$PackagePath' is under an experimental namespace and must declare a non-stable x-hve.componentMaturity"
        }

        It 'Rejects an explicit stable label under an experimental namespace' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{
                    name    = 'demo'
                    agents  = @('agents/experimental/first.md')
                    'x-hve' = @{ componentMaturity = @{ 'agents/experimental/first.md' = 'stable' } }
                })
            $errors | Should -Contain "component path 'agents/experimental/first.md' is under an experimental namespace and must declare a non-stable x-hve.componentMaturity"
        }

        It 'Accepts non-stable label <Maturity> under an experimental namespace' -ForEach @(
            @{ Maturity = 'preview' }
            @{ Maturity = 'experimental' }
            @{ Maturity = 'deprecated' }
            @{ Maturity = 'removed' }
        ) {
            $errors = @(Test-MarketplaceEntryContract -Entry @{
                    name    = 'demo'
                    agents  = @('agents/experimental/first.md')
                    'x-hve' = @{ componentMaturity = @{ 'agents/experimental/first.md' = $Maturity } }
                })
            $errors.Count | Should -Be 0
        }

        It 'Leaves components outside an experimental namespace on the stable default' {
            $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; agents = @('agents/demo/experimental.md') })
            $errors.Count | Should -Be 0
        }
    }
}

Describe 'Test-MarketplaceEntryContract x-hve overlay' -Tag 'Unit' {
    It 'Rejects a non-object overlay' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = 'preview' })
        $errors | Should -Contain 'x-hve must be an object'
    }

    It 'Rejects an unsupported overlay key' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ channel = 'beta' } })
        $errors | Should -Contain "x-hve contains unsupported key 'channel'"
    }

    It 'Accepts every key in the closed metadata set' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                'x-hve' = @{
                    displayName       = 'Demo'
                    maturity          = 'stable'
                    componentMaturity = @{ 'agents/demo/first.md' = 'preview' }
                    documentation     = 'docs/plugins/demo.md'
                    profiles          = @{ starter = @('agents/demo/first.md') }
                }
            })
        $errors.Count | Should -Be 0
    }

    It 'Rejects an empty display name' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ displayName = '' } })
        $errors | Should -Contain 'x-hve.displayName must be a non-empty string'
    }

    It 'Accepts package maturity <Value>' -ForEach @(
        @{ Value = 'stable' }
        @{ Value = 'preview' }
        @{ Value = 'experimental' }
        @{ Value = 'deprecated' }
        @{ Value = 'removed' }
    ) {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ maturity = $Value } })
        $errors.Count | Should -Be 0
    }

    It 'Rejects package maturity outside the vocabulary' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ maturity = 'beta' } })
        $errors | Should -Contain "x-hve.maturity 'beta' must be one of: stable, preview, experimental, deprecated, removed"
    }

    It 'Rejects a non-object componentMaturity' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ componentMaturity = 'preview' } })
        $errors | Should -Contain 'x-hve.componentMaturity must be an object keyed by component path'
    }

    It 'Rejects a componentMaturity key that is not normalized' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                'x-hve' = @{ componentMaturity = @{ 'skills/demo/toolkit/' = 'preview' } }
            })
        $errors | Should -Contain "x-hve.componentMaturity key 'skills/demo/toolkit/' must be a normalized component path"
    }

    It 'Rejects a componentMaturity key that fails path validation' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                'x-hve' = @{ componentMaturity = @{ 'agents\demo\first.md' = 'preview' } }
            })
        $errors | Should -Contain "x-hve.componentMaturity: component path 'agents\demo\first.md' must use forward slashes"
    }

    It 'Rejects a componentMaturity value outside the vocabulary' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                'x-hve' = @{ componentMaturity = @{ 'agents/demo/first.md' = 'beta' } }
            })
        $errors | Should -Contain "x-hve.componentMaturity['agents/demo/first.md'] value 'beta' must be one of: stable, preview, experimental, deprecated, removed"
    }

    It 'Accepts a removed componentMaturity tombstone without membership' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                'x-hve' = @{ componentMaturity = @{ 'skills/demo/retired' = 'removed' } }
            })
        $errors.Count | Should -Be 0
    }

    It 'Rejects a non-string documentation value' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ documentation = 42 } })
        $errors | Should -Contain 'x-hve.documentation must be a repository-relative path string'
    }

    It 'Rejects a documentation path that is not normalized' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ documentation = 'docs/plugins/demo.md/' } })
        $errors | Should -Contain "x-hve.documentation 'docs/plugins/demo.md/' must be a normalized repository-relative path"
    }

    It 'Rejects a documentation path that escapes the repository root' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ documentation = '../secrets.md' } })
        $errors | Should -Contain "x-hve.documentation: component path '../secrets.md' must not escape the package root"
    }

    It 'Rejects a non-object profiles overlay' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{ name = 'demo'; 'x-hve' = @{ profiles = 'starter' } })
        $errors | Should -Contain 'x-hve.profiles must be an object keyed by profile name'
    }

    It 'Rejects a profile name outside the identifier vocabulary' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                'x-hve' = @{ profiles = @{ 'Starter Profile' = @('agents/demo/first.md') } }
            })
        $errors | Should -Contain "x-hve.profiles name 'Starter Profile' must contain only lowercase letters, digits, and hyphens"
    }

    It 'Rejects a profile that is not an array of paths' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                'x-hve' = @{ profiles = @{ starter = 'agents/demo/first.md' } }
            })
        $errors | Should -Contain "x-hve.profiles['starter'] must be an array of component paths"
    }

    It 'Rejects an empty profile' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                'x-hve' = @{ profiles = @{ starter = @() } }
            })
        $errors | Should -Contain "x-hve.profiles['starter'] must declare at least one component path"
    }

    It 'Rejects a duplicate profile member' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                'x-hve' = @{ profiles = @{ starter = @('agents/demo/first.md', 'agents/demo/first.md') } }
            })
        $errors | Should -Contain "x-hve.profiles['starter'] declares duplicate path 'agents/demo/first.md'"
    }

    It 'Rejects a profile member that fails path validation' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                'x-hve' = @{ profiles = @{ starter = @('agents/../escape.md') } }
            })
        $errors | Should -Contain "x-hve.profiles['starter']: component path 'agents/../escape.md' must not escape the package root"
    }

    It 'Rejects a profile member that is not declared component membership' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                'x-hve' = @{ profiles = @{ starter = @('agents/demo/absent.md') } }
            })
        $errors | Should -Contain "x-hve.profiles['starter'] references 'agents/demo/absent.md', which is not declared component membership"
    }

    It 'Rejects a profile member from a non-installable field' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md')
                hooks   = 'hooks/demo/hooks.json'
                'x-hve' = @{ profiles = @{ starter = @('agents/demo/first.md', 'hooks/demo/hooks.json') } }
            })
        $errors | Should -Contain "x-hve.profiles['starter'] references 'hooks/demo/hooks.json' from non-installable field 'hooks'; profiles support only: agents, commands, rules, skills"
    }

    It 'Accepts a profile that selects a subset of declared membership' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md', 'agents/demo/second.md')
                skills  = @('skills/demo/toolkit')
                'x-hve' = @{ profiles = @{ starter = @('agents/demo/first.md', 'skills/demo/toolkit') } }
            })
        $errors.Count | Should -Be 0
    }

    It 'Reports membership errors alongside overlay errors' {
        $errors = @(Test-MarketplaceEntryContract -Entry @{
                name    = 'demo'
                agents  = @('agents/demo/first.md', 'agents/demo/first.md')
                'x-hve' = @{ displayName = '' }
            })
        $errors.Count | Should -Be 2
        $errors | Should -Contain "component field 'agents' declares duplicate path 'agents/demo/first.md'"
        $errors | Should -Contain 'x-hve.displayName must be a non-empty string'
    }
}

AfterAll {
    Remove-Module MarketplaceHelpers -Force -ErrorAction SilentlyContinue
}
