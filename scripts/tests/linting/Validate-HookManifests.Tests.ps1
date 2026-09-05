#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../linting/Validate-HookManifests.ps1
}

Describe 'Test-HookManifest - valid manifests' {
    It 'Returns no errors for a valid CLI-form manifest' {
        $manifest = @{
            version     = 1
            description = 'Telemetry collector'
            hooks       = @{
                sessionStart = @(
                    @{ type = 'command'; bash = './collect.sh'; powershell = './Collect.ps1'; timeoutSec = 10 }
                )
            }
        }

        Test-HookManifest -Manifest $manifest | Should -BeNullOrEmpty
    }

    It 'Returns no errors for a valid VS Code-native command manifest' {
        $manifest = @{
            version = 1
            hooks   = @{
                stop = @(
                    @{ type = 'command'; command = './done.sh'; timeout = 5 }
                )
            }
        }

        Test-HookManifest -Manifest $manifest | Should -BeNullOrEmpty
    }

    It 'Accepts all allowed lifecycle events' {
        $hooks = @{}
        foreach ($eventName in $script:HookAllowedEvents) {
            $hooks[$eventName] = @(@{ type = 'command'; bash = 'a' })
        }
        $manifest = @{
            version = 1
            hooks   = $hooks
        }

        Test-HookManifest -Manifest $manifest | Should -BeNullOrEmpty
    }
}

Describe 'Hook manifest schema synchronization' {
    It 'Keeps the schema event enum in sync with $script:HookAllowedEvents' {
        $schemaPath = Join-Path $PSScriptRoot '../../linting/schemas/hook-manifest.schema.json'
        $schema = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json -AsHashtable
        $schemaEvents = @($schema['properties']['hooks']['propertyNames']['enum'])

        $schemaEvents | Should -Be @($script:HookAllowedEvents)
    }
}

Describe 'Test-HookManifest - structural errors' {
    It 'Reports missing version' {
        $manifest = @{ hooks = @{ stop = @(@{ type = 'command'; bash = 'a' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "missing required field 'version'"
    }

    It 'Reports unsupported version' {
        $manifest = @{ version = 2; hooks = @{ stop = @(@{ type = 'command'; bash = 'a' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "field 'version' must be 1"
    }

    It 'Reports missing hooks' {
        $manifest = @{ version = 1 }
        Test-HookManifest -Manifest $manifest | Should -Contain "missing required field 'hooks'"
    }

    It 'Reports unknown top-level field' {
        $manifest = @{ version = 1; extra = 'nope'; hooks = @{ stop = @(@{ type = 'command'; bash = 'a' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "unknown top-level field 'extra'"
    }

    It 'Reports empty hooks object' {
        $manifest = @{ version = 1; hooks = @{} }
        Test-HookManifest -Manifest $manifest | Should -Contain "field 'hooks' must declare at least one event"
    }
}

Describe 'Test-HookManifest - event name enforcement' {
    It 'Rejects the PascalCase form and points to the CLI lowercase form' {
        $manifest = @{ version = 1; hooks = @{ SessionStart = @(@{ type = 'command'; bash = 'a' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "event 'SessionStart' must use the Copilot CLI lowercase form 'sessionStart'"
    }

    It 'Rejects an unknown event name' {
        $manifest = @{ version = 1; hooks = @{ onSomething = @(@{ type = 'command'; bash = 'a' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "unknown event 'onSomething'"
    }
}

Describe 'Test-HookManifest - command entry errors' {
    It 'Reports a non-array event value' {
        $manifest = @{ version = 1; hooks = @{ stop = @{ type = 'command'; bash = 'a' } } }
        Test-HookManifest -Manifest $manifest | Should -Contain "event 'stop' must be an array of command entries"
    }

    It 'Reports an empty event array' {
        $manifest = @{ version = 1; hooks = @{ stop = @() } }
        Test-HookManifest -Manifest $manifest | Should -Contain "event 'stop' must declare at least one command entry"
    }

    It 'Reports a missing type property' {
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ bash = 'a' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "event 'stop' entry [0] missing required property 'type'"
    }

    It 'Reports a non-command type' {
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'script'; bash = 'a' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "event 'stop' entry [0] property 'type' must be 'command'"
    }

    It 'Reports an unknown command property' {
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'command'; bash = 'a'; nope = 'x' }) } }
        Test-HookManifest -Manifest $manifest | Should -Contain "event 'stop' entry [0] has unknown property 'nope'"
    }

    It 'Reports an entry with no command property' {
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'command' }) } }
        $errors = Test-HookManifest -Manifest $manifest
        ($errors -join "`n") | Should -BeLike '*must define at least one command property*'
    }
}

Describe 'Test-HookManifest - Windows PowerShell 5.1 compatibility' {
    It 'Rejects a ternary operator in a powershell command' {
        $command = "& (Join-Path ([string]::IsNullOrWhiteSpace(`$env:CLAUDE_PLUGIN_ROOT) ? '.' : `$env:CLAUDE_PLUGIN_ROOT) 'a.ps1')"
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'command'; powershell = $command }) } }

        ((Test-HookManifest -Manifest $manifest) -join "`n") | Should -BeLike "*property 'powershell' uses PowerShell 7-only syntax (ternary operator '? :')*"
    }

    It 'Accepts the equivalent if-expression form' {
        $command = "& (Join-Path `$(if ([string]::IsNullOrWhiteSpace(`$env:CLAUDE_PLUGIN_ROOT)) { '.' } else { `$env:CLAUDE_PLUGIN_ROOT }) 'a.ps1')"
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'command'; powershell = $command }) } }

        Test-HookManifest -Manifest $manifest | Should -BeNullOrEmpty
    }

    It 'Does not flag PowerShell 7-only operators that appear inside string literals' {
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'command'; powershell = "Write-Output 'a ? b : c && d ?? e'" }) } }

        Test-HookManifest -Manifest $manifest | Should -BeNullOrEmpty
    }

    It 'Does not inspect the bash command for PowerShell syntax' {
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'command'; bash = 'a && b || c' }) } }

        Test-HookManifest -Manifest $manifest | Should -BeNullOrEmpty
    }

    It 'Reports each PowerShell 7-only construct' -ForEach @(
        @{ Command = '$a ?? $b'; Expected = "null-coalescing operator '??'" }
        @{ Command = '$a ??= $b'; Expected = "null-coalescing assignment '??='" }
        @{ Command = '${a}?.Length'; Expected = "null-conditional member access '?.'" }
        @{ Command = '${a}?[0]'; Expected = "null-conditional index '?['" }
        @{ Command = 'a.exe && b.exe'; Expected = "pipeline chain operator '&&'" }
        @{ Command = 'a.exe || b.exe'; Expected = "pipeline chain operator '||'" }
    ) {
        $manifest = @{ version = 1; hooks = @{ stop = @(@{ type = 'command'; powershell = $Command }) } }

        ((Test-HookManifest -Manifest $manifest) -join "`n").Contains($Expected) | Should -BeTrue
    }
}

