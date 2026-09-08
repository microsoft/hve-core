#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Running a workflow step body against fixtures needs the shell it declares and
# the jq available inside that shell, which may differ from the host command path.
$script:BashCommand = (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1).Source
$script:SkipShellFixtureTests = -not $script:BashCommand
if (-not $script:SkipShellFixtureTests) {
    & $script:BashCommand -c 'command -v jq >/dev/null && command -v pwsh >/dev/null' 2>$null
    $script:SkipShellFixtureTests = $LASTEXITCODE -ne 0
}

BeforeAll {
    $script:BashCommand = (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1).Source
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:WorkflowDirectory = Join-Path $script:RepositoryRoot '.github/workflows'

    # Every workflow that participates in building, attesting, publishing, or
    # reconciling the one hve-core package.
    $script:PackagingWorkflow = [string[]]@(
        'extension-provenance-signer.yml'
        'extension-marketplace-publish.yml'
        'release-marketplace-prerelease.yml'
        'release-marketplace-stable.yml'
        'release-prerelease.yml'
        'release-vsix-publish.yml'
        'release-stable-publish.yml'
        'release-prerelease-prepare.yml'
        'release-stable.yml'
        'pr-validation.yml'
    )

    function Get-WorkflowText {
        <#
        .SYNOPSIS
        Reads raw workflow text.
        .PARAMETER Name
        Workflow file name.
        .OUTPUTS
        [string] Raw workflow content.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        return Get-Content -LiteralPath (Join-Path $script:WorkflowDirectory $Name) -Raw -Encoding utf8
    }

    function Get-WorkflowDocument {
        <#
        .SYNOPSIS
        Parses one workflow file.
        .PARAMETER Name
        Workflow file name.
        .OUTPUTS
        [System.Collections.IDictionary] Parsed workflow.
        #>
        [CmdletBinding()]
        [OutputType([System.Collections.IDictionary])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        return (Get-WorkflowText -Name $Name | ConvertFrom-Yaml)
    }

    function Get-JobStepText {
        <#
        .SYNOPSIS
        Returns the run and uses text of every step in a job, in declaration order.
        .PARAMETER Document
        Parsed workflow.
        .PARAMETER JobName
        Job identifier.
        .OUTPUTS
        [string[]] Step text in order.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [System.Collections.IDictionary]$Document,

            [Parameter(Mandatory = $true)]
            [string]$JobName
        )

        $steps = @($Document['jobs'][$JobName]['steps'])
        return [string[]]@($steps | ForEach-Object {
                $run = if ($_.Contains('run')) { [string]$_['run'] } else { '' }
                $uses = if ($_.Contains('uses')) { [string]$_['uses'] } else { '' }
                "$uses`n$run"
            })
    }

    function Get-NamedJobStep {
        <#
        .SYNOPSIS
        Returns the single step of a job carrying an exact display name.
        .PARAMETER Document
        Parsed workflow.
        .PARAMETER JobName
        Job identifier.
        .PARAMETER StepName
        Step display name.
        .OUTPUTS
        [System.Collections.IDictionary] Matching step.
        #>
        [CmdletBinding()]
        [OutputType([System.Collections.IDictionary])]
        param(
            [Parameter(Mandatory = $true)]
            [System.Collections.IDictionary]$Document,

            [Parameter(Mandatory = $true)]
            [string]$JobName,

            [Parameter(Mandatory = $true)]
            [string]$StepName
        )

        $found = @($Document['jobs'][$JobName]['steps'] | Where-Object { [string]$_['name'] -eq $StepName })
        if ($found.Count -ne 1) {
            throw "Job '$JobName' must declare exactly one step named '$StepName' but declared $($found.Count)"
        }
        return $found[0]
    }

    function Invoke-BashFixtureStep {
        <#
        .SYNOPSIS
        Runs a Bash step body in a disposable fixture.
        .PARAMETER Body
        Step run text.
        .PARAMETER Environment
        Environment variables supplied to the step, including blank values.
        .PARAMETER Setup
        Optional fixture setup callback receiving the fixture path.
        .OUTPUTS
        [pscustomobject] Exit code, output, workflow output, and attempt count.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Body,

            [Parameter(Mandatory = $true)]
            [hashtable]$Environment,

            [Parameter(Mandatory = $false)]
            [scriptblock]$Setup
        )

        $fixture = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        try {
            if ($Setup) {
                & $Setup $fixture
            }
            $stepPath = Join-Path $fixture 'step.sh'
            [IO.File]::WriteAllText($stepPath, ($Body -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
            $environmentPath = Join-Path $fixture 'environment.sh'
            $environmentLines = [string[]]@($Environment.GetEnumerator() | ForEach-Object {
                    $encodedValue = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$_.Value))
                    "export $($_.Key)=`"`$(printf '%s' '$encodedValue' | base64 --decode)`""
                })
            [IO.File]::WriteAllText($environmentPath, ($environmentLines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))

            Push-Location -LiteralPath $fixture
            try {
                if (Test-Path -LiteralPath (Join-Path $fixture 'bin')) {
                    & $script:BashCommand -c 'chmod +x ./bin/*'
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Unable to make fixture commands executable'
                    }
                }
                $output = & $script:BashCommand -c 'source ./environment.sh; export PATH="$PWD/bin:$PATH"; bash ./step.sh' 2>$null
                $exitCode = $LASTEXITCODE
                $githubOutputPath = Join-Path $fixture 'github-output.txt'
                $attemptCountPath = Join-Path $fixture 'attempt-count.txt'
                return [pscustomobject]@{
                    ExitCode    = $exitCode
                    Output      = [string]::Join("`n", [string[]]@($output))
                    GithubOutput = if (Test-Path -LiteralPath $githubOutputPath) {
                        Get-Content -LiteralPath $githubOutputPath -Raw -Encoding utf8
                    } else { '' }
                    AttemptCount = if (Test-Path -LiteralPath $attemptCountPath) {
                        [int](Get-Content -LiteralPath $attemptCountPath -Raw -Encoding utf8).Trim()
                    } else { 0 }
                }
            } finally {
                Pop-Location
            }
        } finally {
            Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    function Invoke-WorkflowShellStep {
        <#
        .SYNOPSIS
        Runs a parsed bash step body in a disposable extension template fixture.
        .PARAMETER Body
        Step run text.
        .PARAMETER TemplateVersion
        Version committed to the fixture extension template.
        .PARAMETER Environment
        Step environment variables, which may hold blank values.
        .OUTPUTS
        [pscustomobject] Exit code and captured annotation output.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Body,

            [Parameter(Mandatory = $true)]
            [string]$TemplateVersion,

            [Parameter(Mandatory = $true)]
            [hashtable]$Environment
        )

        $setup = {
            param($FixturePath)
            $templateDirectory = Join-Path $FixturePath 'extension/templates'
            New-Item -ItemType Directory -Path $templateDirectory -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $templateDirectory 'package.template.json') `
                -Value "{`"name`":`"hve-core`",`"version`":`"$TemplateVersion`"}" -Encoding utf8
        }
        return Invoke-BashFixtureStep -Body $Body -Environment $Environment -Setup $setup
    }

    function Invoke-ReleaseAuthorizationShellStep {
        <#
        .SYNOPSIS
        Runs immutable signer authorization against deterministic App and ruleset responses.
        .PARAMETER Body
        Authorization step body.
        .PARAMETER Environment
        Trusted event and caller input environment.
        .PARAMETER RulesetList
        Summary list response for repository tag rulesets.
        .PARAMETER CreationRuleset
        Detailed creation-ruleset response.
        .PARAMETER ImmutableRuleset
        Detailed immutability-ruleset response.
        .OUTPUTS
        [pscustomobject] Exit code and captured annotation output.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Body,

            [Parameter(Mandatory = $true)]
            [hashtable]$Environment,

            [Parameter(Mandatory = $true)]
            [string]$RulesetList,

            [Parameter(Mandatory = $true)]
            [string]$CreationRuleset,

            [Parameter(Mandatory = $true)]
            [string]$ImmutableRuleset,

            [Parameter(Mandatory = $false)]
            [string]$ReleaseList = '[{"id":201,"tag_name":"v3.4.0","target_commitish":"1111111111111111111111111111111111111111","draft":true,"prerelease":false}]',

            [Parameter(Mandatory = $false)]
            [ValidateSet('ahead', 'identical', 'behind', 'diverged')]
            [string]$CompareStatus = 'ahead'
        )

        $setup = {
            param($FixturePath)
            $binDirectory = Join-Path $FixturePath 'bin'
            New-Item -ItemType Directory -Path $binDirectory -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $FixturePath 'ruleset-list.json'), $RulesetList, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $FixturePath 'release-list.json'), $ReleaseList, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $FixturePath 'creation.json'), $CreationRuleset, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $FixturePath 'immutable.json'), $ImmutableRuleset, [Text.UTF8Encoding]::new($false))
            $ghCommand = @'
#!/usr/bin/env bash
set -euo pipefail
test "$1" = 'api'
shift
if [ "$1" = '--paginate' ] && [ "$2" = '--slurp' ]; then
    printf '['
    case "$3" in
        */releases?*)
            cat "$MOCK_RELEASE_LIST"
            ;;
        */rulesets?*)
            cat "$MOCK_RULESET_LIST"
            ;;
        *)
            exit 1
            ;;
    esac
    printf ']'
    exit 0
fi
case "$1" in
    /apps/hve-core-release-please)
        printf '%s\n' '{"id":2646666,"slug":"hve-core-release-please"}'
        ;;
    /users/hve-core-release-please%5Bbot%5D)
        printf '%s\n' '{"id":254602402,"login":"hve-core-release-please[bot]","type":"Bot"}'
        ;;
    */git/ref/heads/release/stable)
        printf '%s\n' '{"object":{"sha":"3333333333333333333333333333333333333333"}}'
        ;;
    */compare/1111111111111111111111111111111111111111...3333333333333333333333333333333333333333)
        printf '{"status":"%s"}\n' "$MOCK_COMPARE_STATUS"
        ;;
    */rulesets/101?*)
        cat "$MOCK_CREATION_RULESET"
        ;;
    */rulesets/102?*)
        cat "$MOCK_IMMUTABLE_RULESET"
        ;;
    *)
        exit 1
        ;;
