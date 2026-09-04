#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

$script:BashCommand = (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1).Source
$script:SkipShellFixtureTests = -not $script:BashCommand
if (-not $script:SkipShellFixtureTests) {
    & $script:BashCommand -c 'command -v jq >/dev/null' 2>$null
    $script:SkipShellFixtureTests = $LASTEXITCODE -ne 0
}

BeforeAll {
    $script:BashCommand = (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1).Source
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:SignerPath = Join-Path $script:RepositoryRoot '.github/workflows/extension-provenance-signer.yml'
    $script:SignerText = Get-Content -LiteralPath $script:SignerPath -Raw -Encoding utf8
    $script:Signer = $script:SignerText | ConvertFrom-Yaml

    function Get-SignerStepText {
        <#
        .SYNOPSIS
            Returns the uses and run text declared by a signer job.
        .PARAMETER JobName
            Signer job identifier.
        .OUTPUTS
            [string] Combined step text.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$JobName
        )

        return (@($script:Signer['jobs'][$JobName]['steps'] | ForEach-Object {
                    $Uses = if ($_.Contains('uses')) { [string]$_['uses'] } else { '' }
                    $Run = if ($_.Contains('run')) { [string]$_['run'] } else { '' }
                    "$Uses`n$Run"
                }) -join "`n")
    }

    function Invoke-BashFixtureStep {
        <#
        .SYNOPSIS
            Runs a Bash step body in a disposable fixture.
        .PARAMETER Body
            Step run text.
        .PARAMETER Environment
            Environment variables supplied to the step.
        .PARAMETER Setup
            Optional fixture setup callback receiving the fixture path.
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

            [Parameter(Mandatory = $false)]
            [scriptblock]$Setup
        )

        $Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
        try {
            if ($Setup) {
                & $Setup $Fixture
            }
            $StepPath = Join-Path $Fixture 'step.sh'
            [IO.File]::WriteAllText($StepPath, ($Body -replace "`r?`n", "`n"), [Text.UTF8Encoding]::new($false))
            $EnvironmentPath = Join-Path $Fixture 'environment.sh'
            $EnvironmentLines = [string[]]@($Environment.GetEnumerator() | ForEach-Object {
                    $EncodedValue = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$_.Value))
                    "export $($_.Key)=`"`$(printf '%s' '$EncodedValue' | base64 --decode)`""
                })
            [IO.File]::WriteAllText(
                $EnvironmentPath,
                ($EnvironmentLines -join "`n") + "`n",
                [Text.UTF8Encoding]::new($false)
            )

            Push-Location -LiteralPath $Fixture
            try {
                & $script:BashCommand -c 'chmod +x ./bin/*'
                if ($LASTEXITCODE -ne 0) {
                    throw 'Unable to make fixture commands executable'
                }
                $Output = & $script:BashCommand -c 'source ./environment.sh; export PATH="$PWD/bin:$PATH"; bash ./step.sh' 2>&1
                return [pscustomobject]@{
                    ExitCode = $LASTEXITCODE
                    Output   = [string]::Join("`n", [string[]]@($Output))
                }
            } finally {
                Pop-Location
            }
        } finally {
            Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    function Invoke-ReleaseAuthorizationShellStep {
        <#
        .SYNOPSIS
            Runs signer authorization against deterministic API responses.
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
        .PARAMETER ReleaseList
            Draft-capable release list response.
        .PARAMETER CompareStatus
            Channel containment comparison status.
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

        $Setup = {
            param($FixturePath)
            $BinDirectory = Join-Path $FixturePath 'bin'
            New-Item -ItemType Directory -Path $BinDirectory -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $FixturePath 'ruleset-list.json'), $RulesetList, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $FixturePath 'release-list.json'), $ReleaseList, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $FixturePath 'creation.json'), $CreationRuleset, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $FixturePath 'immutable.json'), $ImmutableRuleset, [Text.UTF8Encoding]::new($false))
            $GhCommand = @'
#!/usr/bin/env bash
set -euo pipefail
test "$1" = 'api'
shift
if [ "$1" = '--paginate' ] && [ "$2" = '--slurp' ]; then
    printf '['
    case "$3" in
        */releases?*) cat "$MOCK_RELEASE_LIST" ;;
        */rulesets?*) cat "$MOCK_RULESET_LIST" ;;
        *) exit 1 ;;
    esac
    printf ']'
    exit 0
