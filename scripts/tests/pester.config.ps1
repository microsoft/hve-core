#!/usr/bin/env pwsh
#
# pester.config.ps1
#
# Purpose: Pester 5.x configuration for HVE-Core PowerShell testing
# Author: HVE Core Team
#

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$CI,

    [Parameter()]
    [switch]$CodeCoverage,

    [Parameter()]
    [string]$TestPath = "$PSScriptRoot"
)

$configuration = New-PesterConfiguration

# Run configuration
$configuration.Run.Path = @($TestPath)
$configuration.Run.Exit = $CI.IsPresent
$configuration.Run.PassThru = $true
$configuration.Run.TestExtension = '.Tests.ps1'

# Filter configuration
$configuration.Filter.ExcludeTag = @('Integration', 'Slow')

# Output configuration
$configuration.Output.Verbosity = if ($CI.IsPresent) { 'Normal' } else { 'Detailed' }
$configuration.Output.CIFormat = if ($CI.IsPresent) { 'GithubActions' } else { 'Auto' }
$configuration.Output.CILogLevel = 'Error'

# Test result configuration (NUnit XML for CI artifact upload)
$configuration.TestResult.Enabled = $CI.IsPresent
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.TestResult.OutputPath = Join-Path $PSScriptRoot '../../logs/pester-results.xml'
$configuration.TestResult.TestSuiteName = 'HVE-Core-PowerShell-Tests'

# Code coverage configuration
if ($CodeCoverage.IsPresent) {
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.OutputPath = Join-Path $PSScriptRoot '../../logs/coverage.xml'
    $configuration.CodeCoverage.Path = @(
        (Join-Path $PSScriptRoot '../linting/**/*.ps1'),
        (Join-Path $PSScriptRoot '../linting/**/*.psm1'),
        (Join-Path $PSScriptRoot '../security/**/*.ps1'),
        (Join-Path $PSScriptRoot '../dev-tools/**/*.ps1'),
        (Join-Path $PSScriptRoot '../lib/**/*.ps1'),
        (Join-Path $PSScriptRoot '../extension/**/*.ps1')
    )
    $configuration.CodeCoverage.ExcludeTests = $true
    $configuration.CodeCoverage.CoveragePercentTarget = 70
}

# Should configuration
$configuration.Should.ErrorAction = 'Stop'

return $configuration
