#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/validate-topics.ps1'

    # Dot-source the script. The main-execution guard is skipped when
    # InvocationName is '.', so no `exit` runs and every internal function is
    # imported into this scope. A valid -Path is required to satisfy the
    # Mandatory + Container ValidateScript at bind time; $PSScriptRoot is a
    # guaranteed-existing directory.
    . $script:ScriptPath -Path $PSScriptRoot

    # Ordinal, case-sensitive allow-prefix set matching the script default.
    function New-AllowSet {
        param([string[]]$Prefixes = @('System', 'Topic', 'Global', 'Env'))
        [System.Collections.Generic.HashSet[string]]::new([string[]]$Prefixes, [System.StringComparer]::Ordinal)
    }

    # Create a fresh, isolated scaffold root with a workspace/topics subtree.
    function New-Workspace {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $topics = Join-Path (Join-Path $root 'workspace') 'topics'
        New-Item -ItemType Directory -Path $topics -Force | Out-Null
        [pscustomobject]@{ Root = $root; Topics = $topics }
    }

    # Write a topic file into a topics directory.
    function Set-Topic {
        param(
            [string]$Directory,
            [string]$Name,
            [string]$Content
        )
        $path = Join-Path $Directory $Name
        Set-Content -LiteralPath $path -Value $Content -Encoding utf8
        $path
    }

    # Write a state.json under a .copilot-tracking directory beneath the root.
    function Set-TrackingState {
        param(
            [string]$Root,
            [string]$Json
        )
        $dir = Join-Path $Root '.copilot-tracking'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $path = Join-Path $dir 'state.json'
        Set-Content -LiteralPath $path -Value $Json -Encoding utf8
        $path
    }

    # Ready-made valid custom topic body.
    function Get-ValidCustomTopic {
        @"
mcs.metadata:
  componentName: GoodTopic
  description: A well-formed custom topic.
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
  actions:
    - kind: SendActivity
      activity: "Your balance is {Global.balance}"
"@
    }
}

Describe 'Get-NormalizedName' {
    It 'strips whitespace and lowercases' {
        Get-NormalizedName -Value 'Thank You' | Should -BeExactly 'thankyou'
    }

    It 'returns empty string for null input' {
        Get-NormalizedName -Value $null | Should -BeExactly ''
    }
}

Describe 'Get-MapValue' {
    It 'returns the value for a matching key' {
        $m = @{ kind = 'AdaptiveDialog' }
        Get-MapValue -Map $m -Key 'kind' | Should -BeExactly 'AdaptiveDialog'
    }

    It 'is case-sensitive on the key' {
        $m = @{ Kind = 'AdaptiveDialog' }
        Get-MapValue -Map $m -Key 'kind' | Should -BeNullOrEmpty
    }

    It 'returns null when the map is not a dictionary' {
        Get-MapValue -Map 'not-a-map' -Key 'kind' | Should -BeNullOrEmpty
    }

    It 'returns null for a missing key' {
        Get-MapValue -Map @{ a = 1 } -Key 'b' | Should -BeNullOrEmpty
    }
}

Describe 'Test-LegitSystemTopic' {
    It 'is true when a system trigger matches its canonical name in filename and componentName' {
        Test-LegitSystemTopic -TriggerKind 'OnEscalate' -Base 'Escalate' -ComponentName 'Escalate' | Should -BeTrue
    }

    It 'is true when a system trigger matches its display name in filename and componentName' {
        Test-LegitSystemTopic -TriggerKind 'OnError' -Base 'On Error' -ComponentName 'On Error' | Should -BeTrue
    }

    It 'is false when the filename base does not match the canonical/display name' {
        Test-LegitSystemTopic -TriggerKind 'OnEscalate' -Base 'Fraud' -ComponentName 'Escalate' | Should -BeFalse
    }

    It 'is false when the componentName does not match even though the filename does' {
        # Fail-open hole this fix closes: canonical filename + custom componentName.
        Test-LegitSystemTopic -TriggerKind 'OnError' -Base 'OnError' -ComponentName 'RefundHandler' | Should -BeFalse
    }

    It 'is false when componentName is null or empty' {
        Test-LegitSystemTopic -TriggerKind 'OnError' -Base 'OnError' -ComponentName $null | Should -BeFalse
        Test-LegitSystemTopic -TriggerKind 'OnError' -Base 'OnError' -ComponentName '' | Should -BeFalse
    }

    It 'is false for a non-system trigger kind' {
        Test-LegitSystemTopic -TriggerKind 'OnRecognizedIntent' -Base 'Anything' -ComponentName 'Anything' | Should -BeFalse
    }

    It 'is case-sensitive on the base name' {
        Test-LegitSystemTopic -TriggerKind 'OnEscalate' -Base 'escalate' -ComponentName 'Escalate' | Should -BeFalse
    }

    It 'is case-sensitive on the componentName' {
        Test-LegitSystemTopic -TriggerKind 'OnEscalate' -Base 'Escalate' -ComponentName 'escalate' | Should -BeFalse
    }
}