Describe 'Invoke-HookManifestValidation' {
    It 'Succeeds when no hooks directory exists' {
        $repoRoot = Join-Path $TestDrive 'repo-no-hooks'
        New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

        $result = Invoke-HookManifestValidation -RepoRoot $repoRoot -OutputPath ([System.IO.Path]::Combine($repoRoot, 'logs', 'out.json'))
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Writes the schema contract path into the report' {
        $repoRoot = Join-Path $TestDrive 'repo-schema-ref'
        New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
        $outPath = [System.IO.Path]::Combine($repoRoot, 'logs', 'out.json')

        Invoke-HookManifestValidation -RepoRoot $repoRoot -OutputPath $outPath | Out-Null

        $report = Get-Content -Path $outPath -Raw | ConvertFrom-Json
        $report.Schema | Should -Be 'scripts/linting/schemas/hook-manifest.schema.json'
    }

    It 'Validates a collection-scoped manifest and ignores deeper files' {
        $repoRoot = Join-Path $TestDrive 'repo-hooks'
        $collectionDir = Join-Path $repoRoot '.github/hooks/shared'
        $implDir = Join-Path $collectionDir 'telemetry'
        New-Item -ItemType Directory -Path $implDir -Force | Out-Null

        $manifest = @{
            version = 1
            hooks   = @{ sessionStart = @(@{ type = 'command'; bash = './a.sh' }) }
        }
        Set-Content -Path (Join-Path $collectionDir 'telemetry.json') -Value ($manifest | ConvertTo-Json -Depth 10)
        # A deeper JSON file (implementation config) must not be treated as a manifest.
        Set-Content -Path (Join-Path $implDir 'config.json') -Value '{ "not": "a manifest" }'

        $result = Invoke-HookManifestValidation -RepoRoot $repoRoot -OutputPath ([System.IO.Path]::Combine($repoRoot, 'logs', 'out.json'))
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Fails on an invalid collection-scoped manifest' {
        $repoRoot = Join-Path $TestDrive 'repo-bad-hooks'
        $collectionDir = Join-Path $repoRoot '.github/hooks/shared'
        New-Item -ItemType Directory -Path $collectionDir -Force | Out-Null
        Set-Content -Path (Join-Path $collectionDir 'telemetry.json') -Value '{ "hooks": { "SessionStart": [ { "type": "command", "bash": "a" } ] } }'

        $result = Invoke-HookManifestValidation -RepoRoot $repoRoot -OutputPath ([System.IO.Path]::Combine($repoRoot, 'logs', 'out.json'))
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterThan 0
    }

    It 'Rejects a manifest that declares an event in both CLI-lowercase and PascalCase form' {
        $repoRoot = Join-Path $TestDrive 'repo-both-forms'
        $collectionDir = Join-Path $repoRoot '.github/hooks/shared'
        New-Item -ItemType Directory -Path $collectionDir -Force | Out-Null
        Set-Content -Path (Join-Path $collectionDir 'telemetry.json') -Value '{ "version": 1, "hooks": { "stop": [ { "type": "command", "bash": "a" } ], "Stop": [ { "type": "command", "bash": "b" } ] } }'

        $result = Invoke-HookManifestValidation -RepoRoot $repoRoot -OutputPath ([System.IO.Path]::Combine($repoRoot, 'logs', 'out.json'))
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterThan 0
    }
}
