
$ErrorActionPreference = "Stop"
Import-Module ./scripts/lib/Modules/FrameworkSkillDiscovery.psm1 -Force
$base = Get-FrameworkSkill -RepoRoot $PWD -Domain "security"
Write-Host "Baseline count: $($base.Count)"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("fsb-test-" + [guid]::NewGuid())
$bundleDir = Join-Path $tmp "my-custom-framework"
$null = New-Item -ItemType Directory -Force -Path $bundleDir
$yml = "framework: my-custom-framework`nversion: \"0.1\"`ndomain: security`nitemKind: control`nstatus: draft`nphaseMap:`n  standards-mapping:`n    - foo"
$yml | Set-Content -LiteralPath (Join-Path $bundleDir "index.yml")
$withExtra = Get-FrameworkSkill -RepoRoot $PWD -Domain "security" -AdditionalRoots $tmp
Write-Host "With extra root (no drafts): $($withExtra.Count)"
$withDrafts = Get-FrameworkSkill -RepoRoot $PWD -Domain "security" -AdditionalRoots $tmp -IncludeDrafts
Write-Host "With extra root + drafts: $($withDrafts.Count)"
$custom = $withDrafts | Where-Object Framework -eq "my-custom-framework"
if ($null -ne $custom) {
    Write-Host "Custom found: True; status=$($custom.Status); domain=$($custom.Domain)"
} else {
    Write-Host "Custom found: False"
}
$wrongDomain = Get-FrameworkSkill -RepoRoot $PWD -Domain "security" -AdditionalRoots $tmp -IncludeDrafts | Where-Object Domain -ne "security"
Write-Host "Bundles with non-security domain leaked: $($wrongDomain.Count)"
Remove-Item -Recurse -Force -LiteralPath $tmp
Write-Host "OK"

