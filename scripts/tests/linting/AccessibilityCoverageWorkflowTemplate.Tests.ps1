#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:templatePath = Join-Path $script:repoRoot '.github/skills/accessibility/accessibility/references/ci/accessibility-coverage.workflow-template.yml'
    $script:template = Get-Content -LiteralPath $script:templatePath -Raw
    $script:workflow = ConvertFrom-Yaml -Yaml $script:template
    $script:steps = @($script:workflow.jobs['runtime-accessibility'].steps)
    $script:stepNames = @($script:steps | ForEach-Object { $_['name'] })
}

Describe 'Accessibility coverage workflow template' -Tag 'Unit' {
    It 'Keeps intent verification inactive only when no authored records exist' {
        $script:template | Should -Match 'intent_records=\(.*TARGET_INTENT_DIR.*\.intent\.yaml.*\)'
        $script:template | Should -Match 'if \[ "\$\{#intent_records\[@\]\}" -eq 0 \]'
    }

    It 'Fails when authored records exist without a runtime config' {
        $script:template | Should -Match 'Design intent records exist, but .*TARGET_CONFIG.* is missing'
    }

    It 'Uses vendored direct-script invocations after removing stale results' {
        $removeIndex = $script:template.IndexOf('rm -f -- "${{ env.TARGET_RESULTS }}"')
        $runInvocation = 'uv run --project "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}" "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}/scripts/runtime_a11y/__main__.py" run-all'
        $verifyInvocation = 'uv run --project "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}" "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}/scripts/runtime_a11y/__main__.py" verify-intent'
        $runIndex = $script:template.IndexOf($runInvocation)

        $removeIndex | Should -BeGreaterThan -1
        $removeIndex | Should -BeLessThan $runIndex
        $runIndex | Should -BeGreaterThan -1
        $script:template.IndexOf($verifyInvocation) | Should -BeGreaterThan $runIndex
    }

    It 'Prefers explicit probe identity and falls back to evidence text' {
        $script:template | Should -Match '(?s)def probe_for\(item\):\s+probe_id = item\.get\("probeId"\)\s+if probe_id in all_gated:\s+return probe_id\s+evidence = str\(item\.get\("evidence", ""\)\)'
        $script:template | Should -Match 'probe_id = probe_for\(item\)'
    }

    It 'Fails when authored records exist without current runtime results' {
        $script:template | Should -Match 'Design intent records exist, but no current runtime results file was produced'
    }

    It 'Keeps evidence composition inactive until every downstream contract exists' {
        foreach ($variable in @(
                'TARGET_EVIDENCE_ASSETS',
                'TARGET_EVIDENCE_REQUIREMENTS',
                'TARGET_EVIDENCE_SCOPE',
                'TARGET_RUN_CONTEXT',
                'TARGET_EVIDENCE_SOURCE',
                'TARGET_STATE_PROOFS'
            )) {
            $expression = '${{ env.' + $variable + ' }}'
            $script:template | Should -Match ([regex]::Escape($expression))
        }
        $script:template | Should -Match 'Evidence composition is inactive because \$path is missing'
    }

    It 'Composes only automated completeness without owning reviewer or release policy' {
        $script:template | Should -Match 'compose-evidence'
        $script:template | Should -Match '--require-completeness automated'
        $script:template | Should -Not -Match '--require-completeness reviewer'
        $script:template | Should -Not -Match '--require-completeness release'
    }

    It 'Composes the bundle before staging it for retention' {
        # Parsed step identity, not text order: a step merged into a prior run
        # block still satisfies substring ordering while never executing.
        $composeIndex = $script:stepNames.IndexOf('Compose accessibility evidence bundle')
        $manifestIndex = $script:stepNames.IndexOf('Emit accessibility validation manifest')
        $stageIndex = $script:stepNames.IndexOf('Stage accessibility evidence for retention')
        $uploadIndex = $script:stepNames.IndexOf('Upload accessibility evidence')

        $composeIndex | Should -BeGreaterThan -1
        $manifestIndex | Should -BeGreaterThan $composeIndex
        $stageIndex | Should -BeGreaterThan $manifestIndex
        $uploadIndex | Should -BeGreaterThan $stageIndex
    }

    It 'Declares the manifest step with its own execution fields' {
        $manifestStep = $script:steps | Where-Object { $_['name'] -eq 'Emit accessibility validation manifest' }
        $manifestStep | Should -Not -BeNullOrEmpty
        $manifestStep['if'] | Should -Be 'always()'
        $manifestStep['run'] | Should -Match 'emit-validation-manifest'
        $manifestStep['env'].Keys | Should -Contain 'VALIDATION_JOB_STATUS'
    }

    It 'Keeps every embedded Python program syntactically valid' {
        $blocks = [regex]::Matches(
            ($script:steps | Where-Object { $_.ContainsKey('run') } | ForEach-Object { $_['run'] }) -join "`n",
            "(?s)<<'PY'\r?\n(.*?)\r?\n\s*PY")
        @($blocks).Count | Should -BeGreaterThan 0

        # py_compile is stdlib, so any interpreter works and no project environment is needed.
        $python = @('python3', 'python') |
            ForEach-Object { Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue } |
            Select-Object -First 1
        $python | Should -Not -BeNullOrEmpty -Because 'compiling the embedded programs requires a Python interpreter'

        foreach ($block in $blocks) {
            $source = Join-Path ([System.IO.Path]::GetTempPath()) ((New-Guid).Guid + '.py')
            try {
                Set-Content -LiteralPath $source -Value $block.Groups[1].Value -Encoding utf8
                $output = & $python.Source -c "import py_compile,sys; py_compile.compile(sys.argv[1], doraise=True)" $source 2>&1
                $LASTEXITCODE | Should -Be 0 -Because "embedded Python must compile: $output"
            }
            finally {
                Remove-Item -LiteralPath $source -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'Validates staging containment before any recursive delete' {
        $stageStep = $script:steps | Where-Object { $_['name'] -eq 'Stage accessibility evidence for retention' }
        $run = $stageStep['run']
        $guardIndex = $run.IndexOf('Refusing unsafe evidence staging path')
        $deleteIndex = $run.IndexOf('rm -rf')

        $guardIndex | Should -BeGreaterThan -1
        $deleteIndex | Should -BeGreaterThan $guardIndex
        $run | Should -Match 'must resolve inside the working directory'
        $run | Should -Match 'Refusing a symlinked evidence staging directory'
        $run | Should -Match 'rm -rf "\$resolved"'
    }

    It 'Emits a manifest from a frozen revision boundary and command artifact' {
        $script:template | Should -Match 'git", "diff", "--binary", "HEAD"'
        $script:template | Should -Match 'TARGET_COMMAND_RESULT'
        $script:template | Should -Match 'resultArtifactDigest.*digest_file\(command_result_path\)'
        $script:template | Should -Match '"generatedInventory": generated'
        $script:template | Should -Match '"untrackedDeliverables": untracked'
        $script:template | Should -Match '--schema-report "\$\{\{ env\.TARGET_SCHEMA_REPORT \}\}"'
    }

    It 'Retains evidence on every exit path including an incomplete composition' {
        # Composition exits non-zero when automated collection is incomplete, so
        # staging and upload must not be conditional on that step succeeding.
        $stageIndex = $script:template.IndexOf('Stage accessibility evidence for retention')
        $uploadIndex = $script:template.IndexOf('Upload accessibility evidence')
        $script:template.Substring($stageIndex, 200) | Should -Match 'if: always\(\)'
        $script:template.Substring($uploadIndex, 200) | Should -Match 'if: always\(\)'
        $script:template | Should -Match '"classification": classification'
        $script:template | Should -Match 'if completeness\["automatedCollection"\] == "complete"'
    }

    It 'Uploads only the staging directory under a pinned action with explicit policy' {
        $script:template | Should -Match 'uses: actions/upload-artifact@[0-9a-f]{40} # v\d+\.\d+\.\d+'
        $script:template | Should -Match 'name: accessibility-evidence-\$\{\{ github\.run_id \}\}-\$\{\{ github\.run_attempt \}\}'
        $script:template | Should -Match 'retention-days: \d+'
        $script:template | Should -Match 'if-no-files-found: \w+'
        $expression = 'path: ${{ env.TARGET_WORKDIR }}/${{ env.TARGET_EVIDENCE_STAGING }}'
        $script:template | Should -Match ([regex]::Escape($expression))
    }

    It 'Stages a closed allowlist into a newly created empty directory' {
        $script:template | Should -Match 'rm -rf "\$resolved"'
        $script:template | Should -Match 'mkdir -p "\$resolved"'
        foreach ($name in @(
                'evidence-bundle.json',
                'composition-summary.json',
                'accessibility-validation-manifest.json',
                'schema-validation-report.json'
            )) {
            $script:template | Should -Match ([regex]::Escape($name))
        }
        $script:template | Should -Match 'Unlisted files reached the staging directory'
    }

    It 'Rejects missing, symlinked, hidden and unvalidated content before staging' {
        $script:template | Should -Match 'Required retained document is missing'
        $script:template | Should -Match 'path\.is_symlink\(\) or path\.name\.startswith\("\."\)'
        $script:template | Should -Match 'Refusing to stage a symlink or hidden file'
        foreach ($schema in @(
                'evidence-bundle.schema.json',
                'composition-summary.schema.json',
                'validation-manifest.schema.json',
                'schema-validation-report.schema.json'
            )) {
            $script:template | Should -Match ([regex]::Escape($schema))
        }
        $script:template | Should -Match 'validate_retained_document\(name, document\)'
        $script:template | Should -Match 'validate_retained_document\("composition-summary\.json", summary\)'
        $script:template | Should -Match 'reject_prohibited_content\(document\)'
        $script:template | Should -Match 'reject_prohibited_content\(summary\)'
    }
}