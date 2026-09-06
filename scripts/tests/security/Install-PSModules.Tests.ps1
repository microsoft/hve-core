#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Install-PSModules.ps1')

    Mock Write-Host {}
    Mock Start-Sleep {}

    $script:FixtureConfig = @'
{
  "modules": {
    "FakeModuleA": { "version": "1.0.0", "purpose": "Test module A" },
    "FakeModuleB": { "version": "2.5.0", "purpose": "Test module B" }
  }
}
'@
}

Describe 'Resolve-ConfigPath' -Tag 'Unit' {
    Context 'when explicit parameter is provided' {
        It 'Returns the explicit path' {
            $result = Resolve-ConfigPath -Explicit '/some/explicit/path.json'
            $result | Should -Be '/some/explicit/path.json'
        }
    }

    Context 'when env var is set and no explicit param' {
        BeforeEach {
            $script:OrigEnv = $env:PS_MODULE_CONFIG_PATH
            $env:PS_MODULE_CONFIG_PATH = '/env/var/path.json'
        }
        AfterEach {
            $env:PS_MODULE_CONFIG_PATH = $script:OrigEnv
        }

        It 'Returns the env var value' {
            $result = Resolve-ConfigPath -Explicit ''
            $result | Should -Be '/env/var/path.json'
        }
    }

    Context 'when neither param nor env var is set' {
        BeforeEach {
            $script:OrigEnv = $env:PS_MODULE_CONFIG_PATH
            $env:PS_MODULE_CONFIG_PATH = $null
        }
        AfterEach {
            $env:PS_MODULE_CONFIG_PATH = $script:OrigEnv
        }

        It 'Returns a path ending in ps-module-versions.json' {
            $result = Resolve-ConfigPath -Explicit ''
            $result | Should -BeLike '*ps-module-versions.json'
        }
    }

    Context 'when git rev-parse cannot determine the repository root' {
        BeforeEach {
            $script:OrigEnv = $env:PS_MODULE_CONFIG_PATH
            $env:PS_MODULE_CONFIG_PATH = $null
            # Simulates git being unavailable, a non-clone checkout, or a linked
            # worktree whose main .git is unreachable, forcing the path fallback.
            Mock git { }
        }
        AfterEach {
            $env:PS_MODULE_CONFIG_PATH = $script:OrigEnv
        }

        It 'Does not duplicate the scripts path segment' {
            $result = Resolve-ConfigPath -Explicit ''
            $result | Should -Not -Match 'scripts[\\/]scripts'
        }

        It 'Resolves to the existing manifest at the repository root' {
            $result = Resolve-ConfigPath -Explicit ''
            Test-Path -LiteralPath $result | Should -BeTrue
        }
    }

    Context 'when explicit param takes precedence over env var' {
        BeforeEach {
            $script:OrigEnv = $env:PS_MODULE_CONFIG_PATH
            $env:PS_MODULE_CONFIG_PATH = '/env/path.json'
        }
        AfterEach {
            $env:PS_MODULE_CONFIG_PATH = $script:OrigEnv
        }

        It 'Returns the explicit path, not the env var' {
            $result = Resolve-ConfigPath -Explicit '/explicit/wins.json'
            $result | Should -Be '/explicit/wins.json'
        }
    }
}

Describe 'Resolve-Scope' -Tag 'Unit' {
    Context 'when explicit parameter is provided' {
        It 'Returns the explicit scope' {
            $result = Resolve-Scope -Explicit 'AllUsers'
            $result | Should -Be 'AllUsers'
        }
    }

    Context 'when env var is set and no explicit param' {
        BeforeEach {
            $script:OrigEnv = $env:PS_MODULE_SCOPE
            $env:PS_MODULE_SCOPE = 'AllUsers'
        }
        AfterEach {
            $env:PS_MODULE_SCOPE = $script:OrigEnv
        }

        It 'Returns the env var value' {
            $result = Resolve-Scope -Explicit ''
            $result | Should -Be 'AllUsers'
        }
    }

    Context 'when neither param nor env var is set' {
        BeforeEach {
            $script:OrigEnv = $env:PS_MODULE_SCOPE
            $env:PS_MODULE_SCOPE = $null
        }
        AfterEach {
            $env:PS_MODULE_SCOPE = $script:OrigEnv
        }

        It 'Defaults to CurrentUser' {
            $result = Resolve-Scope -Explicit ''
            $result | Should -Be 'CurrentUser'
        }
    }
}

