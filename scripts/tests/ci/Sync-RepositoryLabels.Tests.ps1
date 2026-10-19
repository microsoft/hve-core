#Requires -Modules Pester, powershell-yaml
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    . (Join-Path $script:RepoRoot 'scripts/ci/Sync-RepositoryLabels.ps1')

    function New-TestLabel {
        param([string]$Name, [string]$Color = 'abcdef', [string]$Description = '')
        return @{ name = $Name; color = $Color; description = $Description }
    }

    function New-TestIssue {
        param([int]$Number, [string[]]$Labels, [string]$State = 'closed', [switch]$PullRequest)
        $Issue = @{
            number = $Number
            state = $State
            labels = @($Labels | ForEach-Object { @{ name = $_ } })
        }
        if ($PullRequest) { $Issue.pull_request = @{} }
        return $Issue
    }

    function Invoke-TestSync {
        Sync-RepositoryLabels -Repository 'owner/repo' -ConfigPath $script:ConfigPath -Confirm:$false
    }
}

Describe 'Label configuration validation' -Tag 'Unit' {
    BeforeEach {
        $script:ConfigPath = Join-Path $TestDrive 'labels.yml'
        Mock Invoke-RepositoryLabelApi { throw 'No network call is allowed during configuration validation.' }
    }

    It 'Normalizes color and optional description while retaining aliases' {
        @'
- name: canonical
  color: '#ABCDEF'
  aliases: [legacy]
'@ | Set-Content -LiteralPath $script:ConfigPath
        $Result = Get-RepositoryLabelConfiguration -Path $script:ConfigPath
        $Result.Count | Should -Be 1
        $Result[0].color | Should -Be 'abcdef'
        $Result[0].description | Should -BeExactly ''
        $Result[0].aliases | Should -Be @('legacy')
    }

    It 'Rejects <Name> before any API call' -ForEach @(
        @{ Name = 'a mapping root'; Yaml = "name: bad`ncolor: abcdef" }
        @{ Name = 'an empty root'; Yaml = '[]' }
        @{ Name = 'a scalar entry'; Yaml = '- invalid' }
        @{ Name = 'an empty name'; Yaml = "- name: ''`n  color: abcdef" }
        @{ Name = 'surrounding whitespace'; Yaml = "- name: ' label '`n  color: abcdef" }
        @{ Name = 'a missing color'; Yaml = '- name: bad' }
        @{ Name = 'a malformed color'; Yaml = "- name: bad`n  color: zz00ff" }
        @{ Name = 'a numeric color'; Yaml = "- name: bad`n  color: 123456" }
        @{ Name = 'a newline-terminated color'; Yaml = "- name: bad`n  color: `"abcdef\n`"" }
        @{ Name = 'a non-string description'; Yaml = "- name: bad`n  color: abcdef`n  description: 42" }
        @{ Name = 'an oversized description'; Yaml = "- name: bad`n  color: abcdef`n  description: '$('x' * 101)'" }
        @{ Name = 'duplicate canonical names'; Yaml = "- name: Good`n  color: abcdef`n- name: good`n  color: abcdef" }
        @{ Name = 'scalar aliases'; Yaml = "- name: bad`n  color: abcdef`n  aliases: old" }
        @{ Name = 'numeric aliases'; Yaml = "- name: bad`n  color: abcdef`n  aliases: [42]" }
        @{ Name = 'empty aliases'; Yaml = "- name: bad`n  color: abcdef`n  aliases: ['']" }
        @{ Name = 'whitespace aliases'; Yaml = "- name: bad`n  color: abcdef`n  aliases: [' old ']" }
        @{ Name = 'self aliases'; Yaml = "- name: bad`n  color: abcdef`n  aliases: [BAD]" }
        @{ Name = 'duplicate aliases'; Yaml = "- name: one`n  color: abcdef`n  aliases: [old, OLD]" }
        @{ Name = 'canonical alias overlap'; Yaml = "- name: one`n  color: abcdef`n  aliases: [two]`n- name: two`n  color: abcdef" }
        @{ Name = 'shared alias ownership'; Yaml = "- name: one`n  color: abcdef`n  aliases: [old]`n- name: two`n  color: abcdef`n  aliases: [old]" }
    ) {
        $Yaml | Set-Content -LiteralPath $script:ConfigPath
        { Invoke-TestSync } | Should -Throw
        Should -Invoke Invoke-RepositoryLabelApi -Times 0
    }

    It 'Rejects invalid repository identifiers before API calls' -ForEach @(
        @{ Repository = 'https://example.invalid/repo' }
        @{ Repository = '../repo' }
        @{ Repository = 'owner/repo/extra' }
        @{ Repository = 'owner/repo?token=not-a-real-token' }
        @{ Repository = 'owner/..' }
        @{ Repository = "owner/repo`n" }
    ) {
        { Sync-RepositoryLabels -Repository $Repository -ConfigPath $script:ConfigPath } | Should -Throw '*owner/repository*'
        Should -Invoke Invoke-RepositoryLabelApi -Times 0
    }

    It 'Reports a missing configuration without its path' {
        $Missing = Join-Path $TestDrive 'person@example.invalid.yml'
        try { Get-RepositoryLabelConfiguration -Path $Missing }
        catch { $Message = $_.Exception.Message }
        $Message | Should -Be 'Cannot read or parse the label configuration.'
        $Message | Should -Not -Match 'person@example'
    }

    It 'Does not expose malformed YAML input in diagnostics' {
        "- name: 'person@example.invalid" | Set-Content -LiteralPath $script:ConfigPath
        try { Get-RepositoryLabelConfiguration -Path $script:ConfigPath }
        catch { $Message = $_.Exception.Message }
        $Message | Should -Be 'Cannot read or parse the label configuration.'
        $Message | Should -Not -Match 'person@'
    }

    It 'Validates the real repository configuration' {
        $Result = Get-RepositoryLabelConfiguration -Path (Join-Path $script:RepoRoot '.github/labels.yml')
        $Result.Count | Should -BeGreaterThan 20
        ($Result | Where-Object name -eq 'instructions').aliases | Should -Contain 'instruction-file'
    }
}

Describe 'Label reconciliation' -Tag 'Unit' {
    BeforeEach {
        $script:ConfigPath = Join-Path $TestDrive 'labels.yml'
        "- name: canonical`n  color: abcdef`n  description: current`n  aliases: [legacy]" |
            Set-Content -LiteralPath $script:ConfigPath
        $script:Labels = [System.Collections.Generic.List[object]]::new()
        $script:Issues = [System.Collections.Generic.List[object]]::new()
        $script:Requests = [System.Collections.Generic.List[object]]::new()
        $script:FailIssue = 0
        $script:IntroduceIssue = $false
        $script:IssueReads = 0

        Mock Invoke-RepositoryLabelApi {
            param($Path, $Method = 'GET', $Body)
            $script:Requests.Add(@{ Path = $Path; Method = $Method; Body = $Body })
            if ($Method -eq 'GET' -and $Path -match '^repos/owner/repo/labels\?per_page=100&page=(\d+)$') {
                $Offset = ([int]$Matches[1] - 1) * 100
                return ,@($script:Labels.ToArray() | Select-Object -Skip $Offset -First 100)
            }
            if ($Method -eq 'GET' -and $Path -match '^repos/owner/repo/issues\?state=all&labels=([^&]+)&per_page=100&page=(\d+)$') {
                $Alias = [uri]::UnescapeDataString($Matches[1])
                $Offset = ([int]$Matches[2] - 1) * 100
                $script:IssueReads++
                if ($script:IntroduceIssue -and $script:IssueReads -eq 2) {
                    $script:Issues.Add((New-TestIssue -Number 999 -Labels @($Alias)))
                }
                return ,@($script:Issues.ToArray() | Where-Object { $Alias -in @($_.labels.name) } | Select-Object -Skip $Offset -First 100)
            }
            if ($Method -eq 'POST' -and $Path -eq 'repos/owner/repo/labels') {
                $script:Labels.Add((New-TestLabel -Name $Body.name -Color $Body.color -Description $Body.description))
                return @{}
            }
            if ($Method -eq 'PATCH' -and $Path -match '^repos/owner/repo/labels/(.+)$') {
                $Old = [uri]::UnescapeDataString($Matches[1])
                $Target = $script:Labels | Where-Object name -eq $Old | Select-Object -First 1
                $Target.name = $Body.new_name
                $Target.color = $Body.color
                $Target.description = $Body.description
                foreach ($Issue in $script:Issues) {
                    foreach ($Label in $Issue.labels) {
                        if ($Label.name -eq $Old) { $Label.name = $Body.new_name }
                    }
                }
                return $Target
            }
            if ($Method -eq 'POST' -and $Path -match '^repos/owner/repo/issues/(\d+)/labels$') {
                $Number = [int]$Matches[1]
                if ($Number -eq $script:FailIssue) { throw 'Simulated assignment failure.' }
                $Issue = $script:Issues | Where-Object number -eq $Number | Select-Object -First 1
                $Issue.labels = @($Issue.labels) + @($Body.labels | ForEach-Object { @{ name = $_ } })
                return ,$Issue.labels
            }
            if ($Method -eq 'DELETE' -and $Path -match '^repos/owner/repo/labels/(.+)$') {
                $Alias = [uri]::UnescapeDataString($Matches[1])
                $Target = $script:Labels | Where-Object name -eq $Alias | Select-Object -First 1
                $null = $script:Labels.Remove($Target)
                foreach ($Issue in $script:Issues) {
                    $Issue.labels = @($Issue.labels | Where-Object name -ne $Alias)
                }
                return $null
            }
            throw 'Unexpected mocked label API request.'
        }
    }

    It 'Creates a missing canonical label and preserves unrelated labels' {
        $script:Labels.Add((New-TestLabel -Name unrelated))
        $Result = Invoke-TestSync
        $Result.Created | Should -Be 1
        $script:Labels.name | Should -Contain 'unrelated'
        $script:Labels.name | Should -Contain 'canonical'
        @($script:Requests | Where-Object Method -eq DELETE).Count | Should -Be 0
    }

    It 'Updates metadata and casing without replacing issue assignments' {
        $script:Labels.Add((New-TestLabel -Name CANONICAL -Color '123456' -Description old))
        $script:Issues.Add((New-TestIssue -Number 1 -Labels @('CANONICAL', 'unrelated')))
        $Result = Invoke-TestSync
        $Result.Updated | Should -Be 1
        $script:Labels[0].name | Should -BeExactly canonical
        $script:Labels[0].description | Should -Be current
        $script:Issues[0].labels.name | Should -Contain unrelated
    }

    It 'Does not write on the second identical run' {
        $null = Invoke-TestSync
        $script:Requests.Clear()
        $Result = Invoke-TestSync
        $Result.Unchanged | Should -Be 1
        @($script:Requests | Where-Object Method -ne GET).Count | Should -Be 0
    }

    It 'Renames a lone alias and preserves closed PR assignments without issue writes' {
        $script:Labels.Add((New-TestLabel -Name legacy))
        $script:Issues.Add((New-TestIssue -Number 12 -Labels @('legacy', 'unrelated') -PullRequest))
        $Result = Invoke-TestSync
        $Result.Renamed | Should -Be 1
        $script:Issues[0].labels.name | Should -Contain canonical
        $script:Issues[0].labels.name | Should -Contain unrelated
        @($script:Requests | Where-Object Method -eq POST).Count | Should -Be 0
    }

    It 'Merges coexisting aliases without replacing unrelated issue or PR labels' {
        foreach ($Name in @('canonical', 'legacy')) {
            $script:Labels.Add((New-TestLabel -Name $Name -Description current))
        }
        $script:Issues.Add((New-TestIssue -Number 1 -Labels @('legacy', 'unrelated') -State open))
        $script:Issues.Add((New-TestIssue -Number 2 -Labels @('legacy', 'canonical') -PullRequest))
        $Result = Invoke-TestSync
        $Result.MigratedIssues | Should -Be 1
        $Result.DeletedAliases | Should -Be 1
        $script:Issues[0].labels.name | Should -Contain unrelated
        $script:Issues[0].labels.name | Should -Contain canonical
        $script:Labels.name | Should -Not -Contain legacy
    }

    It 'Merges multiple aliases after renaming the first' {
        "- name: canonical`n  color: abcdef`n  description: current`n  aliases: [old-one, old-two]" |
            Set-Content -LiteralPath $script:ConfigPath
        $script:Labels.Add((New-TestLabel -Name old-one))
        $script:Labels.Add((New-TestLabel -Name old-two))
        $script:Issues.Add((New-TestIssue -Number 1 -Labels @('old-one')))
        $script:Issues.Add((New-TestIssue -Number 2 -Labels @('old-two')))
        $Result = Invoke-TestSync
        $Result.Renamed | Should -Be 1
        $Result.DeletedAliases | Should -Be 1
        $script:Issues[0].labels.name | Should -Contain canonical
        $script:Issues[1].labels.name | Should -Contain canonical
    }

    It 'Reads more than one page of repository labels before reconciling' {
        foreach ($Number in 1..100) { $script:Labels.Add((New-TestLabel -Name "extra-$Number")) }
        $script:Labels.Add((New-TestLabel -Name canonical -Description current))
        $Result = Invoke-TestSync
        $Result.Created | Should -Be 0
        $Result.Unchanged | Should -Be 1
        @($script:Requests | Where-Object Path -eq 'repos/owner/repo/labels?per_page=100&page=2').Count | Should -Be 1
    }

    It 'Migrates every page of alias assignments including closed PRs' {
        foreach ($Name in @('canonical', 'legacy')) { $script:Labels.Add((New-TestLabel -Name $Name -Description current)) }
        foreach ($Number in 1..101) { $script:Issues.Add((New-TestIssue -Number $Number -Labels @('legacy') -PullRequest)) }
        $Result = Invoke-TestSync
        $Result.MigratedIssues | Should -Be 101
        $Result.DeletedAliases | Should -Be 1
        @($script:Issues | Where-Object { 'canonical' -notin $_.labels.name }).Count | Should -Be 0
    }

    It 'Retains an alias on partial failure and safely resumes without duplicate writes' {
        foreach ($Name in @('canonical', 'legacy')) { $script:Labels.Add((New-TestLabel -Name $Name -Description current)) }
        $script:Issues.Add((New-TestIssue -Number 1 -Labels @('legacy')))
        $script:Issues.Add((New-TestIssue -Number 2 -Labels @('legacy')))
        $script:FailIssue = 2
        { Invoke-TestSync } | Should -Throw '*assignment failure*'
        $script:Labels.name | Should -Contain legacy
        @($script:Requests | Where-Object Method -eq DELETE).Count | Should -Be 0
        $script:FailIssue = 0
        $Result = Invoke-TestSync
        $Result.MigratedIssues | Should -Be 1
        $Result.DeletedAliases | Should -Be 1
    }

    It 'Retains an alias if a new unmigrated assignment appears during verification' {
        foreach ($Name in @('canonical', 'legacy')) { $script:Labels.Add((New-TestLabel -Name $Name -Description current)) }
        $script:Issues.Add((New-TestIssue -Number 1 -Labels @('legacy')))
        $script:IntroduceIssue = $true
        { Invoke-TestSync } | Should -Throw '*alias retained*'
        @($script:Requests | Where-Object Method -eq DELETE).Count | Should -Be 0
    }

    It 'Encodes alias names without interpolating URL or shell syntax' {
        "- name: canonical`n  color: abcdef`n  aliases: ['old / label']" | Set-Content -LiteralPath $script:ConfigPath
        $script:Labels.Add((New-TestLabel -Name 'old / label'))
        $null = Invoke-TestSync
        @($script:Requests | Where-Object Path -eq 'repos/owner/repo/labels/old%20%2F%20label').Count | Should -Be 1
    }

    It 'Performs no network calls in WhatIf mode' {
        $Result = Sync-RepositoryLabels -Repository owner/repo -ConfigPath $script:ConfigPath -WhatIf
        $Result.Status | Should -Be Skipped
        Should -Invoke Invoke-RepositoryLabelApi -Times 0
    }

    It 'Does not split comma-containing alias names into multiple label filters' {
        $script:Issues.Add((New-TestIssue -Number 1 -Labels @('old, label')))
        $script:Issues.Add((New-TestIssue -Number 2 -Labels @('old', 'label')))
        Mock Get-RepositoryLabelCollection {
            param($Path)
            $Path | Should -Be 'repos/owner/repo/issues?state=all'
            return ,$script:Issues.ToArray()
        }
        $Result = Get-RepositoryAliasIssues -Prefix repos/owner/repo -Alias 'old, label'
        $Result.Count | Should -Be 1
        $Result[0].number | Should -Be 1
    }

    It 'Rejects malformed collection responses rather than treating them as empty' {
        Mock Invoke-RepositoryLabelApi { return @{ unexpected = 'object' } }
        { Invoke-TestSync } | Should -Throw '*invalid collection*'
    }

    It 'Retains aliases when assignment records have invalid issue numbers' {
        foreach ($Name in @('canonical', 'legacy')) { $script:Labels.Add((New-TestLabel -Name $Name -Description current)) }
        Mock Get-RepositoryAliasIssues { return ,@(@{ number = 'not-a-number'; labels = @(@{ name = 'legacy' }) }) }
        { Invoke-TestSync } | Should -Throw '*invalid alias assignments*'
        @($script:Requests | Where-Object Method -eq DELETE).Count | Should -Be 0
    }
}

Describe 'GitHub label API transport' -Tag 'Unit' {
    BeforeEach {
        $script:SavedGhToken = $env:GH_TOKEN
        $script:SavedGitHubToken = $env:GITHUB_TOKEN
        $env:GH_TOKEN = 'fake-label-token-not-a-real-credential'
        $env:GITHUB_TOKEN = ''
        $script:HttpCalls = 0
        Mock Start-Sleep {}
    }

    AfterEach {
        $env:GH_TOKEN = $script:SavedGhToken
        $env:GITHUB_TOKEN = $script:SavedGitHubToken
    }

    It 'Keeps an empty JSON collection distinct from a no-content response' {
        Mock Invoke-WebRequest { return @{ StatusCode = 200; Content = '[]' } }
        $Result = Invoke-RepositoryLabelApi -Path repos/owner/repo/labels
        ,$Result | Should -BeOfType [object[]]
        $Result.Count | Should -Be 0
    }

    It 'Accepts successful no-content deletion' {
        Mock Invoke-WebRequest { return @{ StatusCode = 204; Content = '' } }
        Invoke-RepositoryLabelApi -Path repos/owner/repo/labels/old -Method DELETE | Should -BeNullOrEmpty
    }

    It 'Uses token headers, fixed GitHub host, and UTF8 JSON' {
        $script:Seen = $null
        Mock Invoke-WebRequest {
            param($Uri, $Method, $Headers, $Body, $ContentType)
            $script:Seen = @{ Uri = $Uri; Method = $Method; Headers = $Headers; Body = $Body; ContentType = $ContentType }
            return @{ StatusCode = 201; Content = '{}' }
        }
        $Description = 'quote " slash \ and ' + [char]0x00E9
        $null = Invoke-RepositoryLabelApi -Path repos/owner/repo/labels -Method POST -Body @{ name = 'label'; description = $Description }
        $script:Seen.Uri | Should -Be 'https://api.github.com/repos/owner/repo/labels'
        $script:Seen.Headers.Authorization | Should -Be "Bearer $env:GH_TOKEN"
        $Decoded = [System.Text.Encoding]::UTF8.GetString($script:Seen.Body) | ConvertFrom-Json
        $Decoded.description | Should -BeExactly $Description
    }

    It 'Falls back to GITHUB_TOKEN' {
        $env:GH_TOKEN = ''
        $env:GITHUB_TOKEN = 'another-fake-token'
        Mock Invoke-WebRequest {
            param($Headers)
            $Headers.Authorization | Should -Be 'Bearer another-fake-token'
            return @{ StatusCode = 200; Content = '[]' }
        }
        $null = Invoke-RepositoryLabelApi -Path repos/owner/repo/labels
    }

    It 'Fails explicitly without credentials' {
        $env:GH_TOKEN = ''
        Mock Invoke-WebRequest {}
        { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels } | Should -Throw '*required*'
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'Rejects a whitespace-bearing token without sending or printing it' {
        $env:GH_TOKEN = "fake-token`nperson@example.invalid"
        Mock Invoke-WebRequest {}
        try { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels }
        catch { $Message = $_.Exception.Message }
        $Message | Should -Be 'The GitHub token must not contain whitespace.'
        $Message | Should -Not -Match 'fake-token|person@'
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'Retries transient HTTP <Code> without exposing its error body' -ForEach @(
        @{ Code = 429 }
        @{ Code = 500 }
        @{ Code = 503 }
    ) {
        $script:StatusCode = $Code
        Mock Invoke-WebRequest {
            $script:HttpCalls++
            if ($script:HttpCalls -lt 3) {
                $Response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$script:StatusCode)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('person@example.invalid?token=fake-secret', $Response)
            }
            return @{ StatusCode = 200; Content = '[]' }
        }
        $null = Invoke-RepositoryLabelApi -Path repos/owner/repo/labels
        $script:HttpCalls | Should -Be 3
        Should -Invoke Start-Sleep -Times 2
    }

    It 'Does not retry HTTP <Code> and does not expose third-party secrets' -ForEach @(
        @{ Code = 401 }
        @{ Code = 403 }
        @{ Code = 404 }
        @{ Code = 422 }
    ) {
        $script:StatusCode = $Code
        Mock Invoke-WebRequest {
            $Response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$script:StatusCode)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('person@example.invalid Authorization: fake-secret', $Response)
        }
        try { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels -Method POST -Body @{ name = 'label' } }
        catch { $Message = $_.Exception.Message }
        $Message | Should -Be "GitHub label API POST failed (HTTP $Code)."
        $Message | Should -Not -Match 'person@|fake-secret|Authorization'
        Should -Invoke Start-Sleep -Times 0
    }

    It 'Stops after three transient failures rather than reporting success' {
        Mock Invoke-WebRequest {
            $Response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::ServiceUnavailable)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('fake-secret', $Response)
        }
        { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels } | Should -Throw '*HTTP 503*'
        Should -Invoke Invoke-WebRequest -Times 3
    }

    It 'Does not retry earlier than an excessive Retry-After interval' {
        Mock Invoke-WebRequest {
            $Response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
            $Response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([timespan]::FromSeconds(60))
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('fake-secret', $Response)
        }
        { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels } | Should -Throw '*HTTP 429*'
        Should -Invoke Start-Sleep -Times 0
    }

    It 'Honors a bounded Retry-After delay' {
        Mock Invoke-WebRequest {
            $script:HttpCalls++
            if ($script:HttpCalls -eq 1) {
                $Response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                $Response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([timespan]::FromSeconds(5))
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('fake-secret', $Response)
            }
            return @{ StatusCode = 200; Content = '[]' }
        }
        $null = Invoke-RepositoryLabelApi -Path repos/owner/repo/labels
        Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 5 }
    }

    It 'Does not retry earlier than a distant Retry-After date' {
        Mock Invoke-WebRequest {
            $Response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
            $Response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([datetimeoffset]::UtcNow.AddMinutes(10))
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('fake-secret', $Response)
        }
        { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels } | Should -Throw '*HTTP 429*'
        Should -Invoke Start-Sleep -Times 0
    }

    It 'Does not expose invalid header or timeout diagnostics' -ForEach @(
        @{ Kind = 'header'; Expected = '*headers are invalid*' }
        @{ Kind = 'timeout'; Expected = '*transport failed*' }
    ) {
        $script:FailureKind = $Kind
        Mock Invoke-WebRequest {
            if ($script:FailureKind -eq 'header') { throw [System.FormatException]::new('Authorization: fake-secret person@example.invalid') }
            throw [System.Threading.Tasks.TaskCanceledException]::new('fake-secret person@example.invalid')
        }
        try { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels }
        catch { $Message = $_.Exception.Message }
        $Message | Should -BeLike $Expected
        $Message | Should -Not -Match 'fake-secret|person@|Authorization'
    }

    It 'Does not emit invalid JSON or transport-error details' -ForEach @(
        @{ Kind = 'json'; Expected = '*invalid JSON*' }
        @{ Kind = 'network'; Expected = '*transport failed*' }
    ) {
        $script:FailureKind = $Kind
        Mock Invoke-WebRequest {
            if ($script:FailureKind -eq 'network') { throw [System.Net.Http.HttpRequestException]::new('https://person@example.invalid/?token=fake-secret') }
            return @{ StatusCode = 200; Content = '{"person@example.invalid": fake-secret' }
        }
        try { Invoke-RepositoryLabelApi -Path repos/owner/repo/labels }
        catch { $Message = $_.Exception.Message }
        $Message | Should -BeLike $Expected
        $Message | Should -Not -Match 'person@|fake-secret'
    }
}