Describe 'Get-McsFile and Test-DirHasMcs' {
    It 'returns sorted *.mcs.yml files and ignores others' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'Beta.mcs.yml' -Content 'k: v' | Out-Null
        Set-Topic -Directory $ws.Topics -Name 'Alpha.mcs.yml' -Content 'k: v' | Out-Null
        Set-Topic -Directory $ws.Topics -Name 'notes.txt' -Content 'ignore' | Out-Null

        $files = @(Get-McsFile -Directory $ws.Topics)
        $files.Count | Should -Be 2
        (Split-Path $files[0] -Leaf) | Should -BeExactly 'Alpha.mcs.yml'
        (Split-Path $files[1] -Leaf) | Should -BeExactly 'Beta.mcs.yml'
    }

    It 'Test-DirHasMcs is false for an empty directory' {
        $ws = New-Workspace
        Test-DirHasMcs -Directory $ws.Topics | Should -BeFalse
    }

    It 'Get-McsFile returns empty for a nonexistent directory' {
        @(Get-McsFile -Directory (Join-Path $TestDrive 'nope-missing')).Count | Should -Be 0
    }
}

Describe 'Find-UndeclaredToken' {
    BeforeAll { $script:Allow = New-AllowSet }

    It 'flags a token whose first segment is not a declared prefix' {
        $doc = ConvertFrom-Yaml 'k: "hi {Foo.Bar}"'
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow) | Should -Contain '{Foo.Bar}'
    }

    It 'flags a bare identifier token that is not declared' {
        $doc = ConvertFrom-Yaml 'k: "hi {balance}"'
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow) | Should -Contain '{balance}'
    }

    It 'accepts a declared namespace token' {
        $doc = ConvertFrom-Yaml 'k: "hi {System.Bot.Name}"'
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow).Count | Should -Be 0
    }

    It 'accepts a declared dotted token' {
        $doc = ConvertFrom-Yaml 'k: "hi {Global.balance}"'
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow).Count | Should -Be 0
    }

    It 'ignores Power Fx expression scalars starting with =' {
        $doc = ConvertFrom-Yaml 'k: "=Concat({Foo.Bar})"'
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow).Count | Should -Be 0
    }

    It 'ignores Adaptive-Card / JSON braces whose inner text is not an identifier path' {
        $doc = ConvertFrom-Yaml 'k: ''{ "type": "AdaptiveCard" }'''
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow).Count | Should -Be 0
    }

    It 'ignores prose braces that are not identifier paths' {
        $doc = ConvertFrom-Yaml 'k: "see {the manual} please"'
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow).Count | Should -Be 0
    }

    It 'does not scan the mcs.metadata subtree' {
        $doc = ConvertFrom-Yaml @"
mcs.metadata:
  componentName: X
  description: "uses {Foo.Bar}"
kind: AdaptiveDialog
"@
        @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow).Count | Should -Be 0
    }

    It 'walks nested lists and dictionaries' {
        $doc = ConvertFrom-Yaml @"
beginDialog:
  actions:
    - activity: "one {Foo.A}"
    - nested:
        - "two {Bar.B}"
"@
        $bad = @(Find-UndeclaredToken -Doc $doc -AllowSet $script:Allow)
        $bad | Should -Contain '{Foo.A}'
        $bad | Should -Contain '{Bar.B}'
    }
}