fi
case "$1" in
    /apps/hve-core-release-please)
        printf '%s\n' '{"id":2646666,"slug":"hve-core-release-please"}' ;;
    /users/hve-core-release-please%5Bbot%5D)
        printf '%s\n' '{"id":254602402,"login":"hve-core-release-please[bot]","type":"Bot"}' ;;
    */git/ref/heads/release/stable)
        printf '%s\n' '{"object":{"sha":"3333333333333333333333333333333333333333"}}' ;;
    */compare/1111111111111111111111111111111111111111...3333333333333333333333333333333333333333)
        printf '{"status":"%s"}\n' "$MOCK_COMPARE_STATUS" ;;
    */rulesets/101?*) cat "$MOCK_CREATION_RULESET" ;;
    */rulesets/102?*) cat "$MOCK_IMMUTABLE_RULESET" ;;
    *) exit 1 ;;
esac
'@
            [IO.File]::WriteAllText(
                (Join-Path $BinDirectory 'gh'),
                ($GhCommand -replace "`r?`n", "`n"),
                [Text.UTF8Encoding]::new($false)
            )
        }
        $FixtureEnvironment = @{} + $Environment
        $FixtureEnvironment['MOCK_RULESET_LIST'] = './ruleset-list.json'
        $FixtureEnvironment['MOCK_RELEASE_LIST'] = './release-list.json'
        $FixtureEnvironment['MOCK_CREATION_RULESET'] = './creation.json'
        $FixtureEnvironment['MOCK_IMMUTABLE_RULESET'] = './immutable.json'
        $FixtureEnvironment['MOCK_COMPARE_STATUS'] = $CompareStatus
        $FixtureEnvironment['RUNNER_TEMP'] = '.'
        return Invoke-BashFixtureStep -Body $Body -Environment $FixtureEnvironment -Setup $Setup
    }
}

