#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
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

Describe 'Install-SingleModule' -Tag 'Unit' {
    Context 'when Install-Module succeeds on first attempt' {
        BeforeAll {
            Mock Install-Module {}
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

    Context 'when Install-Module fails twice then succeeds' {
        BeforeAll {
            $script:CallCount = 0
            Mock Install-Module {
                $script:CallCount++
                if ($script:CallCount -le 2) {
                    throw "PSGallery transient failure"
                }
            }
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