Describe 'Test-ModulePresent' -Tag 'Unit' {
    Context 'when module is installed at the required version' {
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{ Version = [version]'3.0.0' }
            }
        }

        It 'Returns true' {
            Test-ModulePresent -Name 'SomeModule' -Version '3.0.0' | Should -BeTrue
        }
    }

    Context 'when module is installed at a different version' {
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{ Version = [version]'2.0.0' }
            }
        }

        It 'Returns false' {
            Test-ModulePresent -Name 'SomeModule' -Version '3.0.0' | Should -BeFalse
        }
    }

    Context 'when module is not installed' {
        BeforeAll {
            Mock Get-Module { $null }
        }

        It 'Returns false' {
            Test-ModulePresent -Name 'MissingModule' -Version '1.0.0' | Should -BeFalse
        }
    }
}

Describe 'Register-DefaultPSGallery' -Tag 'Unit' {
    It 'Uses only the PowerShellGet default parameter set' {
        $command = (Get-Command Register-DefaultPSGallery).ScriptBlock.Ast.Find({
                param($Ast)
                $Ast -is [System.Management.Automation.Language.CommandAst] -and
                $Ast.GetCommandName() -eq 'Register-PSRepository'
            }, $true)

        $command.Extent.Text | Should -BeExactly 'Register-PSRepository -Default -ErrorAction Stop'
    }

}

Describe 'Initialize-Repository' -Tag 'Unit' {
    Context 'when the repository is already registered' {
        BeforeAll {
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
        }

        It 'Does not register the repository again' {
            $result = Initialize-Repository -Name 'PSGallery'

            $result | Should -BeExactly 'PSGallery'
            Should -Invoke Register-PSRepository -Times 0 -Exactly
        }
    }

    Context 'when PSGallery is missing' {
        BeforeAll {
            Mock Get-PSRepository { $null }
            Mock Register-DefaultPSGallery { $true }
        }

        It 'Registers PSGallery with the default parameter set' {
            $result = Initialize-Repository -Name 'PSGallery'

            $result | Should -BeExactly 'PSGallery'
            Should -Invoke Register-DefaultPSGallery -Times 1 -Exactly
        }
    }

    Context 'when default PSGallery registration remains unavailable' {
        BeforeAll {
            Mock Get-PSRepository { $null }
            Mock Register-DefaultPSGallery { $false }
            Mock Register-PSRepository {}
        }

        It 'Returns a temporary repository at the canonical endpoint' {
            $result = Initialize-Repository -Name 'PSGallery'

            $result | Should -BeLike "HVEPSGallery-$PID-*"
            Should -Invoke Register-PSRepository -Times 1 -Exactly -ParameterFilter {
                $Name -like "HVEPSGallery-$PID-*" -and
                $SourceLocation -eq 'https://www.powershellgallery.com/api/v2' -and
                $InstallationPolicy -eq 'Untrusted'
            }
        }
    }

    Context 'when a non-PSGallery repository is missing' {
        BeforeAll {
            Mock Get-PSRepository { $null }
            Mock Register-PSRepository {}
        }

        It 'Does not register an alternate repository automatically' {
            $result = Initialize-Repository -Name 'CustomRepo'

            $result | Should -BeExactly 'CustomRepo'
            Should -Invoke Register-PSRepository -Times 0 -Exactly
        }
    }
}