Describe 'Test-Topic' {
    BeforeAll { $script:Allow = New-AllowSet }

    It 'passes a fully valid custom topic' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'GoodTopic.mcs.yml' -Content (Get-ValidCustomTopic)
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $r.fails.Count | Should -Be 0
        $r.triggerKind | Should -BeExactly 'OnRecognizedIntent'
        $r.componentName | Should -BeExactly 'GoodTopic'
    }

    It 'passes a legitimate system topic' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'Escalate.mcs.yml' -Content @"
mcs.metadata:
  componentName: Escalate
  description: The built-in escalate topic.
kind: AdaptiveDialog
beginDialog:
  kind: OnEscalate
  id: main
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $r.fails.Count | Should -Be 0
        $r.isLegitSystem | Should -BeTrue
    }

    It 'fails system-trigger-collision for a custom-named file with a system trigger' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'MyEscalation.mcs.yml' -Content @"
mcs.metadata:
  componentName: MyEscalation
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnEscalate
  id: main
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $invariants = @($r.fails | ForEach-Object { $_.invariant })
        $invariants | Should -Contain 'system-trigger-collision'
        ($r.fails | Where-Object { $_.invariant -eq 'system-trigger-collision' }).message |
            Should -BeLike "*will collapse into the built-in 'Escalate' topic on pack*"
    }

    It 'fails reserved-name-collision for a custom topic whose componentName is a built-in name' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'Escalate.mcs.yml' -Content @"
mcs.metadata:
  componentName: Escalate
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        @($r.fails | ForEach-Object { $_.invariant }) | Should -Contain 'reserved-name-collision'
    }

    It 'fails filename-mismatch when the base differs from componentName' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'WrongName.mcs.yml' -Content @"
mcs.metadata:
  componentName: DifferentName
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $mismatch = $r.fails | Where-Object { $_.invariant -eq 'filename-mismatch' }
        $mismatch | Should -Not -BeNullOrEmpty
        $mismatch.message | Should -BeLike "*filename 'WrongName' != componentName 'DifferentName'*"
    }

    It 'reports every schema-skeleton miss with the exact labels' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'Broken.mcs.yml' -Content @"
mcs.metadata:
  description: has description but no componentName
kind: SomethingElse
beginDialog:
  id: notmain
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $skeleton = $r.fails | Where-Object { $_.invariant -eq 'schema-skeleton' }
        $skeleton | Should -Not -BeNullOrEmpty
        $skeleton.message | Should -BeLike '*mcs.metadata.componentName*'
        $skeleton.message | Should -BeLike '*kind: AdaptiveDialog*'
        $skeleton.message | Should -BeLike '*beginDialog.kind*'
        $skeleton.message | Should -BeLike '*beginDialog.id: main*'
    }

    It 'emits a description-missing WARN without failing when nothing else is wrong' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'NoDesc.mcs.yml' -Content @"
mcs.metadata:
  componentName: NoDesc
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $r.fails.Count | Should -Be 0
        @($r.warns | ForEach-Object { $_.invariant }) | Should -Contain 'schema-skeleton'
        $r.warns[0].message | Should -BeExactly 'mcs.metadata.description missing'
    }

    It 'fails undeclared-tokens for an unknown namespace' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'TokenTopic.mcs.yml' -Content @"