Describe 'Label workflow and fixture contracts' -Tag 'Unit' {
    It 'Runs the in-repository script with minimum permissions and serialized jobs' {
        $Workflow = Get-Content -Raw (Join-Path $script:RepoRoot '.github/workflows/label-sync.yml') | ConvertFrom-Yaml
        $Workflow.permissions.Count | Should -Be 1
        $Workflow.permissions.contents | Should -Be read
        $Job = $Workflow.jobs.'sync-labels'
        $Job.permissions.Count | Should -Be 2
        $Job.permissions.issues | Should -Be write
        $Workflow.concurrency.'cancel-in-progress' | Should -BeFalse
        $Workflow.concurrency.group | Should -Be '${{ github.workflow }}'
        $Workflow.on.Keys | Should -Contain workflow_dispatch
        $Workflow.on.push.paths | Should -Contain 'scripts/ci/Sync-RepositoryLabels.ps1'
        $Sync = $Job.steps | Where-Object name -eq 'Sync labels'
        $Sync.shell | Should -Be pwsh
        $Sync.run | Should -Be './scripts/ci/Sync-RepositoryLabels.ps1'
        $Sync.env.GH_TOKEN | Should -Be '${{ secrets.GITHUB_TOKEN }}'
        @($Job.steps | Where-Object { $_.uses -like 'EndBug/*' }).Count | Should -Be 0
        ($Job.steps | Where-Object { $_.uses -like 'actions/checkout@*' }).with.'persist-credentials' | Should -BeFalse
        @($Job.steps | Where-Object uses -eq './.github/actions/setup-ps-modules').Count | Should -Be 1
    }

    It 'Exposes the script through the package entrypoint without dependency changes' {
        $Package = Get-Content -Raw (Join-Path $script:RepoRoot 'package.json') | ConvertFrom-Json
        $Package.scripts.'labels:sync' | Should -Be 'pwsh -NoProfile -File scripts/ci/Sync-RepositoryLabels.ps1'
    }

    It 'Pins the fixture image while retaining the asserted action-pinning weakness' {
        $Root = Join-Path $script:RepoRoot 'evals/agent-behavior'
        $Docker = Get-Content -Raw (Join-Path $Root 'fixtures/sssc-smoke/Dockerfile.fixture')
        $Docker | Should -Match '^FROM node:22-alpine@sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402'
        $Release = Get-Content -Raw (Join-Path $Root 'fixtures/sssc-smoke/release-workflow.fixture')
        $Release | Should -Match 'actions/checkout@v4'
        $Release | Should -Match 'actions/setup-node@v4'
        $Stimulus = Get-Content -Raw (Join-Path $Root 'stimuli/sssc-reviewer.yml')
        $Stimulus | Should -Match 'const actionable = /actions'
    }
}