Describe 'Install-SingleModule' -Tag 'Unit' {
    Context 'when Install-Module succeeds on first attempt' {
        BeforeAll {
            Mock Install-Module {}
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
        }

        It 'Calls Install-Module exactly once' {
            Install-SingleModule -Name 'TestMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 10

            Should -Invoke Install-Module -Times 1 -Exactly
        }

        It 'Does not call Start-Sleep' {
            Install-SingleModule -Name 'TestMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 10

            Should -Invoke Start-Sleep -Times 0 -Exactly
        }
    }

    Context 'when default registration requires a temporary repository' {
        BeforeAll {
            Mock Initialize-Repository { "HVEPSGallery-$PID-test" }
            Mock Install-Module {}
            Mock Unregister-PSRepository {}
        }

        It 'Installs from the temporary repository and removes it' {
            Install-SingleModule -Name 'TestMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 10

            Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter {
                $Repository -eq "HVEPSGallery-$PID-test"
            }
            Should -Invoke Unregister-PSRepository -Times 1 -Exactly -ParameterFilter {
                $Name -eq "HVEPSGallery-$PID-test"
            }
        }
    }

    Context 'when installation from a temporary repository fails' {
        BeforeAll {
            Mock Initialize-Repository { "HVEPSGallery-$PID-test" }
            Mock Install-Module { throw 'installation failed' }
            Mock Unregister-PSRepository {}
        }

        It 'Removes the temporary repository before propagating the failure' {
            { Install-SingleModule -Name 'TestMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 1 -BaseDelaySeconds 1 } |
                Should -Throw '*Failed to install TestMod*'

            Should -Invoke Unregister-PSRepository -Times 1 -Exactly -ParameterFilter {
                $Name -eq "HVEPSGallery-$PID-test"
            }
        }
    }

    Context 'when temporary repository cleanup also fails' {
        BeforeAll {
            Mock Initialize-Repository { "HVEPSGallery-$PID-test" }
            Mock Install-Module { throw 'installation failed' }
            Mock Unregister-PSRepository { throw 'cleanup failed' }
            Mock Write-Warning {}
        }

        It 'Preserves the installation failure' {
            { Install-SingleModule -Name 'TestMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 1 -BaseDelaySeconds 1 } |
                Should -Throw '*Failed to install TestMod*'

            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like 'Failed to remove temporary repository*'
            }
        }
    }

    Context 'when cleanup is the only failure' {
        BeforeAll {
            Mock Initialize-Repository { "HVEPSGallery-$PID-test" }
            Mock Install-Module {}
            Mock Unregister-PSRepository { throw 'cleanup failed' }
        }

        It 'Fails instead of reporting successful cleanup' {
            { Install-SingleModule -Name 'TestMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 1 -BaseDelaySeconds 1 } |
                Should -Throw '*Failed to remove temporary repository*'
        }
    }

    Context 'when Install-Module fails twice then succeeds' {
        BeforeAll {
            $script:CallCount = 0
            Mock Install-Module {
                $script:CallCount++
                if ($script:CallCount -le 2) {
                    throw "PSGallery transient failure"
                }
            }
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
        }
        BeforeEach {
            $script:CallCount = 0
        }

        It 'Retries and succeeds on the third attempt' {
            { Install-SingleModule -Name 'RetryMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 10 } |
                Should -Not -Throw
        }

        It 'Calls Install-Module 3 times' {
            Install-SingleModule -Name 'RetryMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 10

            Should -Invoke Install-Module -Times 3 -Exactly
        }

        It 'Calls Start-Sleep twice with exponential backoff' {
            Install-SingleModule -Name 'RetryMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 10

            Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 10 }
            Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 20 }
        }
    }

    Context 'when Install-Module fails on all attempts' {
        BeforeAll {
            Mock Install-Module { throw "PSGallery is down" }
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
        }

        It 'Throws after exhausting retries' {
            { Install-SingleModule -Name 'FailMod' -Version '1.0.0' -Scope 'CurrentUser' `
                -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 5 } |
                Should -Throw '*Failed to install FailMod*'
        }

        It 'Calls Install-Module MaxAttempts times' {
            try {
                Install-SingleModule -Name 'FailMod' -Version '1.0.0' -Scope 'CurrentUser' `
                    -Repository 'PSGallery' -MaxAttempts 3 -BaseDelaySeconds 5
            } catch { $null = $_ }

            Should -Invoke Install-Module -Times 3 -Exactly
        }
    }

    Context 'when running in GitHub Actions' {
        BeforeAll {
            Mock Install-Module { throw "network error" }
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
        }
        BeforeEach {
            $script:OrigGA = $env:GITHUB_ACTIONS
            $env:GITHUB_ACTIONS = 'true'
        }
        AfterEach {
            $env:GITHUB_ACTIONS = $script:OrigGA
        }

        It 'Emits ::warning:: annotations on retry' {
            try {
                Install-SingleModule -Name 'CIMod' -Version '1.0.0' -Scope 'CurrentUser' `
                    -Repository 'PSGallery' -MaxAttempts 2 -BaseDelaySeconds 1
            } catch { $null = $_ }

            Should -Invoke Write-Host -ParameterFilter { $Object -like '::warning::*' } -Times 1 -Exactly
        }

        It 'Emits ::error:: annotation on final failure' {
            try {
                Install-SingleModule -Name 'CIMod' -Version '1.0.0' -Scope 'CurrentUser' `
                    -Repository 'PSGallery' -MaxAttempts 2 -BaseDelaySeconds 1
            } catch { $null = $_ }

            Should -Invoke Write-Host -ParameterFilter { $Object -like '::error::*' } -Times 1 -Exactly
        }
    }
}

Describe 'Invoke-PSModuleInstall end-to-end' -Tag 'Unit' {
    BeforeAll {
        $script:ConfigFile = Join-Path $TestDrive 'ps-module-versions.json'
        $script:FixtureConfig | Set-Content -Path $script:ConfigFile -Encoding UTF8
    }

    Context 'when all modules are already installed (idempotent skip)' {
        BeforeAll {
            Mock Get-Module {
                param($Name)
                switch ($Name) {
                    'FakeModuleA' { [PSCustomObject]@{ Version = [version]'1.0.0' } }
                    'FakeModuleB' { [PSCustomObject]@{ Version = [version]'2.5.0' } }
                }
            }
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
            Mock Install-Module {}
            Mock Import-Module {}
        }

        It 'Does not call Install-Module' {
            Invoke-PSModuleInstall -ConfigPath $script:ConfigFile

            Should -Invoke Install-Module -Times 0 -Exactly
        }
    }

    Context 'when -Force is specified' {
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{ Version = [version]'1.0.0' }
            }
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
            Mock Install-Module {}
            Mock Import-Module {}
        }

        It 'Calls Install-Module even for present modules' {
            Invoke-PSModuleInstall -ConfigPath $script:ConfigFile -Force

            Should -Invoke Install-Module -Times 2 -Exactly
        }
    }

    Context 'when -Import is specified' {
        BeforeAll {
            Mock Get-Module {
                param($Name)
                switch ($Name) {
                    'FakeModuleA' { [PSCustomObject]@{ Version = [version]'1.0.0' } }
                    'FakeModuleB' { [PSCustomObject]@{ Version = [version]'2.5.0' } }
                }
            }
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
            Mock Install-Module {}
            Mock Import-Module {}
        }

        It 'Calls Import-Module for each module' {
            Invoke-PSModuleInstall -ConfigPath $script:ConfigFile -Import

            Should -Invoke Import-Module -Times 2 -Exactly
        }
    }

    Context 'when -Import is not specified' {
        BeforeAll {
            Mock Get-Module {
                param($Name)
                switch ($Name) {
                    'FakeModuleA' { [PSCustomObject]@{ Version = [version]'1.0.0' } }
                    'FakeModuleB' { [PSCustomObject]@{ Version = [version]'2.5.0' } }
                }
            }
            Mock Get-PSRepository {
                [PSCustomObject]@{ Name = 'PSGallery' }
            }
            Mock Register-PSRepository {}
            Mock Install-Module {}
            Mock Import-Module {}
        }

        It 'Does not call Import-Module' {
            Invoke-PSModuleInstall -ConfigPath $script:ConfigFile

            Should -Invoke Import-Module -Times 0 -Exactly
        }
    }

    Context 'when config file does not exist' {
        It 'Throws a descriptive error' {
            { Invoke-PSModuleInstall -ConfigPath (Join-Path $TestDrive 'nonexistent.json') } |
                Should -Throw '*Config file not found*'
        }
    }
}

AfterAll {
    # Restore any leaked env vars
    $env:PS_MODULE_CONFIG_PATH = $null
    $env:PS_MODULE_SCOPE = $null
}