mcs.metadata:
  componentName: TokenTopic
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
  actions:
    - activity: "hello {Foo.Bar}"
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $tok = $r.fails | Where-Object { $_.invariant -eq 'undeclared-tokens' }
        $tok | Should -Not -BeNullOrEmpty
        $tok.message | Should -BeLike '*undeclared token(s): {Foo.Bar}*'
    }

    It 'reports multiple undeclared tokens in deterministic sorted order' {
        $ws = New-Workspace
        # Authored out of order (Zeta before Alpha before Mu) to prove the
        # reported list is sorted, not source-ordered.
        $f = Set-Topic -Directory $ws.Topics -Name 'MultiToken.mcs.yml' -Content @"
mcs.metadata:
  componentName: MultiToken
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
  actions:
    - activity: "one {Zeta.value} two {Alpha.value} three {Mu.value}"
"@
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $tok = $r.fails | Where-Object { $_.invariant -eq 'undeclared-tokens' }
        $tok | Should -Not -BeNullOrEmpty
        $tok.message | Should -BeExactly 'undeclared token(s): {Alpha.value}, {Mu.value}, {Zeta.value}'
    }

    It 'fails schema-parse and sets parseError on invalid YAML' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'Bad.mcs.yml' -Content "foo: [unclosed`nbar: : :"
        $r = Test-Topic -File $f -AllowSet $script:Allow
        $r.parseError | Should -BeTrue
        @($r.fails | ForEach-Object { $_.invariant }) | Should -Contain 'schema-parse'
    }

    It 'fails schema-skeleton when the document is not a mapping' {
        $ws = New-Workspace
        $f = Set-Topic -Directory $ws.Topics -Name 'Scalar.mcs.yml' -Content 'just-a-scalar'
        $r = Test-Topic -File $f -AllowSet $script:Allow
        ($r.fails | Where-Object { $_.invariant -eq 'schema-skeleton' }).message |
            Should -BeExactly 'file does not parse to a mapping'
    }

    It 'fails io when the file cannot be read as text' {
        $ws = New-Workspace
        # Pointing Test-Topic at a directory triggers the read-failure path.
        $r = Test-Topic -File $ws.Topics -AllowSet $script:Allow
        @($r.fails | ForEach-Object { $_.invariant }) | Should -Contain 'io'
    }
}

Describe 'Test-DuplicateSystemTrigger' {
    BeforeAll { $script:Allow = New-AllowSet }

    It 'fails both topics that share a system trigger kind' {
        $ws = New-Workspace
        $a = Set-Topic -Directory $ws.Topics -Name 'OnError.mcs.yml' -Content @"
mcs.metadata:
  componentName: OnError
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnError
  id: main
"@
        $b = Set-Topic -Directory $ws.Topics -Name 'AlsoError.mcs.yml' -Content @"
mcs.metadata:
  componentName: AlsoError
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnError
  id: main
"@
        $results = @(
            (Test-Topic -File $a -AllowSet $script:Allow),
            (Test-Topic -File $b -AllowSet $script:Allow)
        )
        Test-DuplicateSystemTrigger -Results $results
        foreach ($r in $results) {
            @($r.fails | ForEach-Object { $_.invariant }) | Should -Contain 'duplicate-system-trigger'
        }
    }
}

Describe 'Test-ComponentNameUniqueness' {
    BeforeAll { $script:Allow = New-AllowSet }

    It 'fails both topics that share a componentName' {
        $ws = New-Workspace
        $a = Set-Topic -Directory $ws.Topics -Name 'Shared.mcs.yml' -Content @"
mcs.metadata:
  componentName: Shared
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
"@
        $b = Set-Topic -Directory $ws.Topics -Name 'Shared2.mcs.yml' -Content @"
mcs.metadata:
  componentName: Shared
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
"@
        $results = @(
            (Test-Topic -File $a -AllowSet $script:Allow),
            (Test-Topic -File $b -AllowSet $script:Allow)
        )
        Test-ComponentNameUniqueness -Results $results
        foreach ($r in $results) {
            ($r.fails | Where-Object { $_.invariant -eq 'componentName-uniqueness' }).message |
                Should -BeLike "*componentName 'Shared' is shared by 2 topics*"
        }
    }
}