Describe 'Immutable extension provenance signer' -Tag 'Unit' {
    It 'Declares the immutable authorization, package, and attestation graph' {
        [string[]]@($script:Signer['jobs'].Keys | Sort-Object) |
            Should -Be @('attest', 'authorize', 'package')
        [string[]]@($script:Signer['jobs']['package']['needs']) | Should -Be @('authorize')
        [string[]]@($script:Signer['jobs']['attest']['needs']) | Should -Be @('authorize', 'package')
        [string]$script:Signer['concurrency']['group'] |
            Should -BeExactly 'extension-provenance-signer-${{ inputs.release-tag }}'
        [bool]$script:Signer['concurrency']['cancel-in-progress'] | Should -BeFalse
    }

    It 'Has one caller pinned to the merged signer revision' {
        $Callers = @(Get-ChildItem -LiteralPath (Join-Path $script:RepositoryRoot '.github/workflows') -Filter '*.yml' |
                Where-Object { $_.FullName -ne $script:SignerPath } |
                Select-String -Pattern 'uses:\s+microsoft/hve-core/\.github/workflows/extension-provenance-signer\.yml@3a09401536cef0c4559db1aa64b7d1010638fd67\s+# PR #2823 squash\s*$')
        $Callers | Should -HaveCount 1
        Split-Path -Path $Callers[0].Path -Leaf | Should -BeExactly 'release-vsix-publish.yml'
    }

    It 'Limits the scanner acknowledgment to the read-only package job' {
        $Config = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.poutine.yml') -Raw -Encoding utf8 |
            ConvertFrom-Yaml
        $Exceptions = @($Config['skip'] | Where-Object {
                @($_['rule']) -contains 'untrusted_checkout_exec' -and
                @($_['path']) -contains '.github/workflows/extension-provenance-signer.yml'
            })
        $Exceptions | Should -HaveCount 1
        @($Exceptions[0].Keys | Sort-Object) | Should -Be @('job', 'path', 'rule')
        [string[]]@($Exceptions[0]['job']) | Should -Be @('package')
    }

    It 'Isolates the governance credential to checkout-free authorization' {
        [string]$script:Signer['jobs']['authorize']['environment'] | Should -BeExactly 'release-governance'
        [string]$script:Signer['jobs']['authorize']['permissions']['contents'] | Should -BeExactly 'read'
        $Token = @($script:Signer['jobs']['authorize']['steps'] |
            Where-Object { [string]$_['name'] -eq 'Generate governance-read Release App token' })[0]
        [string]$Token['with']['permission-administration'] | Should -BeExactly 'read'
        [string]$Token['with']['permission-contents'] | Should -BeExactly 'read'
        [string]$Token['with']['private-key'] | Should -BeExactly '${{ secrets.RELEASE_APP_PRIVATE_KEY }}'
        $AuthorizeText = Get-SignerStepText -JobName 'authorize'
        $AuthorizeText | Should -Not -Match 'actions/checkout@|npm ci|Package-Extension\.ps1|gh release (upload|edit)'

        foreach ($Job in @('package', 'attest')) {
            (Get-SignerStepText -JobName $Job) |
                Should -Not -Match 'RELEASE_APP_PRIVATE_KEY|app-token\.outputs\.token'
        }
    }

    It 'Validates actor, draft, channel containment, and exact governance before checkout' {
        $AuthorizeText = Get-SignerStepText -JobName 'authorize'
        foreach ($Contract in @(
                'hve-core-release-please\[bot\]'
                '254602402'
                'Exact draft release identity'
                'compare/\$EVENT_SHA\.\.\.\$BRANCH_SHA'
                'release-tags-creation-by-release-app'
                'release-tags-immutable'
                'bypass_actors'
                'actor_type == "Integration"'
                'actor_id == 2646666'
                'bypass_mode == "always"'
                'and \.bypass_actors == \[\]')) {
            $AuthorizeText | Should -Match $Contract
        }
    }

    It 'Executes release source only in the read-only package job' {
        [string]$script:Signer['jobs']['package']['permissions']['contents'] | Should -BeExactly 'read'
        $PackageText = Get-SignerStepText -JobName 'package'
        $PackageText | Should -Match 'actions/checkout@'
        $PackageText | Should -Match 'npm ci --ignore-scripts=false'
        $PackageText | Should -Match 'Package-Extension\.ps1'
        $PackageText | Should -Match 'Generate dependency SBOM|anchore/sbom-action@'

        foreach ($Job in @('authorize', 'attest')) {
            (Get-SignerStepText -JobName $Job) |
                Should -Not -Match 'actions/checkout@|npm ci|Package-Extension\.ps1|Prepare-Extension\.ps1|\.\/\.github\/actions\/'
        }
    }

    It 'Binds the event-default checkout to the authorized source before execution' {
        $PackageSteps = @($script:Signer['jobs']['package']['steps'])
        $Checkout = @($PackageSteps | Where-Object { [string]$_['name'] -eq 'Checkout code' })[0]
        $Checkout['with'].Contains('ref') | Should -BeFalse
        [bool]$Checkout['with']['persist-credentials'] | Should -BeFalse

        $StepNames = [string[]]@($PackageSteps | ForEach-Object { [string]$_['name'] })
        $CheckoutIndex = [Array]::IndexOf($StepNames, 'Checkout code')
        $VerifyIndex = [Array]::IndexOf($StepNames, 'Verify checked-out source')
        $VerifyIndex | Should -Be ($CheckoutIndex + 1)

        $Verify = $PackageSteps[$VerifyIndex]
        [string]$Verify['env']['EXPECTED_SOURCE'] | Should -BeExactly '${{ github.sha }}'
        [string]$Verify['run'] | Should -Match 'git rev-parse HEAD'
        [string]$Verify['run'] | Should -Match 'CHECKED_OUT_SOURCE.*EXPECTED_SOURCE'
    }

    It 'Keeps privileged attestation checkout-free and release-write-free' {
        $Permissions = $script:Signer['jobs']['attest']['permissions']
        [string[]]@($Permissions.Keys | Sort-Object) |
            Should -Be @('artifact-metadata', 'attestations', 'contents', 'id-token')
        [string]$Permissions['contents'] | Should -BeExactly 'read'
        [string]$Permissions['id-token'] | Should -BeExactly 'write'
        [string]$Permissions['attestations'] | Should -BeExactly 'write'
        [string]$Permissions['artifact-metadata'] | Should -BeExactly 'write'

        $AttestText = Get-SignerStepText -JobName 'attest'
        $AttestText | Should -Not -Match 'gh release (upload|edit)|actions/checkout@|\.\/scripts\/'
        @([regex]::Matches($AttestText, 'actions/attest-build-provenance@')) | Should -HaveCount 1
        @([regex]::Matches($AttestText, 'actions/attest@')) | Should -HaveCount 2
    }

    It 'Closes the attestation input and output file sets' {
        $PackageText = Get-SignerStepText -JobName 'package'
        $AttestText = Get-SignerStepText -JobName 'attest'
        $PackageText | Should -Match 'dependencies\.spdx\.json'
        $PackageText | Should -Match 'manifest\.json'
        $AttestText | Should -Match 'EXPECTED_FILES='
        $AttestText | Should -Match 'Untrusted package manifest does not match frozen attestation policy'
        $AttestText | Should -Match 'attested/dependencies\.spdx\.json'
        $AttestText | Should -Match '\.sigstore\.json'
        $AttestText | Should -Match '\.intoto\.jsonl'
    }

    Context 'when authorization executes against API fixtures' {
        BeforeAll {
            $script:AuthorizationBody = [string]@($script:Signer['jobs']['authorize']['steps'] |
                Where-Object { [string]$_['name'] -eq 'Authenticate release principal and governance' })[0]['run']
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

        It 'Accepts the exact Release App, release, containment, and governance state' -Skip:$script:SkipShellFixtureTests {
            $Result = Invoke-ReleaseAuthorizationShellStep -Body $script:AuthorizationBody `
                -Environment $script:AuthorizationEnvironment -RulesetList $script:RulesetList `
                -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset
            $Result.ExitCode | Should -Be 0
        }

        It 'Rejects invalid <Name> identity or caller input before packaging' -Skip:$script:SkipShellFixtureTests -ForEach @(
            @{ Name = 'actor'; Key = 'EVENT_ACTOR'; Value = 'octocat'; Error = 'expected Release App principal' }
            @{ Name = 'source'; Key = 'INPUT_SOURCE_REF'; Value = '2222222222222222222222222222222222222222'; Error = 'immutable release event identity' }
        ) {
            $Environment = @{} + $script:AuthorizationEnvironment
            $Environment[$Key] = $Value
            $Result = Invoke-ReleaseAuthorizationShellStep -Body $script:AuthorizationBody `
                -Environment $Environment -RulesetList $script:RulesetList `
                -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset
            $Result.ExitCode | Should -Not -Be 0
            $Result.Output | Should -Match $Error
        }

        It 'Rejects invalid <Name> release discovery before packaging' -Skip:$script:SkipShellFixtureTests -ForEach @(
            @{ Name = 'absent release'; Releases = '[]'; Error = 'Exact draft release identity' }
            @{ Name = 'malformed release pages'; Releases = '{"malformed":true}'; Error = 'malformed response' }
        ) {
            $Result = Invoke-ReleaseAuthorizationShellStep -Body $script:AuthorizationBody `
                -Environment $script:AuthorizationEnvironment -RulesetList $script:RulesetList `
                -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset `
                -ReleaseList $Releases
            $Result.ExitCode | Should -Not -Be 0
            $Result.Output | Should -Match $Error
        }

        It 'Rejects a release commit outside its channel branch' -Skip:$script:SkipShellFixtureTests {
            $Result = Invoke-ReleaseAuthorizationShellStep -Body $script:AuthorizationBody `
                -Environment $script:AuthorizationEnvironment -RulesetList $script:RulesetList `
                -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset `
                -CompareStatus 'diverged'
            $Result.ExitCode | Should -Not -Be 0
            $Result.Output | Should -Match 'not contained in the expected release/stable branch'
        }

        It 'Rejects invalid <Name> governance discovery before packaging' -Skip:$script:SkipShellFixtureTests -ForEach @(
            @{
                Name = 'missing ruleset'
                List = '[{"id":101,"name":"release-tags-creation-by-release-app"}]'
                Error = 'match count 0'
            }
            @{
                Name = 'malformed ruleset pages'
                List = '{"malformed":true}'
                Error = 'malformed response'
            }
        ) {
            $Result = Invoke-ReleaseAuthorizationShellStep -Body $script:AuthorizationBody `
                -Environment $script:AuthorizationEnvironment -RulesetList $List `
                -CreationRuleset $script:CreationRuleset -ImmutableRuleset $script:ImmutableRuleset
            $Result.ExitCode | Should -Not -Be 0
            $Result.Output | Should -Match $Error
        }
    }
}
