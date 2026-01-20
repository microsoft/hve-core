#Requires -Modules Pester

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Update-ActionSHAPinning.ps1'
    . $scriptPath

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # Save environment before tests
    Save-GitHubEnvironment

    # Fixture paths
    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'
}

AfterAll {
    Restore-GitHubEnvironment
}

Describe 'Get-ActionReference' -Tag 'Unit' {
    Context 'Standard action references' {
        It 'Parses action with tag reference' {
            $yaml = 'uses: actions/checkout@v4'
            $result = Get-ActionReference -Content $yaml
            $result | Should -Not -BeNullOrEmpty
            $result.Owner | Should -Be 'actions'
            $result.Repo | Should -Be 'checkout'
            $result.Ref | Should -Be 'v4'
        }

        It 'Parses action with SHA reference' {
            $yaml = 'uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29'
            $result = Get-ActionReference -Content $yaml
            $result.Ref | Should -Be 'a5ac7e51b41094c92402da3b24376905380afc29'
        }
    }

    Context 'Action with subpath' {
        It 'Parses action with subpath correctly' {
            $yaml = 'uses: actions/aws-for-github-actions/configure-credentials@v4'
            $result = Get-ActionReference -Content $yaml
            $result.Owner | Should -Be 'actions'
            $result.Repo | Should -Match 'aws-for-github-actions'
        }
    }

    Context 'Invalid references' {
        It 'Returns null for non-action content' {
            $yaml = 'run: echo "Hello"'
            $result = Get-ActionReference -Content $yaml
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-SHAForAction' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'ActionSHAMap lookup' {
        It 'Returns SHA from ActionSHAMap for known action' {
            $result = Get-SHAForAction -Owner 'actions' -Repo 'checkout' -Version 'v4'
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match '^[a-f0-9]{40}$'
        }
    }

    Context 'API fallback' {
        It 'Calls API for unknown action' {
            Mock Invoke-RestMethod {
                return @{ sha = 'api123456789012345678901234567890abcdef' }
            } -ParameterFilter {
                $Uri -match 'api.github.com/repos'
            }

            $result = Get-SHAForAction -Owner 'unknown' -Repo 'action' -Version 'v1'
            $result | Should -Be 'api123456789012345678901234567890abcdef'
        }
    }
}

Describe 'Update-WorkflowFile' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'

        # Copy fixture to TestDrive for modification testing
        $unpinnedSource = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
        $script:TestWorkflow = Join-Path $TestDrive 'test-workflow.yml'
        Copy-Item $unpinnedSource $script:TestWorkflow

        Mock Invoke-RestMethod {
            return @{ sha = 'newsha123456789012345678901234567890abcd' }
        }
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'File modification' {
        It 'Updates unpinned action to SHA' {
            Update-WorkflowFile -Path $script:TestWorkflow

            $content = Get-Content $script:TestWorkflow -Raw
            $content | Should -Match '[a-f0-9]{40}'
            $content | Should -Not -Match 'uses: actions/checkout@v4\s*$'
        }

        It 'Preserves version comment after SHA' {
            Update-WorkflowFile -Path $script:TestWorkflow

            $content = Get-Content $script:TestWorkflow -Raw
            $content | Should -Match '#\s*v\d+'
        }
    }

    Context 'Already pinned workflows' {
        It 'Does not modify already pinned actions' {
            $pinnedSource = Join-Path $script:FixturesPath 'pinned-workflow.yml'
            $pinnedTest = Join-Path $TestDrive 'pinned-test.yml'
            Copy-Item $pinnedSource $pinnedTest

            $originalContent = Get-Content $pinnedTest -Raw
            Update-WorkflowFile -Path $pinnedTest
            $newContent = Get-Content $pinnedTest -Raw

            $newContent | Should -Be $originalContent
        }
    }
}

Describe 'Update-WorkflowFile -WhatIf' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'

        $unpinnedSource = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
        $script:TestWorkflow = Join-Path $TestDrive 'whatif-test.yml'
        Copy-Item $unpinnedSource $script:TestWorkflow

        Mock Invoke-RestMethod {
            return @{ sha = 'newsha123456789012345678901234567890abcd' }
        }
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'WhatIf behavior' {
        It 'Does not modify file when WhatIf is specified' {
            $originalContent = Get-Content $script:TestWorkflow -Raw

            Update-WorkflowFile -Path $script:TestWorkflow -WhatIf

            $newContent = Get-Content $script:TestWorkflow -Raw
            $newContent | Should -Be $originalContent
        }

        It 'Reports what would be changed without modifying' {
            $result = Update-WorkflowFile -Path $script:TestWorkflow -WhatIf -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.WouldUpdate | Should -BeTrue
        }
    }
}