Describe 'Get-TopicCountReconciliation' {
    It 'reports ok when the count matches' {
        $results = @([pscustomobject]@{ triggerKind = 'OnRecognizedIntent' })
        $state = Join-Path $TestDrive 'st-match.json'
        Set-Content -LiteralPath $state -Value '{"phases":{"topics":{"topicCount":1}}}' -Encoding utf8
        $recon = Get-TopicCountReconciliation -StatePath $state -Results $results
        $recon.ok | Should -BeTrue
        $recon.warn | Should -BeFalse
        $recon.message | Should -BeLike '*topicCount=1 vs custom (OnRecognizedIntent) topic files=1*'
    }

    It 'reports not-ok when the count mismatches' {
        $results = @([pscustomobject]@{ triggerKind = 'OnRecognizedIntent' })
        $state = Join-Path $TestDrive 'st-mismatch.json'
        Set-Content -LiteralPath $state -Value '{"phases":{"topics":{"topicCount":5}}}' -Encoding utf8
        $recon = Get-TopicCountReconciliation -StatePath $state -Results $results
        $recon.ok | Should -BeFalse
        $recon.error | Should -BeNullOrEmpty
    }

    It 'warns when topicCount is absent' {
        $results = @([pscustomobject]@{ triggerKind = 'OnRecognizedIntent' })
        $state = Join-Path $TestDrive 'st-absent.json'
        Set-Content -LiteralPath $state -Value '{"phases":{"topics":{}}}' -Encoding utf8
        $recon = Get-TopicCountReconciliation -StatePath $state -Results $results
        $recon.warn | Should -BeTrue
        $recon.ok | Should -BeTrue
        $recon.message | Should -BeLike '*absent; reconciliation skipped*'
    }

    It 'errors when topicCount is non-numeric' {
        $results = @([pscustomobject]@{ triggerKind = 'OnRecognizedIntent' })
        $state = Join-Path $TestDrive 'st-nonnum.json'
        Set-Content -LiteralPath $state -Value '{"phases":{"topics":{"topicCount":"three"}}}' -Encoding utf8
        $recon = Get-TopicCountReconciliation -StatePath $state -Results $results
        $recon.ok | Should -BeFalse
        $recon.error | Should -BeLike '*non-numeric*cannot reconcile*'
    }

    It 'errors when state.json cannot be parsed' {
        $results = @([pscustomobject]@{ triggerKind = 'OnRecognizedIntent' })
        $state = Join-Path $TestDrive 'st-broken.json'
        Set-Content -LiteralPath $state -Value '{ this is : not json ]' -Encoding utf8
        $recon = Get-TopicCountReconciliation -StatePath $state -Results $results
        $recon.ok | Should -BeFalse
        $recon.error | Should -BeLike '*cannot read/parse state.json*'
    }

    It 'counts only OnRecognizedIntent topics as custom' {
        $results = @(
            [pscustomobject]@{ triggerKind = 'OnRecognizedIntent' },
            [pscustomobject]@{ triggerKind = 'OnEscalate' },
            [pscustomobject]@{ triggerKind = $null }
        )
        $state = Join-Path $TestDrive 'st-count.json'
        Set-Content -LiteralPath $state -Value '{"phases":{"topics":{"topicCount":1}}}' -Encoding utf8
        $recon = Get-TopicCountReconciliation -StatePath $state -Results $results
        $recon.customCount | Should -Be 1
        $recon.ok | Should -BeTrue
    }
}

Describe 'Resolve-TopicSet' {
    It 'prefers an immediate workspace/topics directory' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'A.mcs.yml' -Content 'k: v' | Out-Null
        $set = Resolve-TopicSet -Path $ws.Root
        $set.TopicsDir | Should -Be (Resolve-Path -LiteralPath $ws.Topics).ProviderPath
        $set.Files.Count | Should -Be 1
    }

    It 'discovers a nested workspace/topics tree' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $nested = Join-Path (Join-Path (Join-Path (Join-Path $root 'a') 'b') 'workspace') 'topics'
        New-Item -ItemType Directory -Path $nested -Force | Out-Null
        Set-Topic -Directory $nested -Name 'A.mcs.yml' -Content 'k: v' | Out-Null
        $set = Resolve-TopicSet -Path $root
        $set.TopicsDir | Should -Be (Resolve-Path -LiteralPath $nested).ProviderPath
    }

    It 'treats a bare directory of *.mcs.yml files as the topic set' {
        $loose = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $loose -Force | Out-Null
        Set-Topic -Directory $loose -Name 'Loose.mcs.yml' -Content 'k: v' | Out-Null
        $set = Resolve-TopicSet -Path $loose
        $set.TopicsDir | Should -Be (Resolve-Path -LiteralPath $loose).ProviderPath
        $set.Files.Count | Should -Be 1
    }

    It 'throws when no *.mcs.yml files are found' {
        $empty = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        { Resolve-TopicSet -Path $empty } | Should -Throw '*no *.mcs.yml topic files found*'
    }
}