esac
'@
            [IO.File]::WriteAllText((Join-Path $binDirectory 'gh'), ($ghCommand -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
        }
        $fixtureEnvironment = @{} + $Environment
        $fixtureEnvironment['MOCK_RULESET_LIST'] = './ruleset-list.json'
        $fixtureEnvironment['MOCK_RELEASE_LIST'] = './release-list.json'
        $fixtureEnvironment['MOCK_CREATION_RULESET'] = './creation.json'
        $fixtureEnvironment['MOCK_IMMUTABLE_RULESET'] = './immutable.json'
        $fixtureEnvironment['MOCK_COMPARE_STATUS'] = $CompareStatus
        $fixtureEnvironment['RUNNER_TEMP'] = '.'
        return Invoke-BashFixtureStep -Body $Body -Environment $fixtureEnvironment -Setup $setup
    }

    function Invoke-AttestationInputShellStep {
        <#
        .SYNOPSIS
        Runs the frozen attestation input validator against a disposable package artifact.
        .PARAMETER Body
        Attestation validation step body.
        .PARAMETER ManifestMutation
        Optional mutation applied to the otherwise valid package manifest.
        .PARAMETER ExtraFile
        Optional unexpected basename added to the package artifact.
        .OUTPUTS
        [pscustomobject] Exit code and captured annotation output.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Body,

            [Parameter(Mandatory = $false)]
            [scriptblock]$ManifestMutation,

            [Parameter(Mandatory = $false)]
            [string]$ExtraFile = ''
        )

        $setup = {
            param($FixturePath)
            $inputDirectory = Join-Path $FixturePath 'input'
            New-Item -ItemType Directory -Path $inputDirectory -Force | Out-Null
            $vsixPath = Join-Path $inputDirectory 'hve-core-3.4.0.vsix'
            $sbomPath = Join-Path $inputDirectory 'hve-core-3.4.0.vsix.spdx.json'
            $dependencySbomPath = Join-Path $inputDirectory 'dependencies.spdx.json'
            [IO.File]::WriteAllText($vsixPath, 'fixed vsix bytes', [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($sbomPath, '{"spdxVersion":"SPDX-2.3"}', [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($dependencySbomPath, '{"spdxVersion":"SPDX-2.3"}', [Text.UTF8Encoding]::new($false))
            $manifest = [ordered]@{
                sourceSha = '1111111111111111111111111111111111111111'
                releaseTag = 'v3.4.0'
                channel = 'Stable'
                version = '3.4.0'
                files = @(
                    [ordered]@{ name = 'hve-core-3.4.0.vsix'; sha256 = (Get-FileHash -LiteralPath $vsixPath -Algorithm SHA256).Hash.ToLowerInvariant() }
                    [ordered]@{ name = 'hve-core-3.4.0.vsix.spdx.json'; sha256 = (Get-FileHash -LiteralPath $sbomPath -Algorithm SHA256).Hash.ToLowerInvariant() }
                    [ordered]@{ name = 'dependencies.spdx.json'; sha256 = (Get-FileHash -LiteralPath $dependencySbomPath -Algorithm SHA256).Hash.ToLowerInvariant() }
                )
            }
            if ($ManifestMutation) {
                & $ManifestMutation $manifest
            }
            [IO.File]::WriteAllText((Join-Path $inputDirectory 'manifest.json'), ($manifest | ConvertTo-Json -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
            if ($ExtraFile) {
                [IO.File]::WriteAllText((Join-Path $inputDirectory $ExtraFile), 'unexpected', [Text.UTF8Encoding]::new($false))
            }
        }
        return Invoke-BashFixtureStep -Body $Body -Environment @{
            CHANNEL              = 'Stable'
            DEPENDENCY_SBOM_NAME = 'dependencies.spdx.json'
            RELEASE_TAG          = 'v3.4.0'
            SBOM_NAME            = 'hve-core-3.4.0.vsix.spdx.json'
            SOURCE_SHA           = '1111111111111111111111111111111111111111'
            VERSION              = '3.4.0'
            VSIX_NAME            = 'hve-core-3.4.0.vsix'
        } -Setup $setup
    }

    function Invoke-ReleaseDiscoveryShellStep {
        <#
        .SYNOPSIS
        Runs the release-discovery Bash body against deterministic API responses.
        .PARAMETER Body
        Release-discovery step run text.
        .PARAMETER Response
        JSON responses returned by successive mocked API calls. The last response repeats.
        .PARAMETER Environment
        Expected release identity environment.
        .PARAMETER ApiFailureAttempt
        Optional API attempt that returns a nonzero exit code.
        .OUTPUTS
        [pscustomobject] Exit code, output, workflow output, and API attempt count.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Body,

            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string[]]$Response,

            [Parameter(Mandatory = $true)]
            [hashtable]$Environment,

            [Parameter(Mandatory = $false)]
            [int]$ApiFailureAttempt = 0
        )

        $setup = {
            param($FixturePath)
            $binDirectory = Join-Path $FixturePath 'bin'
            $responseDirectory = Join-Path $FixturePath 'responses'
            New-Item -ItemType Directory -Path $binDirectory, $responseDirectory -Force | Out-Null
            for ($attempt = 1; $attempt -le 20; $attempt++) {
                $responseIndex = [Math]::Min($attempt - 1, $Response.Count - 1)
                Set-Content -LiteralPath (Join-Path $responseDirectory "$attempt.json") `
                    -Value $Response[$responseIndex] -Encoding utf8
            }
            $ghCommand = @'
#!/usr/bin/env bash
set -euo pipefail
attempt=0
if [ -f "$MOCK_COUNTER_FILE" ]; then
  attempt=$(cat "$MOCK_COUNTER_FILE")
fi
attempt=$((attempt + 1))
printf '%s' "$attempt" > "$MOCK_COUNTER_FILE"
if [ "$MOCK_API_FAILURE_ATTEMPT" -eq "$attempt" ]; then
  exit 1
fi
cat "$MOCK_RESPONSE_DIRECTORY/$attempt.json"
'@
            [IO.File]::WriteAllText((Join-Path $binDirectory 'gh'), ($ghCommand -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
            $sleepCommand = @'
#!/usr/bin/env bash
exit 0
'@
            [IO.File]::WriteAllText((Join-Path $binDirectory 'sleep'), ($sleepCommand -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
        }
        $fixtureEnvironment = @{} + $Environment
        $fixtureEnvironment['GITHUB_OUTPUT'] = './github-output.txt'
        $fixtureEnvironment['MOCK_API_FAILURE_ATTEMPT'] = $ApiFailureAttempt
        $fixtureEnvironment['MOCK_COUNTER_FILE'] = './attempt-count.txt'
        $fixtureEnvironment['MOCK_RESPONSE_DIRECTORY'] = './responses'
        $fixtureEnvironment['RUNNER_TEMP'] = '.'
        return Invoke-BashFixtureStep -Body $Body -Environment $fixtureEnvironment -Setup $setup
    }

        function Invoke-ReleaseAssetShellStep {
                <#
                .SYNOPSIS
                Runs a release asset verification Bash body with mocked GitHub and PowerShell commands.
                .PARAMETER Body
                Release asset verification step run text.
                .PARAMETER AssetName
                Release asset names returned by the mocked API.
                .PARAMETER Environment
                Release identity environment supplied to the step.
                .OUTPUTS
                [pscustomobject] Exit code and captured command output.
                #>
                [CmdletBinding()]
                [OutputType([pscustomobject])]
                param(
                        [Parameter(Mandatory = $true)]
                        [string]$Body,

                        [Parameter(Mandatory = $true)]
                        [AllowEmptyCollection()]
                        [string[]]$AssetName,

                        [Parameter(Mandatory = $true)]
                        [hashtable]$Environment
                )

                $setup = {
                        param($FixturePath)
                        $binDirectory = Join-Path $FixturePath 'bin'
                        $releaseDirectory = Join-Path $FixturePath 'scripts/release'
                        $moduleDirectory = Join-Path $FixturePath 'scripts/lib/Modules'
                        New-Item -ItemType Directory -Path $binDirectory -Force | Out-Null
                        New-Item -ItemType Directory -Path $releaseDirectory, $moduleDirectory -Force | Out-Null
                        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'scripts/release/Assert-ReleaseAssetSet.ps1') `
                            -Destination $releaseDirectory
                        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'scripts/lib/Modules/CIHelpers.psm1') `
                            -Destination $moduleDirectory
                        $assetRows = for ($index = 0; $index -lt $AssetName.Count; $index++) {
                                "$($index + 1)`t$($AssetName[$index])"
                        }
                        $assetNames = if ($AssetName.Count -gt 0) {
                            ($AssetName -join "`n") + "`n"
                        }
                        else {
                            ''
                        }
                        $assetResponse = if ($assetRows.Count -gt 0) {
                            ($assetRows -join "`n") + "`n"
                        }
                        else {
                            ''
                        }
                        [IO.File]::WriteAllText((Join-Path $FixturePath 'asset-response.names'), $assetNames, [Text.UTF8Encoding]::new($false))
                        [IO.File]::WriteAllText((Join-Path $FixturePath 'asset-response.tsv'), $assetResponse, [Text.UTF8Encoding]::new($false))
                        $ghCommand = @'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = 'api' ]; then
    shift
    if [ "$1" != '--paginate' ]; then
        exit 2
    fi
    shift
    if [ "$1" != "$MOCK_EXPECTED_ASSET_ENDPOINT" ]; then
        exit 3
    fi
    shift
    if [ "$1" != '--jq' ] || [ "$#" -ne 2 ]; then
        exit 4
    fi
    case "$2" in
        '.[].name')
            cat "$MOCK_ASSET_NAME_RESPONSE"
            ;;
        '.[] | [.id, .name] | @tsv')
            cat "$MOCK_ASSET_TSV_RESPONSE"
            ;;
        *)
            exit 5
            ;;
    esac
    exit 0
fi
if [ "$1" = 'release' ] && [ "$2" = 'download' ]; then
    pattern=''
    destination='.'
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -p)
                pattern="$2"
                shift 2
                ;;
            -D)
                destination="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    mkdir -p "$destination"
    printf '%s' 'fixture bytes' > "$destination/$pattern"
    exit 0
