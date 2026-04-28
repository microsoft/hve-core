#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'Test-FsiPersistenceSanity' -Tag 'Unit' {
    Context 'sensitive input persisted to user scope' {
        It 'emits a warning' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{secret}} Header"
inputs:
  - name: secret
    description: A sensitive value
    sensitive: true
    persistence: user
'@
            $path = Join-Path $TestDrive 'sensitive-user.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiPersistenceSanity -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'sensitive'
            $result.Warnings[0] | Should -Match 'persistence: user'
        }
    }

    Context 'sensitive input with session persistence' {
        It 'emits no warnings' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{secret}} Header"
inputs:
  - name: secret
    description: A sensitive value
    sensitive: true
    persistence: session
'@
            $path = Join-Path $TestDrive 'sensitive-session.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiPersistenceSanity -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'non-sensitive input persisted to user scope' {
        It 'emits no warnings' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{name}} Header"
inputs:
  - name: name
    description: User name
    persistence: user
'@
            $path = Join-Path $TestDrive 'normal-user.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiPersistenceSanity -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'item without inputs' {
        It 'emits no warnings' {
            $yaml = @'
id: test-section
title: Test Section
template: "Static text"
'@
            $path = Join-Path $TestDrive 'no-inputs.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiPersistenceSanity -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Warnings | Should -HaveCount 0
        }
    }
}