Describe 'Find-StateFile' {
    It 'finds a state.json inside a .copilot-tracking directory' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $expected = Set-TrackingState -Root $root -Json '{}'
        (Find-StateFile -Root $root) | Should -Be (Resolve-Path -LiteralPath $expected).ProviderPath
    }

    It 'falls back to a top-level state.json' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $top = Join-Path $root 'state.json'
        Set-Content -LiteralPath $top -Value '{}' -Encoding utf8
        (Find-StateFile -Root $root) | Should -Be $top
    }

    It 'returns null when no state.json exists' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Find-StateFile -Root $root | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-TopicIntegrityGate' {
    It 'returns 0 and reports PASS for a clean scaffold with a reconciling state' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'GoodTopic.mcs.yml' -Content (Get-ValidCustomTopic) | Out-Null
        Set-TrackingState -Root $ws.Root -Json '{"phases":{"topics":{"topicCount":1}}}' | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 0
        $report | Should -BeLike '*PASS  GoodTopic.mcs.yml*'
        $report | Should -BeLike '*SCAFFOLD PASS  topicCount-reconciliation*'
        $report | Should -BeLike '*1 topics, 1 pass, 0 fail*'
    }

    It 'returns 1 and reports FAIL for a failing topic with no state' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'MyEscalation.mcs.yml' -Content @"
mcs.metadata:
  componentName: MyEscalation
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnEscalate
  id: main
"@ | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 1
        # Bracket-bearing substring: use an escaped regex match because -BeLike
        # would interpret [system-trigger-collision] as a wildcard char class.
        $report | Should -Match ([regex]::Escape('FAIL  MyEscalation.mcs.yml  [system-trigger-collision]'))
        $report | Should -BeLike '*SCAFFOLD ----  topicCount-reconciliation: no state.json found (skipped)*'
    }

    It 'returns 1 and appends the reconciliation-fail suffix on a count mismatch' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'GoodTopic.mcs.yml' -Content (Get-ValidCustomTopic) | Out-Null
        Set-TrackingState -Root $ws.Root -Json '{"phases":{"topics":{"topicCount":9}}}' | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 1
        $report | Should -BeLike '*SCAFFOLD FAIL  topicCount-reconciliation*'
        $report | Should -BeLike '*+ topicCount-reconciliation FAIL*'
    }

    It 'returns 0 and reports SCAFFOLD WARN when topicCount is absent' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'GoodTopic.mcs.yml' -Content (Get-ValidCustomTopic) | Out-Null
        Set-TrackingState -Root $ws.Root -Json '{"phases":{"topics":{}}}' | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 0
        $report | Should -BeLike '*SCAFFOLD WARN  topicCount-reconciliation*'
    }

    It 'returns 2 when any topic has a YAML parse error' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'Bad.mcs.yml' -Content "foo: [unclosed`nbar: : :" | Out-Null
        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $code | Should -Be 2
    }

    It 'emits a WARN line in the report for a description-missing topic' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'NoDesc.mcs.yml' -Content @"
mcs.metadata:
  componentName: NoDesc
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
"@ | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 0
        $report | Should -BeLike '*warn schema-skeleton: mcs.metadata.description missing*'
    }

    It 'honors an explicit -StatePath over auto-discovery' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'GoodTopic.mcs.yml' -Content (Get-ValidCustomTopic) | Out-Null
        $explicit = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.json')
        Set-Content -LiteralPath $explicit -Value '{"phases":{"topics":{"topicCount":1}}}' -Encoding utf8

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -StatePath $explicit -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 0
        $report | Should -BeLike '*SCAFFOLD PASS  topicCount-reconciliation*'
    }

    It 'writes a JSON report with the documented shape' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'GoodTopic.mcs.yml' -Content (Get-ValidCustomTopic) | Out-Null
        Set-TrackingState -Root $ws.Root -Json '{"phases":{"topics":{"topicCount":1}}}' | Out-Null
        $jsonOut = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.json')

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -JsonOut $jsonOut -InformationVariable inf
        $code | Should -Be 0
        Test-Path -LiteralPath $jsonOut | Should -BeTrue

        $payload = Get-Content -LiteralPath $jsonOut -Raw | ConvertFrom-Json
        $payload.target | Should -Not -BeNullOrEmpty
        $payload.summary.topics | Should -Be 1
        $payload.summary.pass | Should -Be 1
        $payload.summary.fail | Should -Be 0
        $payload.summary.reconciliationFailed | Should -BeFalse
        $payload.results[0].file | Should -BeExactly 'GoodTopic.mcs.yml'
        $payload.results[0].pass | Should -BeTrue
        $payload.results[0].triggerKind | Should -BeExactly 'OnRecognizedIntent'
    }

    It 'uses a custom -AllowPrefix set' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'CustomPrefix.mcs.yml' -Content @"