fi
exit 1
'@
                        [IO.File]::WriteAllText((Join-Path $binDirectory 'gh'), ($ghCommand -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
                        $pwshCommand = @'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *'Assert-ReleaseAssetSet.ps1'* ]]; then
    exec "$MOCK_REAL_PWSH" "$@"
fi
printf 'pwsh %s\n' "$*"
'@
                        [IO.File]::WriteAllText((Join-Path $binDirectory 'pwsh'), ($pwshCommand -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
                }
                $fixtureEnvironment = @{} + $Environment
                $fixtureEnvironment['MOCK_ASSET_NAME_RESPONSE'] = './asset-response.names'
                $fixtureEnvironment['MOCK_ASSET_TSV_RESPONSE'] = './asset-response.tsv'
                $fixtureEnvironment['MOCK_EXPECTED_ASSET_ENDPOINT'] = "/repos/$($Environment['REPOSITORY'])/releases/$($Environment['RELEASE_ID'])/assets?per_page=100"
                $fixtureEnvironment['MOCK_REAL_PWSH'] = (& $script:BashCommand -c 'command -v pwsh').Trim()
                $fixtureEnvironment['RUNNER_TEMP'] = '.'
                return Invoke-BashFixtureStep -Body $Body -Environment $fixtureEnvironment -Setup $setup
        }

        function Invoke-ManagedReleaseIdentityShellStep {
                <#
                .SYNOPSIS
                Runs a managed release postcondition against deterministic GitHub responses.
                .PARAMETER Body
                Managed release identity step run text.
                .PARAMETER Environment
                Release-please outputs and expected identity supplied to the step.
                .PARAMETER TagObject
                Type and SHA returned by the mocked exact tag lookup.
                .PARAMETER ReleaseJson
                JSON returned by the mocked exact release lookup.
                .PARAMETER FailureEndpoint
                Optional endpoint substring whose mocked request fails.
                .OUTPUTS
                [pscustomobject] Exit code and captured output.
                #>
                [CmdletBinding()]
                [OutputType([pscustomobject])]
                param(
                        [Parameter(Mandatory = $true)]
                        [string]$Body,

                        [Parameter(Mandatory = $true)]
                        [hashtable]$Environment,

                        [Parameter(Mandatory = $true)]
                        [string]$TagObject,

                        [Parameter(Mandatory = $true)]
                        [string]$ReleaseJson,

                        [Parameter(Mandatory = $false)]
                        [string]$FailureEndpoint = ''
                )

                $setup = {
                        param($FixturePath)
                        $binDirectory = Join-Path $FixturePath 'bin'
                        New-Item -ItemType Directory -Path $binDirectory -Force | Out-Null
                        $ghCommand = @'
#!/usr/bin/env bash
set -euo pipefail
endpoint="$2"
if [ -n "$MOCK_FAILURE_ENDPOINT" ] && [[ "$endpoint" == *"$MOCK_FAILURE_ENDPOINT"* ]]; then
    exit 1
fi
case "$endpoint" in
    */git/ref/tags/*|*/git/tags/*)
        printf '%s\n' "$MOCK_TAG_OBJECT"
        ;;
    */releases/tags/*)
        printf '%s\n' "$MOCK_RELEASE_JSON"
        ;;
    *)
        exit 1
        ;;
esac
'@
                        [IO.File]::WriteAllText((Join-Path $binDirectory 'gh'), ($ghCommand -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
                }
                $fixtureEnvironment = @{} + $Environment
                $fixtureEnvironment['MOCK_FAILURE_ENDPOINT'] = $FailureEndpoint
                $fixtureEnvironment['MOCK_RELEASE_JSON'] = $ReleaseJson
                $fixtureEnvironment['MOCK_TAG_OBJECT'] = $TagObject
                $fixtureEnvironment['RUNNER_TEMP'] = '.'
                return Invoke-BashFixtureStep -Body $Body -Environment $fixtureEnvironment -Setup $setup
        }

            function Invoke-ReleaseNotesShellStep {
                <#
                .SYNOPSIS
                Runs the Stable note mutation step against a persistent mocked release body.
                .PARAMETER Body
                Release-note workflow step body.
                .PARAMETER InitialBody
                Release body returned on the first read.
                .PARAMETER RunCount
                Number of sequential complete step applications.
                .OUTPUTS
                [pscustomobject] Exit codes, final body, and edit count.
                #>
                [CmdletBinding()]
                [OutputType([pscustomobject])]
                param(
                    [Parameter(Mandatory = $true)]
                    [string]$Body,

                    [Parameter(Mandatory = $true)]
                    [AllowEmptyString()]
                    [string]$InitialBody,

                    [Parameter(Mandatory = $false)]
                    [ValidateRange(1, 3)]
                    [int]$RunCount = 1
                )

                $fixture = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('n'))
                New-Item -ItemType Directory -Path (Join-Path $fixture 'bin') -Force | Out-Null
                try {
                    [IO.File]::WriteAllText((Join-Path $fixture 'step.sh'), ($Body -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
                    [IO.File]::WriteAllText((Join-Path $fixture 'release-body.md'), $InitialBody, [Text.UTF8Encoding]::new($false))
                    [IO.File]::WriteAllText((Join-Path $fixture 'edit-count.txt'), '0', [Text.UTF8Encoding]::new($false))
                    $ghCommand = @'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = 'release' ] && [ "$2" = 'view' ]; then
    cat "$MOCK_RELEASE_BODY"
    exit 0
fi
if [ "$1" = 'release' ] && [ "$2" = 'edit' ]; then
    notes_file=''
    while [ "$#" -gt 0 ]; do
        if [ "$1" = '--notes-file' ]; then
            notes_file="$2"
            break
        fi
        shift
    done
    test -n "$notes_file"
    cp -- "$notes_file" "$MOCK_RELEASE_BODY"
    count=$(cat "$MOCK_EDIT_COUNT")
    printf '%s' "$((count + 1))" > "$MOCK_EDIT_COUNT"
    exit 0
fi
exit 1
'@
                    [IO.File]::WriteAllText((Join-Path $fixture 'bin/gh'), ($ghCommand -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))

                    Push-Location -LiteralPath $fixture
                    try {
                        & $script:BashCommand -c 'chmod +x ./bin/gh'
                        $exitCodes = [System.Collections.Generic.List[int]]::new()
                        for ($run = 1; $run -le $RunCount; $run++) {
                            $null = & $script:BashCommand -c 'export PATH="$PWD/bin:$PATH"; export GH_TOKEN=fixture-token REPOSITORY=microsoft/hve-core TAG=v3.4.0 MOCK_RELEASE_BODY="$PWD/release-body.md" MOCK_EDIT_COUNT="$PWD/edit-count.txt"; bash ./step.sh' 2>$null
                            $exitCodes.Add($LASTEXITCODE)
                            if ($LASTEXITCODE -ne 0) { break }
                        }
                        return [pscustomobject]@{
                            ExitCode  = [int[]]$exitCodes
                            Body      = Get-Content -LiteralPath './release-body.md' -Raw -Encoding utf8
                            EditCount = [int](Get-Content -LiteralPath './edit-count.txt' -Raw -Encoding utf8)
                        }
                    } finally {
                        Pop-Location
                    }
                } finally {
                    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
}

Describe 'Retired multi-package contracts' -Tag 'Unit' {
    # Every retired contract is proved absent from the active packaging and
    # release surface, so a reintroduced matrix or ZIP job fails here first.
    It 'Declares no package matrix input or output in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-provenance-signer.yml' }
        @{ Workflow = 'extension-marketplace-publish.yml' }
        @{ Workflow = 'release-marketplace-prerelease.yml' }
        @{ Workflow = 'release-marketplace-stable.yml' }
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-vsix-publish.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'packages-matrix'
        $text | Should -Not -Match 'matrix\.id'
        $text | Should -Not -Match 'PackageId'
    }

    It 'Declares no job-level matrix strategy in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-provenance-signer.yml' }
        @{ Workflow = 'extension-marketplace-publish.yml' }
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-vsix-publish.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        foreach ($job in $document['jobs'].Keys) {
            $definition = $document['jobs'][$job]
            if ($definition.Contains('strategy')) {
                $definition['strategy'].Contains('matrix') |
                    Should -BeFalse -Because "$Workflow job '$job' packages one fixed identity"
            }
        }
    }

    It 'Invokes no retired package selection or discovery script in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-provenance-signer.yml' }
        @{ Workflow = 'extension-marketplace-publish.yml' }
        @{ Workflow = 'release-marketplace-prerelease.yml' }
        @{ Workflow = 'release-marketplace-stable.yml' }
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-vsix-publish.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
        @{ Workflow = 'pr-validation.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'Get-MarketplacePackageMatrix'
        $text | Should -Not -Match 'Select-PackageVsix'
        $text | Should -Not -Match 'ExtensionIdentity'
        $text | Should -Not -Match 'Generate-Plugins'
        $text | Should -Not -Match 'Update-VersionFiles'
    }

    It 'Calls no plugin packaging workflow and uploads no plugin ZIP in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'plugin-package\.yml'
        $text | Should -Not -Match 'dist/plugins'
        $text | Should -Not -Match "\-p '\*\.zip'"
        $text | Should -Not -Match 'HVE_PLUGIN_STAGING_ROOT'

        $document = Get-WorkflowDocument -Name $Workflow
        [string[]]@($document['jobs'].Keys) | Should -Not -Contain 'upload-plugin-packages'
        @($document['jobs'].Keys | Where-Object { $_ -like 'plugin-package*' }) | Should -BeNullOrEmpty
    }

    It 'Reads no plugin release evidence or release candidate record in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
        @{ Workflow = 'pr-validation.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'plugin-release-evidence'
        $text | Should -Not -Match 'release-candidate'
        $text | Should -Not -Match 'CandidateAction'
    }

    # A one-entry catalog carries a relative source, so no workflow may derive
    # or assert an immutable per-package locator.
    It 'Derives no catalog source locator in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
        @{ Workflow = 'pr-validation.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'BASELINE_TAG'
        $text | Should -Not -Match 'source\.ref'
    }
}

Describe 'One-package build and artifact naming' -Tag 'Unit' {
    It 'Packages one hve-core VSIX from the explicit source ref' {
        $document = Get-WorkflowDocument -Name 'extension-provenance-signer.yml'
        [string[]]@($document['jobs'].Keys | Sort-Object) | Should -Be @('attest', 'authorize', 'package')

        $inputs = $document['on']['workflow_call']['inputs']
        $inputs['source-ref']['required'] | Should -BeTrue
        $inputs['version']['required'] | Should -BeTrue
        $inputs.Contains('channel') | Should -BeTrue
        $document['on']['workflow_call'].Contains('outputs') | Should -BeFalse

        $steps = Get-JobStepText -Document $document -JobName 'package'
        @($steps | Where-Object { $_ -match 'Prepare-Extension\.ps1$' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'Package-Extension\.ps1 @arguments' }) | Should -HaveCount 1
    }

    It 'Validates the source ref before checkout and packaging inputs before dependencies' {
        $document = Get-WorkflowDocument -Name 'extension-provenance-signer.yml'
        $names = [string[]]@($document['jobs']['package']['steps'] | ForEach-Object { [string]$_['name'] })
        $names.IndexOf('Validate source ref') | Should -BeLessThan $names.IndexOf('Checkout code')
        $names.IndexOf('Checkout code') | Should -BeLessThan $names.IndexOf('Validate packaging inputs')
        $names.IndexOf('Validate packaging inputs') | Should -BeLessThan $names.IndexOf('Install dependencies')
    }

    It 'Accepts a source-ref equal to the run commit before checkout' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'package' -StepName 'Validate source ref'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            EVENT_SHA        = 'abcdef1111111111111111111111111111111111'
            INPUT_SOURCE_REF = 'abcdef1111111111111111111111111111111111'
        }
        $result.ExitCode | Should -Be 0
    }

    It 'Rejects malformed source-ref <SourceRef> before checkout' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ SourceRef = '' }
        @{ SourceRef = '-branch' }
        @{ SourceRef = 'bad..ref' }
        @{ SourceRef = 'refs/heads/bad ref' }
        @{ SourceRef = 'main' }
        @{ SourceRef = 'v3.2.2' }
        @{ SourceRef = 'refs/tags/v3.2.2' }
        @{ SourceRef = 'ABCDEF1111111111111111111111111111111111' }
        @{ SourceRef = '2222222222222222222222222222222222222222' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'package' -StepName 'Validate source ref'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            EVENT_SHA        = 'abcdef1111111111111111111111111111111111'
            INPUT_SOURCE_REF = $SourceRef
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'source-ref'
    }

    It 'Fails a committed template version mismatch in extension-provenance-signer.yml' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'package' -StepName 'Validate packaging inputs'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            INPUT_CHANNEL    = 'Stable'
            INPUT_SOURCE_REF = '1111111111111111111111111111111111111111'
            INPUT_VERSION    = '3.5.0'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'is 3\.3\.0 but the caller requested 3\.5\.0'
    }

    It 'Fails a blank version in extension-provenance-signer.yml' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'package' -StepName 'Validate packaging inputs'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            INPUT_SOURCE_REF = '1111111111111111111111111111111111111111'
            INPUT_VERSION    = ''
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'version must be canonical MAJOR.MINOR.PATCH'
    }

    # The builder and the attest workflow must agree on one artifact name, so
    # they can never disagree about what was signed within a run.
    It 'Matches the VSIX artifact producer and consumer names' {
        $text = Get-WorkflowText -Name 'extension-provenance-signer.yml'
        @([regex]::Matches($text, 'name: extension-attestation-input')) | Should -HaveCount 2
        @([regex]::Matches($text, 'name: extension-attested')) | Should -HaveCount 1
    }
}

# A caller-supplied ref must never select a checked-out tree; the run's own
# commit is the only trusted selector, and the gates below are what make it so.
Describe 'Trusted source binding' -Tag 'Unit', 'SignerIsolation' {
    BeforeAll {
        $script:AuthorizationEnvironment = @{
            EVENT_ACTOR       = 'hve-core-release-please[bot]'
            EVENT_ACTOR_ID    = '254602402'
            EVENT_NAME        = 'push'
            EVENT_REF         = 'refs/tags/v3.4.0'
            EVENT_REF_NAME    = 'v3.4.0'
            EVENT_REF_TYPE    = 'tag'
            EVENT_SHA         = '1111111111111111111111111111111111111111'
            GH_TOKEN          = 'fixture-token'
            INPUT_CHANNEL     = 'Stable'
            INPUT_RELEASE_TAG = 'v3.4.0'
            INPUT_SOURCE_REF  = '1111111111111111111111111111111111111111'
            INPUT_VERSION     = '3.4.0'
            RELEASE_APP_SLUG  = 'hve-core-release-please'
            REPOSITORY        = 'microsoft/hve-core'
        }
        $script:RulesetList = '[{"id":101,"name":"release-tags-creation-by-release-app"},{"id":102,"name":"release-tags-immutable"}]'
        $script:CreationRuleset = '{"id":101,"name":"release-tags-creation-by-release-app","target":"tag","source_type":"Repository","source":"microsoft/hve-core","enforcement":"active","bypass_actors":[{"actor_id":2646666,"actor_type":"Integration","bypass_mode":"always"}],"conditions":{"ref_name":{"include":["refs/tags/v*","refs/tags/prerelease-v*"],"exclude":[]}},"rules":[{"type":"creation"}]}'
        $script:ImmutableRuleset = '{"id":102,"name":"release-tags-immutable","target":"tag","source_type":"Repository","source":"microsoft/hve-core","enforcement":"active","bypass_actors":[],"conditions":{"ref_name":{"include":["refs/tags/v*","refs/tags/prerelease-v*"],"exclude":[]}},"rules":[{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}]}'
    }

    It 'Limits the reusable signer to one protected release-tag push caller' {
        $callers = @(Get-ChildItem -LiteralPath $script:WorkflowDirectory -Filter '*.yml' |
            Select-String -Pattern 'uses:\s+microsoft/hve-core/\.github/workflows/extension-provenance-signer\.yml@3a09401536cef0c4559db1aa64b7d1010638fd67\s+# PR #2823 squash\s*$')
        $callers | Should -HaveCount 1
        Split-Path -Path $callers[0].Path -Leaf | Should -BeExactly 'release-vsix-publish.yml'

        $document = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        [string[]]@($document['on'].Keys) | Should -Be @('push')
        [string[]]@($document['on']['push']['tags']) | Should -Be @('v*', 'prerelease-v*')
        $identity = Get-NamedJobStep -Document $document -JobName 'validate-release' `
            -StepName 'Validate tag event identity'
        [string]$identity['run'] | Should -Match "EVENT_NAME.*!= 'push'"
        [string]$identity['run'] | Should -Match "EVENT_REF_TYPE.*!= 'tag'"
        [string]$identity['run'] | Should -Match "EVENT_REF_PROTECTED.*!= 'true'"
        [string]$identity['run'] | Should -Match "EVENT_ACTOR.*EXPECTED_ACTOR"
        [string]$identity['run'] | Should -Match "EVENT_ACTOR_ID.*EXPECTED_ACTOR_ID"
    }

    It 'Authenticates source eligibility and exact governance without exposing the private key to source jobs' {
        $document = Get-WorkflowDocument -Name 'extension-provenance-signer.yml'
        $authorize = $document['jobs']['authorize']
        [string[]]@($authorize['permissions'].Keys) | Should -Be @('contents')
        [string]$authorize['permissions']['contents'] | Should -BeExactly 'read'
        [string]$authorize['environment'] | Should -BeExactly 'release-governance'
        [string[]]@($document['jobs']['package']['needs']) | Should -Be @('authorize')

        $document['on']['workflow_call'].Contains('secrets') | Should -BeFalse
        $token = Get-NamedJobStep -Document $document -JobName 'authorize' `
            -StepName 'Generate governance-read Release App token'
        [string]$token['with']['permission-administration'] | Should -BeExactly 'read'
        [string]$token['with']['private-key'] | Should -BeExactly '${{ secrets.RELEASE_APP_PRIVATE_KEY }}'

        $authorizeText = (Get-JobStepText -Document $document -JobName 'authorize') -join "`n"
        foreach ($contract in @('hve-core-release-please\[bot\]', '254602402', 'release-tags-creation-by-release-app',
                'release-tags-immutable', 'target == "tag"', 'enforcement == "active"',
            'source_type == "Repository"', 'conditions\.ref_name\.include',
            'conditions\.ref_name\.exclude', 'rules\[\]\.type', '/releases\?per_page=100',
            '/compare/\$EVENT_SHA\.\.\.\$BRANCH_SHA', 'Exact draft release identity',
            'bypass_actors', 'actor_type', 'actor_id', 'bypass_mode')) {
            $authorizeText | Should -Match $contract
        }

        foreach ($job in @('package', 'attest')) {
            $jobText = (Get-JobStepText -Document $document -JobName $job) -join "`n"
            $jobText | Should -Not -Match 'RELEASE_APP_PRIVATE_KEY|app-token\.outputs\.token'
        }

        $newSignerCallers = @(Get-ChildItem -LiteralPath $script:WorkflowDirectory -Filter '*.yml' |
            Select-String -Pattern 'uses:\s+.*extension-provenance-signer\.yml@')
        $newSignerCallers | Should -HaveCount 1
    }

    It 'Accepts the exact Release App and active tag rulesets before packaging' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'authorize' -StepName 'Authenticate release principal and governance'
        $result = Invoke-ReleaseAuthorizationShellStep -Body ([string]$step['run']) `
            -Environment $script:AuthorizationEnvironment -RulesetList $script:RulesetList `
            -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset
        $result.ExitCode | Should -Be 0
    }

    It 'Rejects an unexpected release actor before packaging' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'authorize' -StepName 'Authenticate release principal and governance'
        $environment = @{} + $script:AuthorizationEnvironment
        $environment['EVENT_ACTOR'] = 'octocat'
        $result = Invoke-ReleaseAuthorizationShellStep -Body ([string]$step['run']) `
            -Environment $environment -RulesetList $script:RulesetList `
            -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'expected Release App principal'
    }

    It 'Rejects invalid exact draft release state <Name> before packaging' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Name = 'absent'; Releases = '[]' }
        @{ Name = 'duplicate'; Releases = '[{"id":201,"tag_name":"v3.4.0","target_commitish":"1111111111111111111111111111111111111111","draft":true,"prerelease":false},{"id":202,"tag_name":"v3.4.0","target_commitish":"1111111111111111111111111111111111111111","draft":true,"prerelease":false}]' }
        @{ Name = 'wrong target'; Releases = '[{"id":201,"tag_name":"v3.4.0","target_commitish":"2222222222222222222222222222222222222222","draft":true,"prerelease":false}]' }
        @{ Name = 'published'; Releases = '[{"id":201,"tag_name":"v3.4.0","target_commitish":"1111111111111111111111111111111111111111","draft":false,"prerelease":false}]' }
        @{ Name = 'wrong channel'; Releases = '[{"id":201,"tag_name":"v3.4.0","target_commitish":"1111111111111111111111111111111111111111","draft":true,"prerelease":true}]' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'authorize' -StepName 'Authenticate release principal and governance'
        $result = Invoke-ReleaseAuthorizationShellStep -Body ([string]$step['run']) `
            -Environment $script:AuthorizationEnvironment -RulesetList $script:RulesetList `
            -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset `
            -ReleaseList $Releases
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Exact draft release identity does not match'
    }

    It 'Rejects a release commit outside the expected channel branch' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'authorize' -StepName 'Authenticate release principal and governance'
        $result = Invoke-ReleaseAuthorizationShellStep -Body ([string]$step['run']) `
            -Environment $script:AuthorizationEnvironment -RulesetList $script:RulesetList `
            -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset `
            -CompareStatus 'diverged'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'not contained in the expected release/stable branch'
    }

    It 'Rejects invalid governance state <Name> before packaging' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Name = 'missing ruleset'; List = '[{"id":101,"name":"release-tags-creation-by-release-app"}]'; Creation = $null; Immutable = $null; Error = 'match count 0' }
        @{ Name = 'inactive creation'; List = $null; Creation = '{"id":101,"name":"release-tags-creation-by-release-app","target":"tag","enforcement":"evaluate","conditions":{"ref_name":{"include":["refs/tags/v*","refs/tags/prerelease-v*"],"exclude":[]}},"rules":[{"type":"creation"}]}'; Immutable = $null; Error = 'exact active release-tag creation boundary' }
        @{ Name = 'excluded tag'; List = $null; Creation = '{"id":101,"name":"release-tags-creation-by-release-app","target":"tag","enforcement":"active","conditions":{"ref_name":{"include":["refs/tags/v*","refs/tags/prerelease-v*"],"exclude":["refs/tags/v3.4.0"]}},"rules":[{"type":"creation"}]}'; Immutable = $null; Error = 'exact active release-tag creation boundary' }
        @{ Name = 'missing creation bypass'; List = $null; Creation = '{"id":101,"name":"release-tags-creation-by-release-app","target":"tag","source_type":"Repository","source":"microsoft/hve-core","enforcement":"active","bypass_actors":[],"conditions":{"ref_name":{"include":["refs/tags/v*","refs/tags/prerelease-v*"],"exclude":[]}},"rules":[{"type":"creation"}]}'; Immutable = $null; Error = 'exact active release-tag creation boundary' }
        @{ Name = 'immutable bypass'; List = $null; Creation = $null; Immutable = '{"id":102,"name":"release-tags-immutable","target":"tag","source_type":"Repository","source":"microsoft/hve-core","enforcement":"active","bypass_actors":[{"actor_id":2646666,"actor_type":"Integration","bypass_mode":"always"}],"conditions":{"ref_name":{"include":["refs/tags/v*","refs/tags/prerelease-v*"],"exclude":[]}},"rules":[{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}]}'; Error = 'exact active release-tag immutability boundary' }
        @{ Name = 'mutable allocation'; List = $null; Creation = $null; Immutable = '{"id":102,"name":"release-tags-immutable","target":"tag","enforcement":"active","conditions":{"ref_name":{"include":["refs/tags/v*","refs/tags/prerelease-v*"],"exclude":[]}},"rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}'; Error = 'exact active release-tag immutability boundary' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-provenance-signer.yml') `
            -JobName 'authorize' -StepName 'Authenticate release principal and governance'
        $result = Invoke-ReleaseAuthorizationShellStep -Body ([string]$step['run']) `
            -Environment $script:AuthorizationEnvironment `
            -RulesetList $(if ($List) { $List } else { $script:RulesetList }) `
            -CreationRuleset $(if ($Creation) { $Creation } else { $script:CreationRuleset }) `
            -ImmutableRuleset $(if ($Immutable) { $Immutable } else { $script:ImmutableRuleset })
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match $Error
    }

    It 'Acknowledges only the trusted signer path for the Poutine checkout rule' -Tag 'Poutine' {
        $config = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.poutine.yml') -Raw -Encoding utf8 |
            ConvertFrom-Yaml
        $exceptions = @($config['skip'] | Where-Object {
                @($_['rule']) -contains 'untrusted_checkout_exec' -and
                @($_['path']) -contains '.github/workflows/extension-provenance-signer.yml'
            })
        $exceptions | Should -HaveCount 1
        @($exceptions[0].Keys | Sort-Object) | Should -Be @('job', 'path', 'rule')
        [string[]]@($exceptions[0]['job']) | Should -Be @('package')

        Get-WorkflowText -Name 'extension-provenance-signer.yml' |
            Should -Not -Match 'poutine:ignore'
    }

    It 'Verifies the event-default signer checkout before source execution' {
        $document = Get-WorkflowDocument -Name 'extension-provenance-signer.yml'
        $checkout = Get-NamedJobStep -Document $document -JobName 'package' -StepName 'Checkout code'
        $checkout['with'].Contains('ref') | Should -BeFalse
        $verify = Get-NamedJobStep -Document $document -JobName 'package' -StepName 'Verify checked-out source'
        [string]$verify['env']['EXPECTED_SOURCE'] | Should -BeExactly '${{ github.sha }}'
        [string]$verify['run'] | Should -Match 'git rev-parse HEAD'
        [string]$verify['run'] | Should -Match 'CHECKED_OUT_SOURCE.*EXPECTED_SOURCE'
    }

    It 'Checks out the run commit for release verification' {
        $document = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        $step = Get-NamedJobStep -Document $document -JobName 'verify-provenance' -StepName 'Checkout verification script'
        [string]$step['with']['ref'] | Should -BeExactly '${{ github.sha }}'
    }

    It 'Retains the tag identity gate that makes the run commit trusted' {
        $document = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        $identity = Get-NamedJobStep -Document $document -JobName 'validate-release' -StepName 'Validate tag source and committed release state'
        [string]$identity['run'] | Should -Match 'TAG_SHA.*EVENT_SHA'
        [string]$document['jobs']['validate-release']['outputs']['source-sha'] | Should -BeExactly '${{ steps.identity.outputs.source-sha }}'
        [string[]]@($document['jobs']['extension-provenance']['needs']) | Should -Contain 'validate-release'
        [string[]]@($document['jobs']['verify-provenance']['needs']) | Should -Contain 'validate-release'
    }
}

# Promotion validation reads through the API now, so the contracts that matter
# are the absence of pull-request Git transport and the immutability of the refs
# every read is pinned to.
Describe 'Immutable promotion validation' -Tag 'Unit' {
    $script:PromotionJobs = @(
        @{ Workflow = 'pr-validation.yml'; JobName = 'gate-completeness-check' }
        @{ Workflow = 'release-stable-publish.yml'; JobName = 'validate-trigger' }
    )

    It 'Uses no pull-request Git transport in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName
        @($steps | Where-Object { $_ -match 'git\s+fetch|git\s+pull|gh\s+pr\s+checkout|refs/pull/' }) | Should -HaveCount 0
    }

    It 'Pins every promotion content read to a resolved commit in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $text = (Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName) -join "`n"
        $refs = @([regex]::Matches($text, '\?ref=\$(?<name>[A-Za-z_]+)') | ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
        $refs | Should -Not -BeNullOrEmpty
        @($refs | Where-Object { $_ -notin @('HEAD_SHA', 'EVENT_SHA', 'BASELINE_SHA', 'SOURCE_SHA', 'STABLE_SHA', 'PRERELEASE_SHA') }) |
            Should -BeNullOrEmpty
    }

    It 'Bounds annotated tag peeling in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $text = (Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName) -join "`n"
        $text | Should -Match 'hop.*-lt 10'
        $text | Should -Match 'tag chain revisits'
        $text | Should -Match 'unsupported object type'
        $text | Should -Match 'did not peel to a commit'
    }

    It 'Proves containment through compare status rather than local ancestry in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $text = (Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName) -join "`n"
        $text | Should -Match 'compare/\$SOURCE_SHA\.\.\.'
        $text | Should -Match "'ahead'"
        $text | Should -Match "'identical'"
        $text | Should -Not -Match 'merge-base'
    }

    It 'Declares only the token scope each promotion job needs' {
        $gate = (Get-WorkflowDocument -Name 'pr-validation.yml')['jobs']['gate-completeness-check']['permissions']
        [string]$gate['contents'] | Should -BeExactly 'read'
        [string]$gate['pull-requests'] | Should -BeExactly 'read'
        @($gate.Keys) | Should -HaveCount 2

        # The Stable trigger compares immutable event SHAs, so it needs no
        # pull-request scope at all.
        $trigger = (Get-WorkflowDocument -Name 'release-stable-publish.yml')['jobs']['validate-trigger']['permissions']
        [string]$trigger['contents'] | Should -BeExactly 'read'
        @($trigger.Keys) | Should -HaveCount 1
    }

    It 'Retains every Stable trigger gate without a validation checkout' {
        $document = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        $names = [string[]]@($document['jobs']['validate-trigger']['steps'] | ForEach-Object { [string]$_['name'] })
        $names | Should -Not -Contain 'Checkout Stable trigger validation workspace'

        $steps = Get-JobStepText -Document $document -JobName 'validate-trigger'
        foreach ($gate in @(
                'is not a merged same-repository pull request',
                'does not match event SHA',
                'is not an authorized Stable release head',
                'is not a published, non-draft GitHub PreRelease',
                'but the PreRelease manifest carries',
                'is not contained in release/prerelease',
                'does not contain selected source',
                'still carries release-as')) {
            @($steps | Where-Object { $_ -match [regex]::Escape($gate) }) |
                Should -Not -BeNullOrEmpty -Because "the '$gate' check must survive the API migration"
        }
    }
}

# The release preparation tree is untrusted data. These contracts keep the write
# credential out of it and bind the push to the commit the tree was built from.
Describe 'Release preparation transport' -Tag 'Unit' {
    $script:SyncWorkflows = @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    )

    It 'Fetches release preparation data without a credential in <Workflow>' -ForEach $script:SyncWorkflows {
        $document = Get-WorkflowDocument -Name $Workflow
        $names = [string[]]@($document['jobs']['sync-release-pr']['steps'] | ForEach-Object { [string]$_['name'] })
        $names | Should -Not -Contain 'Checkout release preparation data'

        $checkouts = @($document['jobs']['sync-release-pr']['steps'] | Where-Object { [string]$_['uses'] -match 'actions/checkout@' })
        $checkouts | Should -HaveCount 1
        [string]$checkouts[0]['with']['ref'] | Should -BeExactly '${{ github.sha }}'
        [string]$checkouts[0]['with']['persist-credentials'] | Should -Match '^[Ff]alse$'

        $prepare = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' `
            -StepName 'Resolve and fetch the release preparation commit'
        [string]$prepare['run'] | Should -Match 'credential\.helper= fetch'
        [string]$prepare['run'] | Should -Not -Match 'x-access-token'
    }

    It 'Binds the preparation tree to an API-resolved immutable commit in <Workflow>' -ForEach $script:SyncWorkflows {
        $prepare = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'sync-release-pr' `
            -StepName 'Resolve and fetch the release preparation commit'
        $run = [string]$prepare['run']
        $run | Should -Match 'release-please--'
        $run | Should -Match 'is not a managed release preparation branch'
        $run | Should -Match 'did not resolve to a commit SHA'
        $run | Should -Match 'moved from .* during preparation'
        $run | Should -Match 'commit=\$resolved_object'
    }

    It 'Transforms the preparation tree without the write token in <Workflow>' -ForEach $script:SyncWorkflows {
        $transform = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'sync-release-pr' `
            -StepName 'Update committed version fields and retire the promotion intent'
        $transformEnv = if ($transform.Contains('env')) { $transform['env'] } else { $null }
        $envKeys = if ($null -ne $transformEnv) { [string[]]@($transformEnv.Keys) } else { @() }
        @($envKeys | Where-Object { $_ -match 'TOKEN' }) | Should -BeNullOrEmpty
        [string]$transform['run'] | Should -Not -Match 'git push'
        [string]$transform['run'] | Should -Match 'committed=false'
        [string]$transform['run'] | Should -Match 'committed=true'
    }

    It 'Scopes the write token to a lease-guarded push in <Workflow>' -ForEach $script:SyncWorkflows {
        $document = Get-WorkflowDocument -Name $Workflow
        $push = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' `
            -StepName 'Push the synchronized release preparation commit'
        [string]$push['if'] | Should -Match "steps\.transform\.outputs\.committed == 'true'"
        [string]$push['env']['GH_APP_TOKEN'] | Should -BeExactly '${{ steps.app-token.outputs.token }}'
        [string]$push['run'] | Should -Match '--force-with-lease="refs/heads/\$RELEASE_BRANCH:\$EXPECTED_COMMIT"'

        $tokenSteps = @($document['jobs']['sync-release-pr']['steps'] | Where-Object {
                $stepEnv = if ($_.Contains('env')) { $_['env'] } else { $null }
                $null -ne $stepEnv -and @($stepEnv.Keys) -contains 'GH_APP_TOKEN'
            })
        $tokenSteps | Should -HaveCount 1
    }
}

Describe 'Retained provenance and SBOM assurance' -Tag 'Unit', 'SignerIsolation' {
    BeforeAll {
        $script:ProvenanceDocument = Get-WorkflowDocument -Name 'extension-provenance-signer.yml'
        $script:ProvenanceSteps = Get-JobStepText -Document $script:ProvenanceDocument -JobName 'attest'
    }

    It 'Attests one VSIX with build provenance, per-VSIX SBOM, and dependency SBOM' {
        [string[]]@($script:ProvenanceDocument['jobs'].Keys | Sort-Object) | Should -Be @('attest', 'authorize', 'package')

        $packageSteps = Get-JobStepText -Document $script:ProvenanceDocument -JobName 'package'
        @($packageSteps | Where-Object { $_ -match 'anchore/sbom-action@' }) | Should -HaveCount 2
        @($script:ProvenanceSteps | Where-Object { $_ -match 'actions/attest-build-provenance@' }) | Should -HaveCount 1
        @($script:ProvenanceSteps | Where-Object { $_ -match 'actions/attest@' }) | Should -HaveCount 2

        $text = Get-WorkflowText -Name 'extension-provenance-signer.yml'
        $text | Should -Match 'sbom-path: input/\$\{\{ steps\.policy\.outputs\.sbom-name \}\}'
        $text | Should -Match 'sbom-path: input/dependencies\.spdx\.json'
    }

    It 'Resolves the built VSIX through the shared resolver' {
        $packageSteps = Get-JobStepText -Document $script:ProvenanceDocument -JobName 'package'
        @($packageSteps | Where-Object { $_ -match 'Resolve-VsixFile\.ps1 -DirectoryPath \$env:VSIX_DIRECTORY' }) | Should -HaveCount 1
        ($script:ProvenanceSteps -join "`n") | Should -Not -Match 'Resolve-VsixFile\.ps1'
    }

    It 'Exports fixed attestation sidecars without mutating a release' {
        $text = Get-WorkflowText -Name 'extension-provenance-signer.yml'
        $text | Should -Match 'attested/\$\{\{ steps\.policy\.outputs\.vsix-name \}\}\.sigstore\.json'
        $text | Should -Match 'attested/\$\{\{ steps\.policy\.outputs\.vsix-name \}\}\.intoto\.jsonl'
        ($script:ProvenanceSteps -join "`n") | Should -Not -Match 'gh release'
    }

    It 'Separates unprivileged packaging from privileged attestation' {
        $package = $script:ProvenanceDocument['jobs']['package']
        [string[]]@($package['permissions'].Keys) | Should -Be @('contents')
        [string]$package['permissions']['contents'] | Should -BeExactly 'read'
        [string[]]@($package['needs']) | Should -Be @('authorize')

        $attest = $script:ProvenanceDocument['jobs']['attest']
        [string[]]@($attest['needs']) | Should -Be @('authorize', 'package')
        [string[]]@($attest['permissions'].Keys) | Sort-Object |
            Should -Be @('artifact-metadata', 'attestations', 'contents', 'id-token')
        [string]$attest['permissions']['contents'] | Should -BeExactly 'read'
        [string]$attest['permissions']['id-token'] | Should -BeExactly 'write'
        [string]$attest['permissions']['attestations'] | Should -BeExactly 'write'
        [string]$attest['permissions']['artifact-metadata'] | Should -BeExactly 'write'

        $packageText = (Get-JobStepText -Document $script:ProvenanceDocument -JobName 'package') -join "`n"
        $packageText | Should -Match 'npm ci --ignore-scripts=false'
        $packageText | Should -Match 'Package-Extension\.ps1'
        $packageText | Should -Not -Match 'actions/attest'

        $attestText = $script:ProvenanceSteps -join "`n"
        $attestText | Should -Not -Match 'npm ci'
        $attestText | Should -Not -Match 'Package-Extension\.ps1'
        $attestText | Should -Not -Match 'actions/checkout@|\./scripts/|\./\.github/actions/'
    }

    It 'Requires the attestation source ref to be this run commit' {
        $script:ProvenanceDocument['on']['workflow_call']['inputs']['source-ref']['required'] | Should -BeTrue
        @($script:ProvenanceSteps | Where-Object { $_ -match 'inputs do not match the immutable release event identity' }) | Should -HaveCount 1
    }

    It 'Accepts only the exact fixed attestation input and local digests' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document $script:ProvenanceDocument -JobName 'attest' `
            -StepName 'Validate fixed attestation input'
        $result = Invoke-AttestationInputShellStep -Body ([string]$step['run'])
        $result.ExitCode | Should -Be 0
    }

    It 'Rejects forged attestation manifest field <Name>' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Name = 'source SHA'; Mutate = { param($Manifest) $Manifest.sourceSha = '2222222222222222222222222222222222222222' } }
        @{ Name = 'release tag'; Mutate = { param($Manifest) $Manifest.releaseTag = 'v3.6.0' } }
        @{ Name = 'channel'; Mutate = { param($Manifest) $Manifest.channel = 'PreRelease' } }
        @{ Name = 'version'; Mutate = { param($Manifest) $Manifest.version = '3.6.0' } }
        @{ Name = 'basename'; Mutate = { param($Manifest) $Manifest.files[0].name = '../hve-core-3.4.0.vsix' } }
        @{ Name = 'digest'; Mutate = { param($Manifest) $Manifest.files[0].sha256 = ('a' * 64) } }
        @{ Name = 'duplicate'; Mutate = { param($Manifest) $Manifest.files[1] = $Manifest.files[0] } }
        @{ Name = 'unknown policy'; Mutate = { param($Manifest) $Manifest['unexpected'] = 'value' } }
    ) {
        $step = Get-NamedJobStep -Document $script:ProvenanceDocument -JobName 'attest' `
            -StepName 'Validate fixed attestation input'
        $result = Invoke-AttestationInputShellStep -Body ([string]$step['run']) -ManifestMutation $Mutate
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'manifest does not match frozen attestation policy'
    }

    It 'Rejects an extra attestation input file before signing' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document $script:ProvenanceDocument -JobName 'attest' `
            -StepName 'Validate fixed attestation input'
        $result = Invoke-AttestationInputShellStep -Body ([string]$step['run']) -ExtraFile 'alias.vsix'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'exact fixed file set'
    }

    It 'Verifies release provenance for one VSIX in the tag producer' {
        $document = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        $steps = Get-JobStepText -Document $document -JobName 'verify-provenance'
        @($steps | Where-Object { $_ -match 'Invoke-ProvenanceVerification\.ps1' }) | Should -HaveCount 1
        $download = Get-NamedJobStep -Document $document -JobName 'verify-provenance' `
            -StepName 'Download attested extension artifact'
        [string]$download['with']['name'] | Should -BeExactly 'extension-attested'
        [string]$download['with']['digest-mismatch'] | Should -BeExactly 'error'
    }

    It 'Generates the dependency SBOM only after authorization in the read-only package job' {
        $document = Get-WorkflowDocument -Name 'extension-provenance-signer.yml'
        $steps = Get-JobStepText -Document $document -JobName 'package'
        $dependencySbom = Get-NamedJobStep -Document $document -JobName 'package' -StepName 'Generate dependency SBOM'
        [string]$dependencySbom['with']['output-file'] | Should -BeExactly 'attestation-input/dependencies.spdx.json'
        @($steps | Where-Object { $_ -match 'gh release upload' }) | Should -HaveCount 0

        $artifactNames = [string[]]@($document['jobs']['attest']['steps'] |
                Where-Object { $_.Contains('with') -and $_['with'].Contains('name') } |
                ForEach-Object { [string]$_['with']['name'] })
        $artifactNames | Should -Contain 'sbom-dependencies'
        $attestedUpload = Get-NamedJobStep -Document $document -JobName 'attest' -StepName 'Upload fixed attested artifact'
        [string]$attestedUpload['with']['path'] | Should -Match 'attested/dependencies\.spdx\.json'

        $producer = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        $producer['jobs'].Contains('generate-dependency-sbom') | Should -BeFalse
        [string[]]@($producer['jobs']['vex-attest']['needs']) | Should -Contain 'extension-provenance'
        [string[]]@($producer['jobs']['sbom-diff']['needs']) | Should -Contain 'extension-provenance'
    }
}

Describe 'Retained marketplace publication' -Tag 'Unit' {
    BeforeAll {
        $script:PublishDocument = Get-WorkflowDocument -Name 'extension-marketplace-publish.yml'
    }

    It 'Runs validation, verification, preparation, and publication in that order' {
        # Parsed YAML mappings carry no key order, so membership and the needs
        # closure express the sequence instead.
        [string[]]@($script:PublishDocument['jobs'].Keys) | Sort-Object |
            Should -Be @('prepare-publisher', 'publish', 'validate-inputs', 'verify')
        [string[]]@($script:PublishDocument['jobs']['verify']['needs']) | Should -Be @('validate-inputs')
        [string[]]@($script:PublishDocument['jobs']['prepare-publisher']['needs']) | Should -Be @('validate-inputs', 'verify')
        [string[]]@($script:PublishDocument['jobs']['publish']['needs']) | Should -Be @('validate-inputs', 'verify', 'prepare-publisher')
    }

    It 'Requires only the release tag and channel flag' {
        $inputs = $script:PublishDocument['on']['workflow_call']['inputs']
        [string[]]@($inputs.Keys) | Sort-Object | Should -Be @('pre-release', 'tag')
        $inputs['tag']['required'] | Should -BeTrue
    }

    It 'Validates the channel tag namespace and minor parity before any credential' {
        $steps = Get-JobStepText -Document $script:PublishDocument -JobName 'validate-inputs'
        @($steps | Where-Object { $_ -match 'Release tag does not match the selected channel' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'requires an \$expected_parity_label minor version' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'azure/login@' }) | Should -HaveCount 0
    }

    It 'Downloads exactly one attested hve-core VSIX from the release tag' {
        $steps = Get-JobStepText -Document $script:PublishDocument -JobName 'verify'
        @($steps | Where-Object { $_ -match "--pattern 'hve-core-\*\.vsix'" }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'Expected exactly one hve-core VSIX' }) | Should -HaveCount 1
    }

    It 'Verifies attested provenance in both the verify and publish jobs' {
        foreach ($job in @('verify', 'publish')) {
            $steps = Get-JobStepText -Document $script:PublishDocument -JobName $job
            @($steps | Where-Object { $_ -match 'gh attestation verify "\$VSIX_FILE"' }) |
                Should -HaveCount 1 -Because "job '$job' verifies before it trusts the artifact"
            @($steps | Where-Object { $_ -match '--signer-workflow "?\$SIGNER_WORKFLOW"?' }) | Should -HaveCount 1
            @($steps | Where-Object { $_ -match '--source-digest "\$RELEASE_DIGEST"' }) | Should -HaveCount 1
        }
    }

    # Publish credentials become active only in the protected environment job,
    # and the toolchain install that runs lifecycle scripts stays outside it.
    It 'Holds the marketplace credentials boundary' {
        [string]$script:PublishDocument['jobs']['publish']['environment'] | Should -BeExactly 'marketplace'
        $script:PublishDocument['jobs']['prepare-publisher'].Contains('environment') | Should -BeFalse

        $prepareSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'prepare-publisher'
        @($prepareSteps | Where-Object { $_ -match 'npm ci .*--ignore-scripts=false' }) | Should -HaveCount 1

        $publishSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'publish'
        @($publishSteps | Where-Object { $_ -match 'npm ci' }) | Should -HaveCount 0
        @($publishSteps | Where-Object { $_ -match 'azure/login@' }) | Should -HaveCount 1
        @($publishSteps | Where-Object { $_ -match '"\$VSCE_BIN" "\$\{arguments\[@\]\}"' }) | Should -HaveCount 1
    }

    It 'Binds publication to the one hve-core identity inside the protected job' {
        $publishSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'publish'
        @($publishSteps | Where-Object { $_ -match ([regex]::Escape("EXTENSION_NAME='hve-core'")) }) | Should -HaveCount 1
        @($publishSteps | Where-Object { $_ -match '\.psm1|Get-ExtensionIdentity|Get-ExtensionVsixGlob' }) | Should -HaveCount 0
    }

    It 'Carries the channel pre-release flag into vsce' {
        $publishSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'publish'
        @($publishSteps | Where-Object { $_ -match 'arguments\+=\(--pre-release\)' }) | Should -HaveCount 1
    }

    It 'Publishes only from the marketplace publish workflow' {
        foreach ($workflow in $script:PackagingWorkflow) {
            if ($workflow -eq 'extension-marketplace-publish.yml') { continue }
            (Get-WorkflowText -Name $workflow) |
                Should -Not -Match 'vsce.*publish' -Because "$workflow must route publication through the shared workflow"
        }
    }

    It 'Feeds the released tag into the publish workflow from <Workflow>' -ForEach @(
        @{ Workflow = 'release-marketplace-prerelease.yml'; Source = 'validate-version'; PreRelease = $true }
        @{ Workflow = 'release-marketplace-stable.yml'; Source = 'normalize-version'; PreRelease = $false }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $publish = $document['jobs']['publish']
        [string]$publish['uses'] | Should -BeExactly './.github/workflows/extension-marketplace-publish.yml'
        [string]$publish['with']['tag'] | Should -BeExactly "`${{ needs.$Source.outputs.tag }}"
        $publish['with']['pre-release'] | Should -Be $PreRelease
        $publish['with'].Contains('packages-matrix') | Should -BeFalse
        [string]$publish['if'] | Should -Match 'dry-run'
    }

    It 'Verifies the released catalog version before publishing in <Workflow>' -ForEach @(
        @{ Workflow = 'release-marketplace-prerelease.yml' }
        @{ Workflow = 'release-marketplace-stable.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $document['jobs'].Contains('verify-catalog') | Should -BeTrue
        $document['jobs'].Contains('discover') | Should -BeFalse
        $steps = Get-JobStepText -Document $document -JobName 'verify-catalog'
        @($steps | Where-Object { $_ -match 'Catalog version \$catalog_version at the release ref does not match' }) | Should -HaveCount 1
    }
}

Describe 'Retained release reconciliation and OpenVEX' -Tag 'Unit', 'ReleaseRecovery' {
    It 'Reconciles a matching published release against channel-specific fixed assets' {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-vsix-publish.yml') `
            -JobName 'validate-release' -StepName 'Verify published release assets'
        $run = [string]$step['run']
        $run | Should -Match 'Assert-ReleaseAssetSet\.ps1'
        $run | Should -Match 'dependencies\.spdx\.json'
        $run | Should -Match 'hve-core\.openvex\.json'
        $run | Should -Match 'dependency-diff\.md'
        $run | Should -Match "CHANNEL.*Stable"
        [string]$step['if'] | Should -Match "release-state == 'published'"
    }

    It 'Verifies every committed version field at the tag event commit' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'release-vsix-publish.yml') -JobName 'validate-release'
        $verify = @($steps | Where-Object { $_ -match 'but the tag declares \$RELEASE_VERSION' })
        $verify | Should -HaveCount 1
        foreach ($path in @('package\.json', 'package-lock\.json', 'release-please.*manifest\.json',
                'extension/templates/package\.template\.json', 'plugin\.json',
                '\.github/plugin/marketplace\.json:\.metadata\.version',
                '\.github/plugin/marketplace\.json:\.plugins\[0\]\.version')) {
            $verify[0] | Should -Match $path
        }
    }

    It 'Attests and uploads the Stable OpenVEX document' {
        $document = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        [string]$document['jobs']['vex-attest']['uses'] | Should -BeExactly './.github/workflows/vex-attest.yml'
        [string]$document['jobs']['vex-attest']['with']['sbom-artifact'] | Should -BeExactly 'sbom-dependencies'
        [string]$document['jobs']['vex-attest']['if'] | Should -Match "channel == 'Stable'"

        $verifySteps = Get-JobStepText -Document $document -JobName 'verify-provenance'
        @($verifySteps | Where-Object { $_ -match "\-p 'hve-core\.openvex\.json'" }) | Should -HaveCount 1
        [string[]]@($document['jobs']['verify-provenance']['needs']) | Should -Contain 'vex-attest'
        [string[]]@($document['jobs']['publish-release']['needs']) | Should -Contain 'vex-attest'
    }

    It 'Documents VSIX and VEX verification without a plugin ZIP instruction' {
        $notes = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-vsix-publish.yml') `
                -JobName 'append-verification-notes' -StepName 'Append verification section to release notes')['run']
        $notes | Should -Match 'gh attestation verify <file>\.vsix'
        $notes | Should -Match 'gh attestation verify hve-core\.openvex\.json'
        $notes | Should -Not -Match '<file>\.zip'
    }

    It 'Applies one byte-stable managed verification block across sequential reruns' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-vsix-publish.yml') `
            -JobName 'append-verification-notes' -StepName 'Append verification section to release notes'
        $initial = "Release-please prose.`n`nMaintainer prose.`n"
        $once = Invoke-ReleaseNotesShellStep -Body ([string]$step['run']) -InitialBody $initial -RunCount 1
        $twice = Invoke-ReleaseNotesShellStep -Body ([string]$step['run']) -InitialBody $initial -RunCount 2

        [int[]]$once.ExitCode | Should -Be @(0)
        [int[]]$twice.ExitCode | Should -Be @(0, 0)
        $once.Body | Should -BeExactly $twice.Body
        $twice.Body.StartsWith($initial, [System.StringComparison]::Ordinal) | Should -BeTrue
        @([regex]::Matches($twice.Body, '<!-- hve-core:verification:start -->')) | Should -HaveCount 1
        @([regex]::Matches($twice.Body, '<!-- hve-core:verification:end -->')) | Should -HaveCount 1
        $twice.EditCount | Should -Be 2
    }

    It 'Replaces one managed block while preserving surrounding prose exactly' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-vsix-publish.yml') `
            -JobName 'append-verification-notes' -StepName 'Append verification section to release notes'
        $prefix = "Before managed block.`n`n"
        $suffix = "`n`nAfter managed block.`n"
        $initial = $prefix + '<!-- hve-core:verification:start -->old<!-- hve-core:verification:end -->' + $suffix
        $result = Invoke-ReleaseNotesShellStep -Body ([string]$step['run']) -InitialBody $initial

        $result.ExitCode | Should -Be @(0)
        $result.Body.StartsWith($prefix, [System.StringComparison]::Ordinal) | Should -BeTrue
        $result.Body.EndsWith($suffix, [System.StringComparison]::Ordinal) | Should -BeTrue
        $result.Body | Should -Not -Match '>old<'
    }

    It 'Rejects malformed managed marker state <Name> before editing' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Name = 'lone start'; Body = 'before<!-- hve-core:verification:start -->after' }
        @{ Name = 'lone end'; Body = 'before<!-- hve-core:verification:end -->after' }
        @{ Name = 'reversed'; Body = '<!-- hve-core:verification:end --><!-- hve-core:verification:start -->' }
        @{ Name = 'unknown marker'; Body = '<!-- hve-core:verification:begin --><!-- hve-core:verification:end -->' }
        @{ Name = 'nested markers'; Body = '<!-- hve-core:verification:start --><!-- hve-core:verification:start --><!-- hve-core:verification:end --><!-- hve-core:verification:end -->' }
        @{ Name = 'duplicate pairs'; Body = '<!-- hve-core:verification:start --><!-- hve-core:verification:end --><!-- hve-core:verification:start --><!-- hve-core:verification:end -->' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-vsix-publish.yml') `
            -JobName 'append-verification-notes' -StepName 'Append verification section to release notes'
        $result = Invoke-ReleaseNotesShellStep -Body ([string]$step['run']) -InitialBody $Body

        $result.ExitCode | Should -Not -Be @(0)
        $result.EditCount | Should -Be 0
        $result.Body | Should -BeExactly $Body
    }

    It 'Skips every artifact-producing chain for a matching published release' {
        $document = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        foreach ($job in @('extension-provenance', 'vex-attest', 'sbom-diff', 'append-verification-notes')) {
            [string]$document['jobs'][$job]['if'] |
                Should -Match "release-state == 'draft'" -Because "job '$job' must not rebuild a published release"
        }
    }

    It 'Leaves both pull-request workflows with pre-tag jobs only' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        [string[]]@($document['jobs'].Keys) | Sort-Object |
            Should -Be @('release-please', 'sync-release-pr', 'validate-trigger')
        (Get-WorkflowText -Name $Workflow) | Should -Not -Match 'extension-vsix|sbom-dependencies|attest-build-provenance|vex-attest|verify-provenance|publish-release|close-milestone'
    }
}

Describe 'Release-please ownership and promotion transforms' -Tag 'Unit' {
    It 'Versions root plugin.json in <Config>' -ForEach @(
        @{ Config = 'release-please-config.json' }
        @{ Config = 'release-please-prerelease-config.json' }
    ) {
        $path = Join-Path $script:RepositoryRoot $Config
        $config = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
        $extraFiles = @($config.packages.'.'.'extra-files')
        @($extraFiles | Where-Object { $_.path -eq 'plugin.json' -and $_.jsonpath -eq '$.version' }) |
            Should -HaveCount 1
        @($extraFiles | Where-Object { $_.path -eq '.github/plugin.json' }) |
            Should -HaveCount 0
    }

    It 'Creates no tag or GitHub release outside release-please in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'gh release create'
        $text | Should -Not -Match 'git tag'
        $text | Should -Not -Match 'git push .*refs/tags'
    }

    It 'Runs release-please as the sole release pull request and tag creator in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'release-please'
        @($steps | Where-Object { $_ -match 'googleapis/release-please-action@' }) | Should -HaveCount 1
    }

    It 'Normalizes versions and syncs the plugin manifest during <Workflow> promotion' -ForEach @(
        @{ Workflow = 'release-prerelease-prepare.yml'; Job = 'prepare-promotion'; Step = 'Refresh the promotion head' }
        @{ Workflow = 'release-stable.yml'; Job = 'prepare-promotion'; Step = 'Refresh the promotion head' }
    ) {
        $run = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) -JobName $Job -StepName $Step)['run']
        $run | Should -Match 'scripts/plugins/Sync-PluginManifest\.ps1'
        $run | Should -Match 'scripts/release/Set-RepositoryVersion\.ps1'
        $run | Should -Match '-Version "\$TARGET_VERSION"'
        $run | Should -Match '-RepoRoot "\$PWD"'

        $versionPosition = $run.IndexOf('scripts/release/Set-RepositoryVersion.ps1', [System.StringComparison]::Ordinal)
        $syncPosition = $run.IndexOf('scripts/plugins/Sync-PluginManifest.ps1', [System.StringComparison]::Ordinal)
        $finalCheckPosition = $run.LastIndexOf('scripts/plugins/Sync-PluginManifest.ps1', [System.StringComparison]::Ordinal)
        $versionPosition | Should -BeGreaterThan -1
        $syncPosition | Should -BeGreaterThan $versionPosition
        $finalCheckPosition | Should -BeGreaterThan $syncPosition
        $run.Substring($finalCheckPosition) | Should -Match '-Check'
    }

    It 'Stages only the Stable release-owned files' {
        $run = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-stable.yml') `
                -JobName 'prepare-promotion' -StepName 'Refresh the promotion head')['run']
        $run | Should -Match 'RELEASE_OWNED_FILES=\('
        $run | Should -Match 'git add -- "\$\{RELEASE_OWNED_FILES\[@\]\}"'
        $run | Should -Not -Match 'git add --all'
    }

    It 'Checks out only trusted release tooling from main in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) `
            -JobName 'prepare-promotion' -StepName 'Checkout trusted release tooling'
        [string]$step['with']['ref'] | Should -BeExactly 'main'
        $sparse = [string[]]@(([string]$step['with']['sparse-checkout']).Split("`n") |
                ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $sparse | Should -Be @(
            'scripts/release/Resolve-ReleasePromotionVersion.ps1'
            'scripts/release/Set-RepositoryVersion.ps1'
            'scripts/plugins/Sync-PluginManifest.ps1'
        )
    }

    It 'Restores release-owned files without a candidate record in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
    ) {
        $run = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) `
                -JobName 'prepare-promotion' -StepName 'Refresh the promotion head')['run']
        $run | Should -Match "restore_from_base required CHANGELOG\.md \.github/plugin/marketplace\.json"
        $run | Should -Match "'plugin\.json'"
        $run | Should -Not -Match 'release-candidate\.json'
    }

    It 'Syncs the managed release preparation branch through the bounded scripts in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' `
            -StepName 'Update committed version fields and retire the promotion intent'
        $run = [string]$step['run']
        $run | Should -Match 'scripts/plugins/Sync-PluginManifest\.ps1'
        $run | Should -Match 'scripts/release/Set-RepositoryVersion\.ps1'
        $run | Should -Match "del\(\.packages\[\`"\.\`"\]\[\`"release-as\`"\]\)"
        $run | Should -Not -Match 'release-candidate\.json'

        $checkout = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' -StepName 'Checkout trusted release updater'
        $sparse = [string[]]@(([string]$checkout['with']['sparse-checkout']).Split("`n") |
                ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $sparse | Should -Be @(
            'scripts/release/Set-RepositoryVersion.ps1'
            'scripts/plugins/Sync-PluginManifest.ps1'
        )
    }

    It 'Retains the PreRelease promotion, branch, and release-as gates in pr-validation.yml' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'pr-validation.yml') -JobName 'gate-completeness-check'
        @($steps | Where-Object { $_ -match 'is not the canonical promotion head' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'PreRelease candidate \$CANDIDATE has an even minor' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'Stable candidate \$CANDIDATE has an odd minor' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'the PreRelease release identity is occupied' }) | Should -HaveCount 1
    }

    It 'Publishes the release only after provenance verification in the tag producer' {
        $document = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        [string[]]@($document['jobs']['publish-release']['needs']) | Should -Contain 'verify-provenance'
        $steps = Get-JobStepText -Document $document -JobName 'publish-release'
        @($steps | Where-Object { $_ -match 'gh release edit .*--draft=false' }) | Should -HaveCount 1
    }
}

Describe 'Sole post-tag release producer' -Tag 'Unit' {
    BeforeAll {
        $script:ReleaseProducer = Get-WorkflowDocument -Name 'release-vsix-publish.yml'
        $script:ReleaseProducerText = Get-WorkflowText -Name 'release-vsix-publish.yml'
    }

    It 'Triggers only for Stable and PreRelease tag pushes with tag-scoped concurrency' {
        [string[]]@($script:ReleaseProducer['on'].Keys) | Should -Be @('push')
        [string[]]@($script:ReleaseProducer['on']['push']['tags']) | Should -Be @('v*', 'prerelease-v*')
        [string]$script:ReleaseProducer['concurrency']['group'] | Should -BeExactly 'release-vsix-${{ github.ref }}'
        $script:ReleaseProducer['concurrency']['cancel-in-progress'] | Should -BeFalse
    }

    It 'Enforces exact tag grammar, parity, protected tag source, and branch containment' {
        $identity = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Validate tag event identity')['run']
        $identity | Should -Match "EVENT_NAME.*push"
        $identity | Should -Match "EVENT_REF_TYPE.*tag"
        $identity | Should -Match 'EVENT_REF_PROTECTED'
        $identity | Should -Match '\^v\(\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\)\$'
        $identity | Should -Match '\^prerelease-v'
        $identity | Should -Match 'Stable version .* odd minor'
        $identity | Should -Match 'PreRelease version .* even minor'

        $source = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Validate tag source and committed release state')['run']
        $source | Should -Match 'refs/tags/\$RELEASE_TAG\^\{commit\}'
        $source | Should -Match 'TAG_SHA.*EVENT_SHA'
        $source | Should -Match 'merge-base --is-ancestor "\$EVENT_SHA" HEAD'
        $source | Should -Match 'stale release-as'
        $source | Should -Match 'CHANGELOG\.md has no release entry'
    }

    It 'Uses exactly twelve discovery attempts and ten-second waits only for absence' {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $discovery | Should -Match 'seq 1 12'
        $discovery | Should -Match 'gh api --paginate --slurp'
        $discovery | Should -Match 'length > 0 and all\(\.\[\]; type == "array"\)'
        $discovery | Should -Match '\[\.\[\]\[\] \| select'
        $discovery | Should -Match 'attempt.*-lt 12'
        $discovery | Should -Match 'sleep 10'
        $discovery.IndexOf('MATCH_COUNT" -eq 1', [System.StringComparison]::Ordinal) |
            Should -BeLessThan $discovery.IndexOf('sleep 10', [System.StringComparison]::Ordinal)
        $discovery | Should -Match 'API failed'
        $discovery | Should -Match 'malformed response'
        $discovery | Should -Match 'matches \$MATCH_COUNT GitHub releases'
        $discovery | Should -Match 'release target .* does not match'
        $discovery | Should -Match 'prerelease state .* does not match'
        $discovery | Should -Match 'absent after exactly 12'
    }

    It 'Discovers the exact draft after bounded absence retries' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = '[{"id":123,"tag_name":"v3.4.0","target_commitish":"' + $sourceSha + '","draft":true,"prerelease":false}]'
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @('[[]]', '[[]]', "[$release]") -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = $sourceSha
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Be 0
        $result.AttemptCount | Should -Be 3
        $result.GithubOutput | Should -Match 'release-id=123'
        $result.GithubOutput | Should -Match 'release-state=draft'
    }

    It 'Classifies an exact published PreRelease without rebuilding artifacts' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = '[{"id":124,"tag_name":"prerelease-v3.5.0","target_commitish":"' + $sourceSha + '","draft":false,"prerelease":true}]'
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @("[$release]") -Environment @{
            EXPECTED_CHANNEL = 'PreRelease'
            EXPECTED_SHA     = $sourceSha
            EXPECTED_TAG     = 'prerelease-v3.5.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Be 0
        $result.AttemptCount | Should -Be 1
        $result.GithubOutput | Should -Match 'release-id=124'
        $result.GithubOutput | Should -Match 'release-state=published'
    }

    It 'Fails release discovery immediately on an API error' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @('[[]]') -ApiFailureAttempt 1 -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = '1111111111111111111111111111111111111111'
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.AttemptCount | Should -Be 1
        $result.Output | Should -Match 'Release discovery API failed on attempt 1'
    }

    It 'Fails release discovery on a malformed API response' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @('{"not":"an-array"}') -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = '1111111111111111111111111111111111111111'
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.AttemptCount | Should -Be 1
        $result.Output | Should -Match 'malformed response on attempt 1'
    }

    It 'Fails release discovery when slurped pagination returns no pages' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @('[]') -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = '1111111111111111111111111111111111111111'
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.AttemptCount | Should -Be 1
        $result.Output | Should -Match 'malformed response on attempt 1'
    }

    It 'Fails release discovery when a later slurped page is malformed' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @('[[ ],{"not":"a-page"}]') -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = '1111111111111111111111111111111111111111'
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.AttemptCount | Should -Be 1
        $result.Output | Should -Match 'malformed response on attempt 1'
    }

    It 'Finds an exact release on page two' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $sourceSha = '1111111111111111111111111111111111111111'
        $nonmatch = '{"id":122,"tag_name":"v3.2.0","target_commitish":"' + $sourceSha + '","draft":false,"prerelease":false}'
        $match = '{"id":123,"tag_name":"v3.4.0","target_commitish":"' + $sourceSha + '","draft":true,"prerelease":false}'
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @("[[$nonmatch],[$match]]") -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = $sourceSha
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Be 0
        $result.AttemptCount | Should -Be 1
        $result.GithubOutput | Should -Match 'release-id=123'
    }

    It 'Fails release discovery when a tag matches multiple releases' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = '{"id":123,"tag_name":"v3.4.0","target_commitish":"' + $sourceSha + '","draft":true,"prerelease":false}'
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @("[[$release],[$release]]") -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = $sourceSha
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.AttemptCount | Should -Be 1
        $result.Output | Should -Match 'matches 2 GitHub releases'
    }

    It 'Fails release discovery when the release target differs from the tag source' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $release = '[{"id":123,"tag_name":"v3.4.0","target_commitish":"2222222222222222222222222222222222222222","draft":true,"prerelease":false}]'
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @("[$release]") -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = '1111111111111111111111111111111111111111'
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'release target .* does not match tag event commit'
    }

    It 'Fails release discovery when channel and prerelease state disagree' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = '[{"id":123,"tag_name":"v3.4.0","target_commitish":"' + $sourceSha + '","draft":true,"prerelease":true}]'
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @("[$release]") -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = $sourceSha
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'prerelease state true does not match Stable'
    }

    It 'Fails release discovery after exactly twelve absent observations' -Skip:$script:SkipShellFixtureTests {
        $discovery = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
                -StepName 'Discover exact release')['run']
        $result = Invoke-ReleaseDiscoveryShellStep -Body $discovery -Response @('[[]]') -Environment @{
            EXPECTED_CHANNEL = 'Stable'
            EXPECTED_SHA     = '1111111111111111111111111111111111111111'
            EXPECTED_TAG     = 'v3.4.0'
            GH_TOKEN         = 'fixture-token'
            REPOSITORY       = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.AttemptCount | Should -Be 12
        $result.Output | Should -Match 'absent after exactly 12 release discovery attempts'
    }

    It 'Calls the consolidated authorized signer with all validated inputs' {
        $builder = $script:ReleaseProducer['jobs']['extension-provenance']
        [string[]]@($builder['needs']) | Should -Be @('validate-release')
        [string]$builder['uses'] | Should -BeExactly 'microsoft/hve-core/.github/workflows/extension-provenance-signer.yml@3a09401536cef0c4559db1aa64b7d1010638fd67'
        [string]$builder['with']['source-ref'] | Should -BeExactly '${{ github.sha }}'
        [string]$builder['with']['version'] | Should -BeExactly '${{ needs.validate-release.outputs.version }}'
        [string]$builder['with']['channel'] | Should -BeExactly '${{ needs.validate-release.outputs.channel }}'
        [string]$builder['with']['release-tag'] | Should -BeExactly '${{ needs.validate-release.outputs.tag-name }}'
    }

    It 'Keeps published releases verification-only without producing artifacts' {
        foreach ($job in @('extension-provenance', 'vex-attest', 'sbom-diff', 'append-verification-notes', 'publish-release')) {
            [string]$script:ReleaseProducer['jobs'][$job]['if'] | Should -Match "release-state == 'draft'"
        }
        $publishedVerification = Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
            -StepName 'Verify published release assets'
        [string]$publishedVerification['if'] | Should -Match "release-state == 'published'"
        [string]$publishedVerification['run'] | Should -Match 'Assert-ReleaseAssetSet\.ps1'
        [string]$publishedVerification['run'] | Should -Match 'VSIX_NAME="hve-core-\$RELEASE_VERSION\.vsix"'
        [string]$publishedVerification['run'] | Should -Match 'gh release download.*\-p "\$asset"'
        [string]$publishedVerification['run'] | Should -Match 'Invoke-ProvenanceVerification\.ps1'
        [string]$publishedVerification['run'] | Should -Match 'ExpectedSourceSha.*EXPECTED_SHA'
        [string]$publishedVerification['run'] | Should -Match 'ExpectedSignerSha.*3a09401536cef0c4559db1aa64b7d1010638fd67'
        [string]$publishedVerification['env']['EXPECTED_SHA'] | Should -BeExactly '${{ steps.identity.outputs.source-sha }}'
        [string]$script:ReleaseProducer['jobs']['validate-release']['permissions']['attestations'] | Should -BeExactly 'read'
    }

    It 'Executes published verification with the validated source SHA' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
            -StepName 'Verify published release assets'
        $sourceSha = '1111111111111111111111111111111111111111'
        $version = '3.4.0'
        $vsix = "hve-core-$version.vsix"
        $result = Invoke-ReleaseAssetShellStep -Body ([string]$step['run']) -AssetName @(
            $vsix
            "$vsix.spdx.json"
            "$vsix.sigstore.json"
            "$vsix.intoto.jsonl"
            'dependencies.spdx.json'
            'hve-core.openvex.json'
        ) -Environment @{
            CHANNEL         = 'Stable'
            EXPECTED_SHA    = $sourceSha
            EXPECTED_SIGNER_SHA = '3a09401536cef0c4559db1aa64b7d1010638fd67'
            GH_TOKEN        = 'fixture-token'
            RELEASE_ID      = '123'
            RELEASE_TAG     = "v$version"
            RELEASE_VERSION = $version
            REPOSITORY      = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match "ExpectedSourceSha $sourceSha"
        $result.Output | Should -Match 'ExpectedSignerSha 3a09401536cef0c4559db1aa64b7d1010638fd67'
    }

    It 'Fails published verification when the source SHA binding is absent' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'validate-release' `
            -StepName 'Verify published release assets'
        $version = '3.4.0'
        $vsix = "hve-core-$version.vsix"
        $result = Invoke-ReleaseAssetShellStep -Body ([string]$step['run']) -AssetName @(
            $vsix
            "$vsix.spdx.json"
            "$vsix.sigstore.json"
            "$vsix.intoto.jsonl"
            'dependencies.spdx.json'
            'hve-core.openvex.json'
        ) -Environment @{
            CHANNEL         = 'Stable'
            GH_TOKEN        = 'fixture-token'
            RELEASE_ID      = '123'
            RELEASE_TAG     = "v$version"
            RELEASE_VERSION = $version
            REPOSITORY      = 'microsoft/hve-core'
        }
        $result.ExitCode | Should -Not -Be 0
    }

    It 'Reconciles draft assets before minting the publication token' {
        $publish = $script:ReleaseProducer['jobs']['publish-release']
        [string]$publish['permissions']['contents'] | Should -BeExactly 'read'
        $stepNames = [string[]]@($publish['steps'] | ForEach-Object { [string]$_['name'] })
        $stepNames.IndexOf('Download verified extension artifact') |
            Should -BeLessThan $stepNames.IndexOf('Verify local artifacts and current draft occupancy')
        $stepNames.IndexOf('Verify local artifacts and current draft occupancy') |
            Should -BeLessThan $stepNames.IndexOf('Generate GitHub App Token')
        $stepNames.IndexOf('Generate GitHub App Token') |
            Should -BeLessThan $stepNames.IndexOf('Publish GitHub Release')
        $token = Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'publish-release' `
            -StepName 'Generate GitHub App Token'
        [string]$token['with']['permission-contents'] | Should -BeExactly 'write'
    }

    It 'Uploads only the fixed verified extension artifact and reconciles before publication' {
        $verifyDownload = Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'verify-provenance' `
            -StepName 'Download attested extension artifact'
        $publishDownload = Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'publish-release' `
            -StepName 'Download verified extension artifact'
        [string]$verifyDownload['with']['name'] | Should -BeExactly 'extension-attested'
        [string]$publishDownload['with']['name'] | Should -BeExactly 'extension-attested'
        [string]$verifyDownload['with']['digest-mismatch'] | Should -BeExactly 'error'
        [string]$publishDownload['with']['digest-mismatch'] | Should -BeExactly 'error'

        $occupancy = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'publish-release' `
                -StepName 'Verify local artifacts and current draft occupancy')['run']
        $occupancy | Should -Match 'exact fixed release file set'
        $occupancy | Should -Match 'MISSING_UPLOAD'
        $occupancy | Should -Match 'PRESENT_UPLOAD'
        $occupancy | Should -Match 'Existing draft asset .* differs'
        $occupancy | Should -Match 'cmp --'

        $publish = [string](Get-NamedJobStep -Document $script:ReleaseProducer -JobName 'publish-release' `
                -StepName 'Publish GitHub Release')['run']
        $publish | Should -Match 'gh release upload'
        $publish | Should -Not -Match '--clobber'
        $publish | Should -Match 'Release identity or draft state changed before publication mutation'
        $publish | Should -Match 'exact final release asset set'
        $publish.IndexOf('exact final release asset set', [System.StringComparison]::Ordinal) |
            Should -BeLessThan $publish.IndexOf('--draft=false', [System.StringComparison]::Ordinal)
    }

    It 'Removes the retired package workflow and every active caller' {
        Test-Path -LiteralPath (Join-Path $script:WorkflowDirectory 'extension-package.yml') | Should -BeFalse
        foreach ($workflow in Get-ChildItem -LiteralPath $script:WorkflowDirectory -Filter '*.yml') {
            (Get-Content -LiteralPath $workflow.FullName -Raw -Encoding utf8) |
                Should -Not -Match 'uses:\s+\./\.github/workflows/extension-package\.yml'
        }
    }
}

Describe 'Managed release identity postconditions' -Tag 'Unit' {
    It 'Exports a validated managed identity in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; TagPrefix = 'prerelease-v' }
        @{ Workflow = 'release-stable-publish.yml'; TagPrefix = 'v' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        [string]$document['jobs']['validate-trigger']['outputs']['release-tag'] |
            Should -BeExactly '${{ steps.managed.outputs.release-tag }}'
        [string]$document['jobs']['validate-trigger']['outputs']['release-version'] |
            Should -BeExactly '${{ steps.managed.outputs.release-version }}'
        $managed = Get-NamedJobStep -Document $document -JobName 'validate-trigger' `
            -StepName 'Validate managed release intent was consumed'
        [string]$managed['id'] | Should -BeExactly 'managed'
        [string]$managed['run'] | Should -Match "release-tag=$([regex]::Escape($TagPrefix))"
        [string]$managed['run'] | Should -Match 'release-version=\$VERSION'
    }

    It 'Accepts exact current-run creation in <Workflow>' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; Channel = 'PreRelease'; Tag = 'prerelease-v3.5.0'; Draft = $true; PreRelease = $false }
        @{ Workflow = 'release-stable-publish.yml'; Channel = 'Stable'; Tag = 'v3.4.0'; Draft = $true; PreRelease = $false }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName 'release-please' -StepName 'Verify managed release identity'
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = @{
            tag_name         = $Tag
            target_commitish = $sourceSha
            draft            = $Draft
            prerelease       = $PreRelease
        } | ConvertTo-Json -Compress
        $result = Invoke-ManagedReleaseIdentityShellStep -Body ([string]$step['run']) -TagObject "commit $sourceSha" `
            -ReleaseJson $release -Environment @{
                CREATED_SHA          = $sourceSha
                CREATED_TAG          = $Tag
                EXPECTED_CHANNEL     = $Channel
                EXPECTED_SHA         = $sourceSha
                EXPECTED_TAG         = $Tag
                GH_TOKEN             = 'fixture-token'
                PATHS_RELEASED       = '["."]'
                ROOT_RELEASE_CREATED = 'true'
                ANY_RELEASE_CREATED  = 'true'
                REPOSITORY           = 'microsoft/hve-core'
            }
        $result.ExitCode | Should -Be 0
    }

    It 'Accepts an exact completed rerun in <Workflow>' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; Channel = 'PreRelease'; Tag = 'prerelease-v3.5.0'; PreRelease = $true }
        @{ Workflow = 'release-stable-publish.yml'; Channel = 'Stable'; Tag = 'v3.4.0'; PreRelease = $false }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName 'release-please' -StepName 'Verify managed release identity'
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = @{
            tag_name         = $Tag
            target_commitish = $sourceSha
            draft            = $false
            prerelease       = $PreRelease
        } | ConvertTo-Json -Compress
        $result = Invoke-ManagedReleaseIdentityShellStep -Body ([string]$step['run']) -TagObject "commit $sourceSha" `
            -ReleaseJson $release -Environment @{
                CREATED_SHA     = ''
                CREATED_TAG     = ''
                EXPECTED_CHANNEL = $Channel
                EXPECTED_SHA    = $sourceSha
                EXPECTED_TAG    = $Tag
                GH_TOKEN        = 'fixture-token'
                PATHS_RELEASED  = '[]'
                ROOT_RELEASE_CREATED = ''
                ANY_RELEASE_CREATED  = 'false'
                REPOSITORY      = 'microsoft/hve-core'
            }
        $result.ExitCode | Should -Be 0
    }

    It 'Rejects a managed release whose target differs in <Workflow>' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; Channel = 'PreRelease'; Tag = 'prerelease-v3.5.0' }
        @{ Workflow = 'release-stable-publish.yml'; Channel = 'Stable'; Tag = 'v3.4.0' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName 'release-please' -StepName 'Verify managed release identity'
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = @{
            tag_name         = $Tag
            target_commitish = '2222222222222222222222222222222222222222'
            draft            = $true
            prerelease       = $false
        } | ConvertTo-Json -Compress
        $result = Invoke-ManagedReleaseIdentityShellStep -Body ([string]$step['run']) -TagObject "commit $sourceSha" `
            -ReleaseJson $release -Environment @{
                CREATED_SHA     = ''
                CREATED_TAG     = ''
                EXPECTED_CHANNEL = $Channel
                EXPECTED_SHA    = $sourceSha
                EXPECTED_TAG    = $Tag
                GH_TOKEN        = 'fixture-token'
                PATHS_RELEASED  = '[]'
                ROOT_RELEASE_CREATED = ''
                ANY_RELEASE_CREATED  = 'false'
                REPOSITORY      = 'microsoft/hve-core'
            }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'does not target managed merge'
    }

    It 'Rejects a published release with the wrong channel state in <Workflow>' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; Channel = 'PreRelease'; Tag = 'prerelease-v3.5.0'; PreRelease = $false }
        @{ Workflow = 'release-stable-publish.yml'; Channel = 'Stable'; Tag = 'v3.4.0'; PreRelease = $true }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName 'release-please' -StepName 'Verify managed release identity'
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = @{
            tag_name         = $Tag
            target_commitish = $sourceSha
            draft            = $false
            prerelease       = $PreRelease
        } | ConvertTo-Json -Compress
        $result = Invoke-ManagedReleaseIdentityShellStep -Body ([string]$step['run']) -TagObject "commit $sourceSha" `
            -ReleaseJson $release -Environment @{
                CREATED_SHA     = ''
                CREATED_TAG     = ''
                EXPECTED_CHANNEL = $Channel
                EXPECTED_SHA    = $sourceSha
                EXPECTED_TAG    = $Tag
                GH_TOKEN        = 'fixture-token'
                PATHS_RELEASED  = '[]'
                ROOT_RELEASE_CREATED = ''
                ANY_RELEASE_CREATED  = 'false'
                REPOSITORY      = 'microsoft/hve-core'
            }
        $result.ExitCode | Should -Not -Be 0
    }

    It 'Rejects malformed or absent exact managed release state' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ ReleaseJson = '[]'; FailureEndpoint = ''; Error = 'malformed response' }
        @{ ReleaseJson = '{}'; FailureEndpoint = '/releases/tags/'; Error = '' }
        @{ ReleaseJson = '{}'; FailureEndpoint = '/git/ref/tags/'; Error = '' }
    ) {
        $document = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        $step = Get-NamedJobStep -Document $document -JobName 'release-please' -StepName 'Verify managed release identity'
        $sourceSha = '1111111111111111111111111111111111111111'
        $result = Invoke-ManagedReleaseIdentityShellStep -Body ([string]$step['run']) -TagObject "commit $sourceSha" `
            -ReleaseJson $ReleaseJson -FailureEndpoint $FailureEndpoint -Environment @{
                CREATED_SHA     = ''
                CREATED_TAG     = ''
                EXPECTED_CHANNEL = 'Stable'
                EXPECTED_SHA    = $sourceSha
                EXPECTED_TAG    = 'v3.4.0'
                GH_TOKEN        = 'fixture-token'
                PATHS_RELEASED  = '[]'
                ROOT_RELEASE_CREATED = ''
                ANY_RELEASE_CREATED  = 'false'
                REPOSITORY      = 'microsoft/hve-core'
            }
        $result.ExitCode | Should -Not -Be 0
        if ($Error) {
            $result.Output | Should -Match $Error
        }
    }

    It 'Rejects inconsistent current-run output cardinality' -Skip:$script:SkipShellFixtureTests {
        $document = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        $step = Get-NamedJobStep -Document $document -JobName 'release-please' -StepName 'Verify managed release identity'
        $sourceSha = '1111111111111111111111111111111111111111'
        $release = '{"tag_name":"v3.4.0","target_commitish":"' + $sourceSha + '","draft":true,"prerelease":false}'
        $result = Invoke-ManagedReleaseIdentityShellStep -Body ([string]$step['run']) -TagObject "commit $sourceSha" `
            -ReleaseJson $release -Environment @{
                CREATED_SHA     = $sourceSha
                CREATED_TAG     = 'v3.4.0'
                EXPECTED_CHANNEL = 'Stable'
                EXPECTED_SHA    = $sourceSha
                EXPECTED_TAG    = 'v3.4.0'
                GH_TOKEN        = 'fixture-token'
                PATHS_RELEASED  = '[".","other"]'
                ROOT_RELEASE_CREATED = 'true'
                ANY_RELEASE_CREATED  = 'true'
                REPOSITORY      = 'microsoft/hve-core'
            }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'unexpected managed release identity'
    }
}

Describe 'Release workflow consumers and metadata' -Tag 'Unit' {
    It 'Runs Scorecard after the consolidated post-tag producer' {
        $scorecard = Get-WorkflowDocument -Name 'scorecard.yml'
        [string[]]@($scorecard['on']['workflow_run']['workflows']) |
            Should -Be @('Release VSIX Publish')
    }

    It 'Uses the verified create-github-app-token version comment consistently' {
        $pinMatches = Get-ChildItem -LiteralPath $script:WorkflowDirectory -Filter '*.yml' |
            Select-String -SimpleMatch 'actions/create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1'
        $pinMatches | Should -HaveCount 11
        @($pinMatches | Where-Object { $_.Line -notmatch '# v3\.2\.0\s*$' }) |
            Should -BeNullOrEmpty
    }

    It 'Removes superseded current-state release workflow names from operational documents' {
        $paths = @(
            (Join-Path $script:RepositoryRoot 'docs/contributing/release-process.md')
            (Join-Path $script:RepositoryRoot 'docs/architecture/workflows.md')
        )
        foreach ($path in $paths) {
            $text = Get-Content -LiteralPath $path -Raw -Encoding utf8
            $text | Should -Not -Match 'Pre-Release Pipeline'
            $text | Should -Not -Match 'Stable Release Publish'
        }
    }

    It 'Documents the Stable dependency diff as conditional and best effort' {
        foreach ($path in @(
                (Join-Path $script:WorkflowDirectory 'README.md')
                (Join-Path $script:RepositoryRoot 'docs/contributing/release-process.md')
                (Join-Path $script:RepositoryRoot 'docs/architecture/workflows.md')
            )) {
            $text = Get-Content -LiteralPath $path -Raw -Encoding utf8
            $text | Should -Match '(?s)best-effort.*dependency diff|dependency diff.*best-effort'
            $text | Should -Match 'previous|prior'
        }
    }
}
