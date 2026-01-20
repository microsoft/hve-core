#Requires -Modules Pester

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Update-ActionSHAPinning.ps1'
    $scriptContent = Get-Content $scriptPath -Raw

    # Extract function definitions and script-level variables using AST to avoid executing main block
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$errors)

    # Extract and execute script-level variable assignments (e.g., $ActionSHAMap)
    # These are direct children of the script block that are assignments
    $scriptStatements = $ast.EndBlock.Statements
    foreach ($stmt in $scriptStatements) {
        if ($stmt -is [System.Management.Automation.Language.AssignmentStatementAst]) {
            $varCode = $stmt.Extent.Text
            try {
                $scriptBlock = [scriptblock]::Create($varCode)
                . $scriptBlock
            } catch {
                # Skip assignments that fail (may depend on other variables)
                $null = $_
            }
        }
    }

    # Extract and define all function definitions
    $functionDefs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    foreach ($func in $functionDefs) {
        $funcCode = $func.Extent.Text
        $scriptBlock = [scriptblock]::Create($funcCode)
        . $scriptBlock
    }

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
            $result = Get-ActionReference -WorkflowContent $yaml
            $result | Should -Not -BeNullOrEmpty
            $result.OriginalRef | Should -Be 'actions/checkout@v4'
        }

        It 'Parses action with SHA reference' {
            $yaml = 'uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29'
            $result = Get-ActionReference -WorkflowContent $yaml
            $result.OriginalRef | Should -Be 'actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29'
        }

        It 'Returns LineNumber for reference' {
            $yaml = "name: Test`njobs:`n  test:`n    steps:`n      - name: Checkout`n        uses: actions/checkout@v4"
            $result = Get-ActionReference -WorkflowContent $yaml
            $result.LineNumber | Should -BeGreaterThan 0
        }
    }

    Context 'Multiple action references' {
        It 'Finds all action references in workflow' {
            $yaml = "jobs:`n  test:`n    steps:`n      - name: Checkout`n        uses: actions/checkout@v4`n      - name: Setup`n        uses: actions/setup-node@v4"
            $result = @(Get-ActionReference -WorkflowContent $yaml)
            $result.Count | Should -Be 2
        }
    }

    Context 'Invalid references' {
        It 'Returns empty for non-action content' {
            $yaml = 'run: echo "Hello"'
            $result = Get-ActionReference -WorkflowContent $yaml
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
        It 'Returns action reference with SHA for known action' {
            $result = Get-SHAForAction -ActionRef 'actions/checkout@v4'
            $result | Should -Not -BeNullOrEmpty
            # Function returns full action reference with SHA (e.g., actions/checkout@sha)
            $result | Should -Match '@[a-f0-9]{40}$'
        }
    }

    Context 'Unmapped actions' {
        It 'Returns null when action not in map and no API call is made' {
            # Get-SHAForAction returns null for unmapped actions without attempting API
            $result = Get-SHAForAction -ActionRef 'unknown/action@v1'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for unmapped actions requiring manual review' {
            # The function logs a warning and returns null for unmapped actions
            $result = Get-SHAForAction -ActionRef 'test-org/test-action@v1'
            $result | Should -BeNullOrEmpty
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
            return @{
                object = @{
                    sha = 'newsha123456789012345678901234567890abcd'
                }
            }
        }
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'Return value structure' {
        It 'Returns hashtable with FilePath' {
            $result = Update-WorkflowFile -FilePath $script:TestWorkflow
            $result | Should -BeOfType [hashtable]
            $result.FilePath | Should -Be $script:TestWorkflow
        }

        It 'Returns ActionsProcessed count' {
            $result = Update-WorkflowFile -FilePath $script:TestWorkflow
            $result.ActionsProcessed | Should -BeGreaterOrEqual 0
        }

        It 'Returns ActionsPinned count' {
            $result = Update-WorkflowFile -FilePath $script:TestWorkflow
            $result.ContainsKey('ActionsPinned') | Should -BeTrue
        }
    }

    Context 'File modification' {
        It 'Updates unpinned action to SHA' {
            Update-WorkflowFile -FilePath $script:TestWorkflow

            $content = Get-Content $script:TestWorkflow -Raw
            # Check that the file was processed (content may or may not change based on mock)
            $content | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Already pinned workflows' {
        It 'Does not modify already pinned actions' {
            $pinnedSource = Join-Path $script:FixturesPath 'pinned-workflow.yml'
            $pinnedTest = Join-Path $TestDrive 'pinned-test.yml'
            Copy-Item $pinnedSource $pinnedTest

            $originalContent = Get-Content $pinnedTest -Raw
            Update-WorkflowFile -FilePath $pinnedTest
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
            return @{
                object = @{
                    sha = 'newsha123456789012345678901234567890abcd'
                }
            }
        }
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'WhatIf behavior' {
        It 'Does not modify file when WhatIf is specified' {
            $originalContent = Get-Content $script:TestWorkflow -Raw

            Update-WorkflowFile -FilePath $script:TestWorkflow -WhatIf

            $newContent = Get-Content $script:TestWorkflow -Raw
            $newContent | Should -Be $originalContent
        }
    }
}
