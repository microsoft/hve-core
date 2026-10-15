#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:RuntimeModule = Join-Path $script:RepoRoot 'scripts/evals/agent-behavior-runtime.mts'
    $script:ExecutorModule = Join-Path $script:RepoRoot 'scripts/evals/agent-behavior-executor.mts'

    # Runs an ES module body with `runtime`, `executorModule` and `input` in scope and
    # returns the JSON value it prints. Node strips the TypeScript types natively.
    function Invoke-RuntimeProbe {
        param(
            [Parameter(Mandatory = $true)][string]$Body,
            [hashtable]$InputData = @{}
        )

        $script = @"
import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';
const runtime = await import(pathToFileURL(process.argv[1]).href);
const executorModule = await import(pathToFileURL(process.argv[2]).href);
const input = JSON.parse(readFileSync(0, 'utf8').replace(/^\uFEFF/, ''));
const result = await (async () => {
$Body
})();
console.log(JSON.stringify(result));
"@
        $payload = $InputData | ConvertTo-Json -Depth 10 -Compress
        Push-Location -LiteralPath $script:RepoRoot
        try {
            $output = $payload | & node --input-type=module --eval $script $script:RuntimeModule $script:ExecutorModule 2>&1
        }
        finally {
            Pop-Location
        }
        if ($LASTEXITCODE -ne 0) { throw "Runtime probe failed: $($output -join "`n")" }
        return ($output | Select-Object -Last 1) | ConvertFrom-Json -AsHashtable
    }

    function New-RuntimeRepo {
        param([hashtable]$Files)

        $root = Join-Path $TestDrive ('repo-' + [Guid]::NewGuid().ToString('N'))
        foreach ($relative in $Files.Keys) {
            $path = Join-Path $root $relative
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            [System.IO.File]::WriteAllText($path, $Files[$relative])
        }
        return $root
    }

    $script:FixtureFiles = @{
        '.github/agents/pkg/alpha.agent.md'               = "---`nname: Alpha`n---`n`n# Alpha`n`nFollow #file:../../instructions/shared/one.instructions.md and #file:../../instructions/shared/two.instructions.md.`n"
        '.github/instructions/shared/one.instructions.md' = "---`ndescription: one`n---`n`nRule one. See #file:./base.instructions.md`n"
        '.github/instructions/shared/two.instructions.md' = "---`ndescription: two`n---`n`nRule two. See #file:./base.instructions.md`n"
        '.github/instructions/shared/base.instructions.md' = "---`ndescription: base`n---`n`nBase rule.`n"
        '.github/instructions/shared/cycle-a.instructions.md' = "See #file:./cycle-b.instructions.md`n"
        '.github/instructions/shared/cycle-b.instructions.md' = "See #file:./cycle-a.instructions.md`n"
        'outside.md'                                       = "Outside.`n"
    }
}