mcs.metadata:
  componentName: CustomPrefix
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
  actions:
    - activity: "value {Widget.count}"
"@ | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -AllowPrefix @('Widget') -InformationVariable inf
        $code | Should -Be 0
    }

    It 'FAILs a canonical-filename topic whose componentName is custom (fail-open hole)' {
        # OnError.mcs.yml + componentName RefundHandler + kind OnError collapses
        # into the built-in On Error topic on `pac copilot pack`, so it MUST fail
        # the system-trigger-collision gate rather than pass as a legit customization.
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'OnError.mcs.yml' -Content @"
mcs.metadata:
  componentName: RefundHandler
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnError
  id: main
"@ | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 1
        $report | Should -Match ([regex]::Escape('FAIL  OnError.mcs.yml'))
        $report | Should -Match 'system-trigger-collision'
    }

    It 'PASSes a genuine system-topic customization (filename == componentName == canonical)' {
        $ws = New-Workspace
        Set-Topic -Directory $ws.Topics -Name 'OnError.mcs.yml' -Content @"
mcs.metadata:
  componentName: OnError
  description: d
kind: AdaptiveDialog
beginDialog:
  kind: OnError
  id: main
"@ | Out-Null

        $code = Invoke-TopicIntegrityGate -Path $ws.Root -InformationVariable inf
        $report = ($inf | ForEach-Object { $_.ToString() }) -join "`n"

        $code | Should -Be 0
        $report | Should -BeLike '*PASS  OnError.mcs.yml*'
    }
}

Describe 'Test-YamlModuleAvailable' {
    It 'returns $false when powershell-yaml is not discoverable' {
        Mock Get-Module { $null } -ParameterFilter { $ListAvailable }
        Test-YamlModuleAvailable | Should -BeFalse
    }

    It 'returns $true when Get-Module reports the module' {
        Mock Get-Module { [pscustomobject]@{ Name = 'powershell-yaml' } } -ParameterFilter { $ListAvailable }
        Test-YamlModuleAvailable | Should -BeTrue
    }
}

Describe 'Script parameter validation' {
    It 'rejects a nonexistent -Path via ValidateScript' {
        { & $script:ScriptPath -Path (Join-Path $TestDrive 'definitely-missing-dir') } | Should -Throw
    }

    It 'surfaces an invalid -Path as a non-zero (fail-closed) child-process exit' {
        # Pin divergence #1: an invalid -Path fails ValidateScript binding, which
        # `pwsh -File` reports as exit 1 (never a silent 0).
        $pwsh = [System.Environment]::ProcessPath
        $missing = Join-Path $TestDrive 'definitely-missing-dir'
        & $pwsh -NoProfile -File $script:ScriptPath -Path $missing *> $null
        $LASTEXITCODE | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 1
    }

    It 'exits 2 (not 1) in a child process when powershell-yaml is unavailable' {
        # Fix 2: a missing dependency is a fail-closed environment error and MUST
        # exit 2. Scrub PSModulePath so Get-Module -ListAvailable finds nothing,
        # then invoke against a valid -Path so binding succeeds and the top-level
        # dependency guard is the code path that decides the exit.
        $pwsh = [System.Environment]::ProcessPath
        $emptyModuleDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $emptyModuleDir -Force | Out-Null
        $validPath = [string]$TestDrive
        # Set PSModulePath at runtime inside the child (a -File child would have
        # PSModulePath re-augmented with the default module paths at startup,
        # re-exposing powershell-yaml). The script's `exit 2` sets $LASTEXITCODE
        # within the -Command scope; the trailing `exit $LASTEXITCODE` (with the
        # guard's error stream redirected) propagates it as the process exit code.
        $command = "`$env:PSModulePath = '$emptyModuleDir'; & '$($script:ScriptPath)' -Path '$validPath' 2>`$null; exit `$LASTEXITCODE"
        & $pwsh -NoProfile -Command $command *> $null
        $LASTEXITCODE | Should -Be 2
    }
}
