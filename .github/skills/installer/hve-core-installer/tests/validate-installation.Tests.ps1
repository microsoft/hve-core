#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'validate-installation' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/validate-installation.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-validate-$([guid]::NewGuid().ToString('N'))"
    }

    BeforeEach {
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        Push-Location $script:testRoot
    }

    AfterEach {
        Pop-Location
    }

    AfterAll {
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Parameter validation' {
        It 'Has a mandatory BasePath parameter' {
            $param = (Get-Command $script:scriptPath).Parameters['BasePath']
            $param | Should -Not -BeNullOrEmpty
            $attr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }

        It 'Has a mandatory Method parameter' {
            $param = (Get-Command $script:scriptPath).Parameters['Method']
            $param | Should -Not -BeNullOrEmpty
            $attr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }
    }

    Context 'Directory validation' {
        It 'Passes when all required directories exist' {
            $installDir = Join-Path $script:testRoot 'install'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            $output = & $script:scriptPath -BasePath $installDir -Method 1 6>&1 | Out-String

            $output | Should -Match 'Installation validated successfully'
        }

        It 'Reports missing directories' {
            $installDir = Join-Path $script:testRoot 'empty-install'
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null

            $output = & $script:scriptPath -BasePath $installDir -Method 1 6>&1 | Out-String

            $output | Should -Match 'Missing'
        }

        It 'Checks agents directory' {
            $installDir = Join-Path $script:testRoot 'partial'
            New-Item -ItemType Directory -Path (Join-Path $installDir '.github/prompts') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $installDir '.github/instructions') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $installDir '.github/skills') -Force | Out-Null

            $output = & $script:scriptPath -BasePath $installDir -Method 1 6>&1 | Out-String

            $output | Should -Match '(?s)Missing.*agents'
        }

        It 'Checks skills directory' {
            $installDir = Join-Path $script:testRoot 'no-skills'
            New-Item -ItemType Directory -Path (Join-Path $installDir '.github/agents') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $installDir '.github/prompts') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $installDir '.github/instructions') -Force | Out-Null

            $output = & $script:scriptPath -BasePath $installDir -Method 1 6>&1 | Out-String

            $output | Should -Match '(?s)Missing.*skills'
        }
    }

    Context 'Experimental subdirectories' {
        It 'Passes validation when experimental directories are absent' {
            $installDir = Join-Path $script:testRoot 'no-experimental'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            $output = & $script:scriptPath -BasePath $installDir -Method 1 6>&1 | Out-String

            $LASTEXITCODE | Should -Not -Be 1
            $output | Should -Match 'Installation validated successfully'
            $output | Should -Not -Match 'Missing.*experimental'
        }

        It 'Reports optional experimental directories when present' {
            $installDir = Join-Path $script:testRoot 'with-experimental'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills',
                               '.github/skills/experimental', '.github/agents/experimental')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            $output = & $script:scriptPath -BasePath $installDir -Method 1 6>&1 | Out-String

            $output | Should -Match '(?s)Found optional.*skills/experimental'
            $output | Should -Match '(?s)Found optional.*agents/experimental'
            $output | Should -Match 'Installation validated successfully'
        }
    }

    Context 'Method 5: Multi-root workspace validation' {
        It 'Validates multi-root workspace configuration' {
            $installDir = Join-Path $script:testRoot 'method5'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            $workspace = @{
                folders = @(
                    @{ path = '.' }
                    @{ path = 'lib/hve-core' }
                )
            }
            $workspace | ConvertTo-Json -Depth 5 | Set-Content 'hve-core.code-workspace'

            $output = & $script:scriptPath -BasePath $installDir -Method 5 6>&1 | Out-String

            $output | Should -Match 'Multi-root configured'
        }

        It 'Fails multi-root check when workspace has fewer than 2 folders' {
            $installDir = Join-Path $script:testRoot 'method5-bad'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            $workspace = @{
                folders = @(
                    @{ path = '.' }
                )
            }
            $workspace | ConvertTo-Json -Depth 5 | Set-Content 'hve-core.code-workspace'

            $output = & $script:scriptPath -BasePath $installDir -Method 5 6>&1 | Out-String

            $output | Should -Match 'Multi-root not configured'
        }
    }

    Context 'Method 6: Submodule validation' {
        It 'Validates submodule entry in .gitmodules' {
            $installDir = Join-Path $script:testRoot 'method6'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            @'
[submodule "lib/hve-core"]
    path = lib/hve-core
    url = https://github.com/microsoft/hve-core.git
'@ | Set-Content '.gitmodules'

            $output = & $script:scriptPath -BasePath $installDir -Method 6 6>&1 | Out-String

            $output | Should -Not -Match 'Submodule not in .gitmodules'
        }

        It 'Fails when .gitmodules missing submodule entry' {
            $installDir = Join-Path $script:testRoot 'method6-bad'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            Set-Content '.gitmodules' -Value '[submodule "other"]'

            $output = & $script:scriptPath -BasePath $installDir -Method 6 6>&1 | Out-String

            $output | Should -Match 'Submodule not in .gitmodules'
        }

        It 'Fails when .gitmodules does not exist' {
            $installDir = Join-Path $script:testRoot 'method6-nomod'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            # Ensure .gitmodules does not exist
            Remove-Item '.gitmodules' -ErrorAction SilentlyContinue

            $output = & $script:scriptPath -BasePath $installDir -Method 6 6>&1 | Out-String

            $output | Should -Match 'Submodule not in .gitmodules'
        }
    }

    Context 'Standard methods (1-4)' {
        It 'Passes validation for method 1 with all directories' {
            $installDir = Join-Path $script:testRoot 'method1'
            foreach ($dir in @('.github/agents', '.github/prompts', '.github/instructions', '.github/skills')) {
                New-Item -ItemType Directory -Path (Join-Path $installDir $dir) -Force | Out-Null
            }

            $output = & $script:scriptPath -BasePath $installDir -Method 1 6>&1 | Out-String

            $output | Should -Match 'Installation validated successfully'
        }
    }
}