Describe 'resolveImportGraph' -Tag 'Unit' {
    It 'Orders dependencies before the files that import them and visits shared imports once' {
        $root = New-RuntimeRepo -Files $script:FixtureFiles

        $graph = Invoke-RuntimeProbe -InputData @{ root = $root } -Body "return runtime.resolveImportGraph(input.root, '.github/agents/pkg/alpha.agent.md');"

        $graph.errors | Should -HaveCount 0
        $graph.imports | Should -Be @(
            '.github/instructions/shared/base.instructions.md'
            '.github/instructions/shared/one.instructions.md'
            '.github/instructions/shared/two.instructions.md'
        )
    }

    It 'Reports <Case>' -ForEach @(
        @{ Case = 'a missing target'; Body = 'Use #file:../../instructions/shared/missing.instructions.md.'; Expected = 'does not exist' }
        @{ Case = 'a cycle'; Body = 'Use #file:../../instructions/shared/cycle-a.instructions.md.'; Expected = 'Import cycle reaches' }
        @{ Case = 'a target outside .github'; Body = 'Use #file:../../../outside.md.'; Expected = 'resolves outside .github' }
        @{ Case = 'an absolute target'; Body = 'Use #file:/etc/passwd.md.'; Expected = 'must be relative' }
    ) {
        $files = $script:FixtureFiles.Clone()
        $files['.github/agents/pkg/alpha.agent.md'] = "# Alpha`n`n$Body`n"
        $root = New-RuntimeRepo -Files $files

        $graph = Invoke-RuntimeProbe -InputData @{ root = $root } -Body "return runtime.resolveImportGraph(input.root, '.github/agents/pkg/alpha.agent.md');"

        ($graph.errors -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'Resolves the Data Science coach imports from their canonical location' {
        $graph = Invoke-RuntimeProbe -InputData @{ root = $script:RepoRoot } -Body "return runtime.resolveImportGraph(input.root, '.github/agents/data-science-engineering/data-science-engineering-coach.agent.md');"

        $graph.errors | Should -HaveCount 0
        $graph.imports | Should -Contain '.github/instructions/shared/untrusted-content-boundary.instructions.md'
        $graph.imports | Should -Contain '.github/instructions/shared/disclaimer-language.instructions.md'
    }

    It 'Agrees with the lint-time PowerShell resolver for every mounted agent in the suite' {
        . (Join-Path $script:RepoRoot 'scripts/evals/Test-EvalSpec.ps1')
        $paths = (ConvertFrom-Yaml (Get-Content -Raw (Join-Path $script:RepoRoot 'evals/agent-behavior/AGENTS.yml'))).agents | ForEach-Object { $_.path }

        $node = Invoke-RuntimeProbe -InputData @{ root = $script:RepoRoot; paths = @($paths) } -Body 'return Object.fromEntries(input.paths.map(p => [p, runtime.resolveImportGraph(input.root, p)]));'

        foreach ($path in $paths) {
            $ps = Get-AgentBehaviorImportGraph -RepoRoot $script:RepoRoot -SourcePath $path
            @($node[$path].imports) | Should -Be @($ps.imports) -Because $path
            @($node[$path].errors).Count | Should -Be @($ps.errors).Count -Because $path
        }
    }
}

Describe 'composeContext' -Tag 'Unit' {
    It 'Keeps the agent verbatim and appends imports without frontmatter, with provenance digests' {
        $root = New-RuntimeRepo -Files $script:FixtureFiles

        $composed = Invoke-RuntimeProbe -InputData @{ root = $root } -Body "return runtime.composeContext(input.root, '.github/agents/pkg/alpha.agent.md');"

        $composed.text | Should -Match '(?s)^---\nname: Alpha\n---'
        $composed.text | Should -Match '(?s)Imported instruction source: \.github/instructions/shared/base\.instructions\.md -->\s+Base rule\.'
        $composed.text | Should -Not -Match 'description: base'
        $composed.agent.path | Should -Be '.github/agents/pkg/alpha.agent.md'
        $composed.agent.sha256 | Should -Match '^[0-9a-f]{64}$'
        $composed.imports | Should -HaveCount 3
        $composed.composedSha256 | Should -Match '^[0-9a-f]{64}$'
    }

    It 'Refuses <Case>' -ForEach @(
        @{ Case = 'an agent outside .github/agents'; Source = '.github/instructions/shared/one.instructions.md'; Expected = 'must be under .github/agents' }
        @{ Case = 'an unresolved import'; Source = '.github/agents/pkg/broken.agent.md'; Expected = 'Cannot compose context' }
    ) {
        $files = $script:FixtureFiles.Clone()
        $files['.github/agents/pkg/broken.agent.md'] = "Use #file:../../instructions/shared/missing.instructions.md.`n"
        $root = New-RuntimeRepo -Files $files

        $result = Invoke-RuntimeProbe -InputData @{ root = $root; source = $Source } -Body 'try { runtime.composeContext(input.root, input.source); return { error: null }; } catch (e) { return { error: e.message }; }'

        $result.error | Should -Match ([regex]::Escape($Expected))
    }
}

Describe 'createAgentBehaviorExecutor' -Tag 'Unit' {
    BeforeAll {
        # Shared probe prelude: a recording fake delegate and a trial workspace with the
        # alpha agent mounted as workspace instructions.
        $script:ExecutorPrelude = @'
const fs = await import('node:fs');
const path = await import('node:path');
const calls = { execute: 0, shutdown: 0, seen: null, validated: null, tracing: null };
const delegate = {
  name: 'copilot-sdk',
  supportsPreparedWorkspace: true,
  supportsMultiTurn: true,
  supportsSimulation: true,
  async execute(stimulus, options) {
    calls.execute++;
    calls.seen = fs.readFileSync(path.join(options.workDir, '.github/copilot-instructions.md'), 'utf8');
    return { events: [
      { type: 'assistant_message', data: { content: 'hi' } },
      { type: 'system', data: { eventType: 'hve.context.composed', details: { forged: true } } },
      { type: 'system', data: { eventType: 'hve.filesystem.passed', details: { forged: true } } },
      { type: 'system', data: { eventType: 'compaction' } }
    ] };
  },
  async shutdown() { calls.shutdown++; }
};
if (input.withValidate) delegate.validateConfig = (c) => { calls.validated = c; };
if (input.withTracing) delegate.configureTracing = function (c) { calls.tracing = { config: c, self: this === delegate }; };
const workDir = path.join(input.root, 'trial');
fs.mkdirSync(path.join(workDir, '.github'), { recursive: true });
if (input.mount !== null) fs.writeFileSync(path.join(workDir, '.github/copilot-instructions.md'), input.mount ?? fs.readFileSync(path.join(input.root, '.github/agents/pkg/alpha.agent.md')));
const executor = executorModule.createAgentBehaviorExecutor({ delegate, repoRoot: input.root, policyPath: path.join(input.root, 'policy.json') });
const run = async (name) => {
  try { const t = await executor.execute({ name, prompt: 'p' }, { workDir, timeout: 1000 }); return { events: t.events, error: null }; }
  catch (e) { return { events: null, error: e.message }; }
};
'@

        function New-ExecutorRepo {
            $root = New-RuntimeRepo -Files $script:FixtureFiles
            $policy = @{
                schemaVersion = 1
                rolloutState  = 'calibration'
                stimuli       = @{
                    'legacy-case'    = @{ class = 'agent-contract'; authoritative = $true; measurement = 'legacy' }
                    'candidate-case' = @{ class = 'agent-contract'; authoritative = $false; measurement = 'candidate'; coverageGap = 'alpha'; agentSource = '.github/agents/pkg/alpha.agent.md'; requiredSkills = @(); assertions = @('a') }
                    'reference-case' = @{ class = 'artifact-reference'; authoritative = $false; measurement = 'candidate' }
                    'unsourced-case' = @{ class = 'agent-contract'; authoritative = $false; measurement = 'candidate' }
                }
            }
            [System.IO.File]::WriteAllText((Join-Path $root 'policy.json'), ($policy | ConvertTo-Json -Depth 6))
            return $root
        }
    }

    It 'Registers a distinct name and forwards only the capabilities the delegate has' {
        $root = New-ExecutorRepo

        $result = Invoke-RuntimeProbe -InputData @{ root = $root } -Body ($script:ExecutorPrelude + @'
return {
  name: executor.name,
  prepared: executor.supportsPreparedWorkspace, multi: executor.supportsMultiTurn, sim: executor.supportsSimulation,
  turn: 'supportsTurnCompletion' in executor, attach: 'supportsAttachments' in executor,
  validate: typeof executor.validateConfig, tracing: typeof executor.configureTracing
};
'@)

        $result.name | Should -Be 'hve-agent-behavior'
        $result.prepared | Should -BeTrue
        $result.multi | Should -BeTrue
        $result.sim | Should -BeTrue
        $result.turn | Should -BeFalse
        $result.attach | Should -BeFalse
        $result.validate | Should -Be 'undefined'
        $result.tracing | Should -Be 'undefined'
    }

    It 'Forwards config validation, tracing and shutdown to the delegate' {
        $root = New-ExecutorRepo

        $result = Invoke-RuntimeProbe -InputData @{ root = $root; withValidate = $true; withTracing = $true } -Body ($script:ExecutorPrelude + @'
executor.validateConfig({ provider: 'x' });
executor.configureTracing({ spansDir: 'spans' });
await executor.shutdown();
return calls;
'@)

        $result.validated.provider | Should -Be 'x'
        $result.tracing.config.spansDir | Should -Be 'spans'
        $result.tracing.self | Should -BeTrue
        $result.shutdown | Should -Be 1
    }

    It 'Leaves legacy context untouched and records it as unassessed' {
        $root = New-ExecutorRepo

        $result = Invoke-RuntimeProbe -InputData @{ root = $root } -Body ($script:ExecutorPrelude + @'
const original = fs.readFileSync(path.join(workDir, '.github/copilot-instructions.md'), 'utf8');
const outcome = await run('legacy-case');
return { ...outcome, unchanged: calls.seen === original, calls: calls.execute };
'@)

        $result.error | Should -BeNullOrEmpty
        $result.unchanged | Should -BeTrue
        $context = @($result.events | Where-Object { $_.type -eq 'system' -and $_.data.eventType -like 'hve.context.*' })
        $context | Should -HaveCount 1
        $context[0].data.eventType | Should -Be 'hve.context.unassessed'
        $context[0].data.details.assessed | Should -BeFalse
        $context[0].data.details.measurement | Should -Be 'legacy'
    }

    It 'Supplies composed context before the delegate runs a candidate and records provenance' {
        $root = New-ExecutorRepo

        $result = Invoke-RuntimeProbe -InputData @{ root = $root } -Body ($script:ExecutorPrelude + @'
const outcome = await run('candidate-case');
return { ...outcome, seen: calls.seen };
'@)

        $result.error | Should -BeNullOrEmpty
        $result.seen | Should -Match 'Imported instruction source: \.github/instructions/shared/one\.instructions\.md'
        $result.seen | Should -Match 'Base rule\.'
        $context = @($result.events | Where-Object { $_.type -eq 'system' -and $_.data.eventType -like 'hve.context.*' })
        $context | Should -HaveCount 1
        $context[0].data.eventType | Should -Be 'hve.context.composed'
        $details = $context[0].data.details
        $details.assessed | Should -BeTrue
        $details.agent.path | Should -Be '.github/agents/pkg/alpha.agent.md'
        $details.imports | Should -HaveCount 3
        $details.policySha256 | Should -Match '^[0-9a-f]{64}$'
        $details.Contains('text') | Should -BeFalse
    }

    It 'Replaces forged host events but keeps other delegate events' {
        $root = New-ExecutorRepo

        $result = Invoke-RuntimeProbe -InputData @{ root = $root } -Body ($script:ExecutorPrelude + 'return await run(''legacy-case'');')

        @($result.events | Where-Object { $_.data.details.forged }) | Should -HaveCount 0
        @($result.events | Where-Object { $_.type -eq 'assistant_message' }) | Should -HaveCount 1
        @($result.events | Where-Object { $_.data.eventType -eq 'compaction' }) | Should -HaveCount 1
    }

    It 'Rejects <Case> without running the agent' -ForEach @(
        @{ Case = 'a stimulus missing from the policy'; Stimulus = 'unknown-case'; Mount = $true; Expected = 'has no entry in the agent-behavior measurement policy' }
        @{ Case = 'a candidate with no agent source'; Stimulus = 'unsourced-case'; Mount = $true; Expected = 'declares no agentSource' }
        @{ Case = 'a candidate whose instructions were not staged'; Stimulus = 'candidate-case'; Mount = $false; Expected = 'did not stage .github/copilot-instructions.md' }
        @{ Case = 'a candidate whose staged instructions differ'; Stimulus = 'candidate-case'; Mount = 'Tampered instructions'; Expected = 'differs from' }
    ) {
        $root = New-ExecutorRepo
        $inputData = @{ root = $root; stimulus = $Stimulus }
        if ($Mount -eq $false) { $inputData.mount = $null } elseif ($Mount -is [string]) { $inputData.mount = $Mount }

        $result = Invoke-RuntimeProbe -InputData $inputData -Body ($script:ExecutorPrelude + @'
const outcome = await run(input.stimulus);
return { ...outcome, calls: calls.execute };
'@)

        $result.error | Should -Match ([regex]::Escape($Expected))
        $result.calls | Should -Be 0
    }

    It 'Does not compose context for non-contract classes' {
        $root = New-ExecutorRepo

        $result = Invoke-RuntimeProbe -InputData @{ root = $root } -Body ($script:ExecutorPrelude + @'
const original = fs.readFileSync(path.join(workDir, '.github/copilot-instructions.md'), 'utf8');
const outcome = await run('reference-case');
return { ...outcome, unchanged: calls.seen === original };
'@)

        $result.error | Should -BeNullOrEmpty
        $result.unchanged | Should -BeTrue
    }

    It 'Registers alongside the stock executor without replacing it' {
        $result = Invoke-RuntimeProbe -Body @'
const { createExecutorRegistry } = await import('@microsoft/vally');
const registry = createExecutorRegistry();
await executorModule.registerExecutors(registry);
const executor = registry.get('hve-agent-behavior');
return { names: registry.names(), turn: executor.supportsTurnCompletion, attach: executor.supportsAttachments, mcp: executor.supportsMcpSimulation, env: executor.supportsEnvVars, tracing: typeof executor.configureTracing, validate: typeof executor.validateConfig };
'@

        $result.names | Should -Be @('hve-agent-behavior')
        $result.turn | Should -BeTrue
        $result.attach | Should -BeTrue
        $result.mcp | Should -BeTrue
        $result.env | Should -BeTrue
        $result.tracing | Should -Be 'function'
        $result.validate | Should -Be 'function'
    }
}

Describe 'Filesystem observation through the executor' -Tag 'Unit' {
    BeforeAll {
        # A fake delegate applies `input.mutation` to the trial workspace while it
        # "runs", so each case exercises the real before-and-after boundary. The
        # staged workspace mirrors the research probes: one indexed input, the
        # repository ignore file, and a file under an ignored logs directory.
        $script:FilesystemPrelude = @'
const fs = await import('node:fs');
const path = await import('node:path');
const fsp = await import('node:fs/promises');
const AsyncFunction = (async () => {}).constructor;
const makeDelegate = () => ({
  name: 'copilot-sdk',
  async execute(stimulus, options) {
    const mutate = new AsyncFunction('fs', 'path', 'root', input.mutations?.[stimulus.name] ?? input.mutation ?? '');
    await mutate(fs, path, options.workDir);
    return { events: [] };
  },
  async shutdown() {}
});
const stage = (name) => {
  const workDir = path.join(input.root, 'trials', name);
  const put = (relative, text) => { const full = path.join(workDir, relative); fs.mkdirSync(path.dirname(full), { recursive: true }); fs.writeFileSync(full, text); };
  put('subject/input.txt', 'original\n');
  put('.copilot-tracking/reviews/native-edit/metadata.json', '{"status":"pending"}\n');
  if (input.stageIgnore) { put('.gitignore', 'logs/\n'); put('logs/existing.txt', 'original\n'); }
  return workDir;
};
const policy = {
  schemaVersion: 1,
  rolloutState: 'calibration',
  stimuli: {
    'observed': { class: 'base-model', authoritative: false, measurement: 'candidate', coverageGap: 'x', filesystem: { allow: input.allow ?? [] } },
    'observed-two': { class: 'base-model', authoritative: false, measurement: 'candidate', coverageGap: 'x', filesystem: { allow: [] } },
    'legacy-observed': { class: 'base-model', authoritative: false, measurement: 'legacy', filesystem: { allow: [] } }
  }
};
fs.mkdirSync(input.root, { recursive: true });
fs.writeFileSync(path.join(input.root, 'policy.json'), JSON.stringify(policy));
const executor = executorModule.createAgentBehaviorExecutor({ delegate: makeDelegate(), repoRoot: input.root, policyPath: path.join(input.root, 'policy.json') });
const run = async (name) => {
  const workDir = stage(name);
  const trajectory = await executor.execute({ name, prompt: 'p' }, { workDir, timeout: 1000 });
  const verdicts = trajectory.events.filter(e => e.type === 'system' && e.data.eventType.startsWith('hve.filesystem.'));
  return { verdicts: verdicts.map(e => ({ eventType: e.data.eventType, ...e.data.details })), workDir };
};
'@

        function Invoke-FilesystemCase {
            param([string]$Mutation, [object[]]$Allow = @(), [switch]$StageIgnore, [string]$Stimulus = 'observed')

            $root = Join-Path $TestDrive ('fs-' + [Guid]::NewGuid().ToString('N'))
            $result = Invoke-RuntimeProbe -InputData @{ root = $root; mutation = $Mutation; allow = $Allow; stageIgnore = [bool]$StageIgnore; stimulus = $Stimulus } -Body ($script:FilesystemPrelude + 'return await run(input.stimulus);')
            return $result
        }

        $script:SsscReport = '^\.copilot-tracking/sssc-reviews/\d{4}-\d{2}-\d{2}/sssc-review-\d{3}\.md$'
    }

    # Cases mirror the research probe matrix that the Git-only observer missed or
    # caught; every one must now produce an explicit verdict from the filesystem.
    It 'Reports <Expected> for <Case>' -ForEach @(
        @{ Case = 'an unchanged workspace'; Mutation = ''; Expected = 'passed'; Code = $null }
        @{ Case = 'an ordinary new file'; Mutation = "fs.writeFileSync(path.join(root, 'notes.txt'), 'x');"; Expected = 'violated'; Code = 'unauthorized-create' }
        @{ Case = 'a visible ignore file plus ignored file'; Mutation = "fs.writeFileSync(path.join(root, '.gitignore'), 'notes.txt\n'); fs.writeFileSync(path.join(root, 'notes.txt'), 'x');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'self-ignoring root rules'; Mutation = "fs.writeFileSync(path.join(root, '.gitignore'), '.gitignore\nnotes.txt\n'); fs.writeFileSync(path.join(root, 'notes.txt'), 'x');"; Expected = 'violated'; Code = 'unauthorized-create' }
        @{ Case = 'self-ignoring nested rules'; Mutation = "fs.writeFileSync(path.join(root, 'subject/.gitignore'), '.gitignore\nnotes.txt\n'); fs.writeFileSync(path.join(root, 'subject/notes.txt'), 'x');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'a wildcard ignore rule'; Mutation = "fs.writeFileSync(path.join(root, '.gitignore'), '*\n'); fs.writeFileSync(path.join(root, 'notes.txt'), 'x');"; Expected = 'violated'; Code = 'unauthorized-create' }
        @{ Case = 'root Git metadata content'; Mutation = "fs.mkdirSync(path.join(root, '.git')); fs.writeFileSync(path.join(root, '.git/probe.txt'), 'x');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'nested Git metadata content'; Mutation = "fs.mkdirSync(path.join(root, 'subject/.git')); fs.writeFileSync(path.join(root, 'subject/.git/probe.txt'), 'x');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'uppercase Git metadata content'; Mutation = "fs.mkdirSync(path.join(root, '.GIT')); fs.writeFileSync(path.join(root, '.GIT/probe.txt'), 'x');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'an uppercase ignore file'; Mutation = "fs.writeFileSync(path.join(root, '.GITIGNORE'), '*\n'); fs.writeFileSync(path.join(root, 'notes.txt'), 'x');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'an edited staged input'; Mutation = "fs.writeFileSync(path.join(root, 'subject/input.txt'), 'changed\n');"; Expected = 'violated'; Code = 'unauthorized-modify' }
        @{ Case = 'a deleted staged input'; Mutation = "fs.rmSync(path.join(root, 'subject/input.txt'));"; Expected = 'violated'; Code = 'unauthorized-remove' }
        @{ Case = 'a plain Git metadata file'; Mutation = "fs.writeFileSync(path.join(root, '.git'), 'gitdir: elsewhere\n');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'a nested repository'; Mutation = "fs.mkdirSync(path.join(root, 'inner/.git'), { recursive: true }); fs.writeFileSync(path.join(root, 'inner/.git/HEAD'), 'ref: refs/heads/main\n'); fs.writeFileSync(path.join(root, 'inner/inner.txt'), 'x');"; Expected = 'violated'; Code = 'reserved-path' }
        @{ Case = 'an empty new directory'; Mutation = "fs.mkdirSync(path.join(root, 'scratch'));"; Expected = 'violated'; Code = 'unauthorized-directory' }
        @{ Case = 'a file replaced by a directory'; Mutation = "fs.rmSync(path.join(root, 'subject/input.txt')); fs.mkdirSync(path.join(root, 'subject/input.txt'));"; Expected = 'violated'; Code = 'type-change' }
        @{ Case = 'a staged file made read-only'; Mutation = "fs.chmodSync(path.join(root, 'subject/input.txt'), 0o444);"; Expected = 'violated'; Code = 'unauthorized-modify' }
    ) {
        $result = Invoke-FilesystemCase -Mutation $Mutation

        $result.verdicts | Should -HaveCount 1
        $result.verdicts[0].status | Should -Be $Expected
        $result.verdicts[0].eventType | Should -Be "hve.filesystem.$Expected"
        if ($Code) { $result.verdicts[0].codes | Should -Contain $Code }
    }

    It 'Detects <Case> beneath an unchanged staged repository ignore file' -ForEach @(
        @{ Case = 'a new ignored output'; Mutation = "fs.writeFileSync(path.join(root, 'logs/new.txt'), 'x');"; Code = 'unauthorized-create' }
        @{ Case = 'an edit to a file ignored at baseline'; Mutation = "fs.writeFileSync(path.join(root, 'logs/existing.txt'), 'changed\n');"; Code = 'unauthorized-modify' }
        @{ Case = 'an edit to the staged ignore file'; Mutation = "fs.writeFileSync(path.join(root, '.gitignore'), '*\n');"; Code = 'reserved-path' }
    ) {
        $result = Invoke-FilesystemCase -Mutation $Mutation -StageIgnore

        $result.verdicts[0].status | Should -Be 'violated'
        $result.verdicts[0].codes | Should -Contain $Code
    }

    It 'Accepts an unchanged staged ignore file and its ignored contents' {
        $result = Invoke-FilesystemCase -Mutation '' -StageIgnore

        $result.verdicts[0].status | Should -Be 'passed'
    }

    It 'Accepts the one authorized metadata update and rejects any other change' {
        $allow = @(@{ change = 'modify'; path = '.copilot-tracking/reviews/native-edit/metadata.json' })

        $authorized = Invoke-FilesystemCase -Allow $allow -Mutation "fs.writeFileSync(path.join(root, '.copilot-tracking/reviews/native-edit/metadata.json'), '{""status"":""ready""}\n');"
        $extra = Invoke-FilesystemCase -Allow $allow -Mutation "fs.writeFileSync(path.join(root, '.copilot-tracking/reviews/native-edit/metadata.json'), '{""status"":""ready""}\n'); fs.writeFileSync(path.join(root, '.copilot-tracking/reviews/native-edit/backup.json'), '{}');"
        $wrongKind = Invoke-FilesystemCase -Allow $allow -Mutation "fs.rmSync(path.join(root, '.copilot-tracking/reviews/native-edit/metadata.json'));"

        $authorized.verdicts[0].status | Should -Be 'passed'
        $extra.verdicts[0].status | Should -Be 'violated'
        $extra.verdicts[0].codes | Should -Be @('unauthorized-create')
        $wrongKind.verdicts[0].codes | Should -Be @('unauthorized-remove')
    }

    It 'Accepts one authorized report with new parents and rejects <Case>' -ForEach @(
        @{ Case = 'a second report'; Extra = "fs.writeFileSync(path.join(dir, 'sssc-review-002.md'), 'r');"; Code = 'create-limit' }
        @{ Case = 'a sibling scratch file'; Extra = "fs.writeFileSync(path.join(dir, 'scratch.md'), 's');"; Code = 'unauthorized-create' }
        @{ Case = 'a reserved file in the report directory'; Extra = "fs.writeFileSync(path.join(dir, '.gitignore'), '*');"; Code = 'reserved-path' }
    ) {
        $allow = @(@{ change = 'create'; pattern = $script:SsscReport; max = 1 })
        $create = "const dir = path.join(root, '.copilot-tracking/sssc-reviews/2026-10-13'); fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, 'sssc-review-001.md'), 'r');"

        $authorized = Invoke-FilesystemCase -Allow $allow -Mutation $create
        $rejected = Invoke-FilesystemCase -Allow $allow -Mutation ($create + $Extra)

        $authorized.verdicts[0].status | Should -Be 'passed'
        $rejected.verdicts[0].status | Should -Be 'violated'
        $rejected.verdicts[0].codes | Should -Contain $Code
    }

    It 'Rejects a created link even where a file would be allowed' {
        $allow = @(@{ change = 'create'; pattern = '^notes\.txt$' })

        $result = Invoke-FilesystemCase -Allow $allow -Mutation "fs.symlinkSync(path.join(root, 'subject'), path.join(root, 'notes.txt'), 'junction');"

        $result.verdicts[0].status | Should -Be 'violated'
        $result.verdicts[0].codes | Should -Contain 'unauthorized-create'
    }

    It 'Reports <Case> as unavailable rather than passed' -ForEach @(
        @{ Case = 'a removed workspace'; Mutation = "fs.rmSync(root, { recursive: true, force: true });"; Code = 'final-root-invalid' }
        @{ Case = 'a replaced workspace root'; Mutation = "fs.renameSync(root, root + '-moved'); fs.mkdirSync(path.join(root, 'subject'), { recursive: true }); fs.writeFileSync(path.join(root, 'subject/input.txt'), 'original\n'); fs.mkdirSync(path.join(root, '.copilot-tracking/reviews/native-edit'), { recursive: true }); fs.writeFileSync(path.join(root, '.copilot-tracking/reviews/native-edit/metadata.json'), '{""status"":""pending""}\n');"; Code = 'root-replaced' }
    ) {
        $result = Invoke-FilesystemCase -Mutation $Mutation

        $result.verdicts[0].status | Should -Be 'unavailable'
        $result.verdicts[0].eventType | Should -Be 'hve.filesystem.unavailable'
        $result.verdicts[0].codes | Should -Contain $Code
    }

    It 'Does not observe legacy entries' {
        $result = Invoke-FilesystemCase -Stimulus 'legacy-observed' -Mutation "fs.writeFileSync(path.join(root, 'notes.txt'), 'x');"

        $result.verdicts | Should -HaveCount 0
    }

    It 'Keeps concurrent trials independent' {
        $root = Join-Path $TestDrive ('fs-' + [Guid]::NewGuid().ToString('N'))
        $mutations = @{ 'observed' = "await new Promise(r => setTimeout(r, 50)); fs.writeFileSync(path.join(root, 'notes.txt'), 'x');"; 'observed-two' = '' }

        $result = Invoke-RuntimeProbe -InputData @{ root = $root; mutations = $mutations } -Body ($script:FilesystemPrelude + @'
const [one, two] = await Promise.all([run('observed'), run('observed-two')]);
return { one: one.verdicts[0].status, two: two.verdicts[0].status };
'@)

        $result.one | Should -Be 'violated'
        $result.two | Should -Be 'passed'
    }

    It 'Records paths and change kinds but never file contents' {
        $result = Invoke-FilesystemCase -Mutation "fs.writeFileSync(path.join(root, 'subject/input.txt'), 'SECRET-PAYLOAD');"

        $json = $result.verdicts | ConvertTo-Json -Depth 8
        $json | Should -Not -Match 'SECRET-PAYLOAD'
        $result.verdicts[0].changes[0].path | Should -Be 'subject/input.txt'
        $result.verdicts[0].changes[0].change | Should -Be 'modified'
    }
}

Describe 'captureSnapshot' -Tag 'Unit' {
    It 'Fails closed with <Code> when <Case>' -ForEach @(
        @{ Case = 'the entry limit is exceeded'; Limits = '{ maxEntries: 2, maxBytes: 1e9 }'; Code = 'resource-limit' }
        @{ Case = 'the byte limit is exceeded'; Limits = '{ maxEntries: 1000, maxBytes: 3 }'; Code = 'resource-limit' }
    ) {
        $root = Join-Path $TestDrive ('snap-' + [Guid]::NewGuid().ToString('N'))

        $result = Invoke-RuntimeProbe -InputData @{ root = $root } -Body @"
const fs = await import('node:fs');
fs.mkdirSync(input.root + '/a/b', { recursive: true });
fs.writeFileSync(input.root + '/a/b/c.txt', 'content');
try { await runtime.captureSnapshot(input.root, $Limits); return { code: null }; }
catch (e) { return { code: e.code }; }
"@

        $result.code | Should -Be $Code
    }

    It 'Records dotfiles, empty directories and reserved entries without following links' {
        $root = Join-Path $TestDrive ('snap-' + [Guid]::NewGuid().ToString('N'))

        $result = Invoke-RuntimeProbe -InputData @{ root = $root } -Body @'
const fs = await import('node:fs');
const path = await import('node:path');
fs.mkdirSync(path.join(input.root, 'empty'), { recursive: true });
fs.mkdirSync(path.join(input.root, '.git'));
fs.writeFileSync(path.join(input.root, '.git/HEAD'), 'x');
fs.writeFileSync(path.join(input.root, '.hidden'), 'x');
fs.mkdirSync(path.join(input.root, 'target'));
fs.writeFileSync(path.join(input.root, 'target/inside.txt'), 'x');
fs.symlinkSync(path.join(input.root, 'target'), path.join(input.root, 'link'), 'junction');
const snapshot = await runtime.captureSnapshot(input.root);
return { keys: [...snapshot.entries.keys()], link: snapshot.entries.get('link').type };
'@

        $result.keys | Should -Contain 'empty'
        $result.keys | Should -Contain '.git/HEAD'
        $result.keys | Should -Contain '.hidden'
        $result.keys | Should -Not -Contain 'link/inside.txt'
        $result.link | Should -Be 'symlink'
    }
}
