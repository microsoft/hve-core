# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

Set-StrictMode -Version Latest

$script:CanonicalCategories = [ordered]@{
    'revenue enablement'  = 'revenue enablement'
    'revenue_enablement'  = 'revenue enablement'
    'revenue-enablement'  = 'revenue enablement'
    'cost avoidance'      = 'cost avoidance'
    'cost_avoidance'      = 'cost avoidance'
    'cost-avoidance'      = 'cost avoidance'
    'capacity gained'     = 'capacity gained'
    'capacity_gained'     = 'capacity gained'
    'capacity-gained'     = 'capacity gained'
    'labour augmentation' = 'labour augmentation'
    'labor augmentation'  = 'labour augmentation'
    'labour_augmentation' = 'labour augmentation'
    'labor_augmentation'  = 'labour augmentation'
    'labour-augmentation' = 'labour augmentation'
    'labor-augmentation'  = 'labour augmentation'
    'quality'             = 'quality'
    'speed'               = 'speed'
    'risk reduction'      = 'risk reduction'
    'risk_reduction'      = 'risk reduction'
    'risk-reduction'      = 'risk reduction'
    'new capacity'        = 'new capacity'
    'new_capacity'        = 'new capacity'
    'new-capacity'        = 'new capacity'
    'engagement'          = 'engagement'
}

$script:DefaultDecreaseCategories = @(
    'cost avoidance'
    'quality'
    'speed'
    'risk reduction'
)

<#
.SYNOPSIS
    Constructs a documented stop exception for Measure-HveBenefitValue.
.PARAMETER Message
    Human-readable validation or guardrail failure message.
#>
function Get-HveBenefitValuationStop {
    [CmdletBinding()]
    [OutputType([System.InvalidOperationException])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $err = [System.InvalidOperationException]::new("Measure-HveBenefitValue: $Message")
    $err.Data['HveBenefitValuationStop'] = $true
    return $err
}

<#
.SYNOPSIS
    Confirms a path and its existing ancestors contain no symbolic links or reparse points.
.PARAMETER CandidatePath
    Filesystem path to validate.
#>
function Assert-HveSafePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath
    )
    $full = [System.IO.Path]::GetFullPath($CandidatePath)
    $cursor = $full
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or $item.LinkTarget)) {
            throw (Get-HveBenefitValuationStop -Message "Linked path refused: '$CandidatePath'.")
        }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) {
            break
        }
        $cursor = $parent
    }
    return $full
}

<#
.SYNOPSIS
    Resolves a raw FinOps value category label to its canonical name.
.PARAMETER Category
    Raw category label from input JSON.
#>
function Resolve-HveCanonicalCategory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Category
    )
    if ([string]::IsNullOrWhiteSpace($Category)) {
        return $null
    }
    $key = ($Category.Trim().ToLowerInvariant() -replace '\s+', ' ')
    if ($script:CanonicalCategories.Contains($key)) {
        return [string]$script:CanonicalCategories[$key]
    }
    throw (Get-HveBenefitValuationStop -Message "Unsupported benefit category '$Category'.")
}

<#
.SYNOPSIS
    Parses a numeric value into a CultureInfo.InvariantCulture decimal or returns null.
.PARAMETER Value
    Candidate scalar value.
.PARAMETER FieldName
    Field path for error reporting.
#>
function ConvertTo-HveDecimal {
    [CmdletBinding()]
    [OutputType([System.Nullable[decimal]])]
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )
    if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
        return $null
    }
    if ($Value -is [bool]) {
        throw (Get-HveBenefitValuationStop -Message "Field '$FieldName' must be numeric, not boolean.")
    }
    $parsed = [decimal]0
    $text = [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture).Trim()
    if (-not [decimal]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        throw (Get-HveBenefitValuationStop -Message "Field '$FieldName' ('$Value') is not a finite decimal number.")
    }
    return $parsed
}

<#
.SYNOPSIS
    Reads a property case-insensitively from a hashtable or PSCustomObject.
.PARAMETER InputObject
    Object or dictionary to inspect.
.PARAMETER Name
    Property name to look up.
#>
function Get-HveProp {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    if ($null -eq $InputObject) {
        return $null
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            if ([string]::Equals([string]$key, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $InputObject[$key]
            }
        }
        return $null
    }
    foreach ($prop in $InputObject.PSObject.Properties) {
        if ([string]::Equals($prop.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $prop.Value
        }
    }
    return $null
}

<#
.SYNOPSIS
    Converts an amount from SourceCurrency into TargetCurrency using explicit FxRates only.
.PARAMETER Amount
    Source decimal amount.
.PARAMETER SourceCurrency
    Three-letter ISO currency code of Amount.
.PARAMETER TargetCurrency
    Three-letter ISO currency code of the valuation report.
.PARAMETER FxRates
    Optional FX conversion map supplied by the caller.
#>
function ConvertTo-HveCurrencyAmount {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [decimal]$Amount,

        [Parameter(Mandatory = $true)]
        [string]$SourceCurrency,

        [Parameter(Mandatory = $true)]
        [string]$TargetCurrency,

        [AllowNull()]
        [object]$FxRates
    )
    $src = $SourceCurrency.Trim().ToUpperInvariant()
    $dst = $TargetCurrency.Trim().ToUpperInvariant()
    if ($src -ceq $dst) {
        return [pscustomobject]@{
            Converted = $true
            Amount    = $Amount
            Rate      = [decimal]1
            Note      = $null
        }
    }
    $rateObj = Get-HveProp -InputObject $FxRates -Name $src
    if ($null -eq $rateObj) {
        $rateObj = Get-HveProp -InputObject $FxRates -Name "$src->$dst"
    }
    if ($null -eq $rateObj) {
        return [pscustomobject]@{
            Converted = $false
            Amount    = $null
            Rate      = $null
            Note      = "Currency '$src' differs from report currency '$dst' and no fx_rates['$src'] conversion factor was supplied."
        }
    }
    $rate = ConvertTo-HveDecimal -Value $rateObj -FieldName "fx_rates.$src"
    if ($null -eq $rate -or $rate -le 0) {
        throw (Get-HveBenefitValuationStop -Message "FX rate for '$src' must be a positive number.")
    }
    return [pscustomobject]@{
        Converted = $true
        Amount    = ($Amount * $rate)
        Rate      = $rate
        Note      = "Converted from $src to $dst at supplied FX rate $rate."
    }
}

<#
.SYNOPSIS
    Evaluates a single FinOps benefit claim into native delta, monetary basis, and gross value.
.PARAMETER Claim
    Claim object from benefit_claims[].
.PARAMETER ReportCurrency
    Target ISO currency code.
.PARAMETER FxRates
    Optional FX conversion table.
#>
function Measure-HveSingleClaim {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Claim,

        [Parameter(Mandatory = $true)]
        [string]$ReportCurrency,

        [AllowNull()]
        [object]$FxRates
    )
    $claimId = [string](Get-HveProp -InputObject $Claim -Name 'claim_id')
    if ([string]::IsNullOrWhiteSpace($claimId)) {
        $claimId = [string](Get-HveProp -InputObject $Claim -Name 'claimId')
    }
    if ([string]::IsNullOrWhiteSpace($claimId)) {
        throw (Get-HveBenefitValuationStop -Message 'Every claim must declare a non-empty claim_id.')
    }

    $category = Resolve-HveCanonicalCategory -Category ([string](Get-HveProp -InputObject $Claim -Name 'category'))
    $hypothesis = [string](Get-HveProp -InputObject $Claim -Name 'hypothesis')
    $beneficiary = [string](Get-HveProp -InputObject $Claim -Name 'beneficiary')
    $measurementOwner = [string](Get-HveProp -InputObject $Claim -Name 'measurement_owner')
    if ([string]::IsNullOrWhiteSpace($measurementOwner)) {
        $measurementOwner = [string](Get-HveProp -InputObject $Claim -Name 'measurementOwner')
    }

    $businessDecision = Get-HveProp -InputObject $Claim -Name 'business_decision'
    if ($null -eq $businessDecision) {
        $businessDecision = Get-HveProp -InputObject $Claim -Name 'businessDecision'
    }
    $decisionOwner = [string](Get-HveProp -InputObject $businessDecision -Name 'owner')
    $decisionStatus = [string](Get-HveProp -InputObject $businessDecision -Name 'status')
    if ([string]::IsNullOrWhiteSpace($decisionStatus)) {
        $decisionStatus = 'unapproved'
    }
    $decisionRef = [string](Get-HveProp -InputObject $businessDecision -Name 'reference')

    $rawStatus = [string](Get-HveProp -InputObject $Claim -Name 'status')
    $evidenceStatus = if ([string]::IsNullOrWhiteSpace($rawStatus)) { 'pending' } else { $rawStatus.Trim().ToLowerInvariant() }
    if ($evidenceStatus -notin @('supported', 'gap', 'pending')) {
        throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' has invalid status '$evidenceStatus'.")
    }

    $baseline = Get-HveProp -InputObject $Claim -Name 'baseline'
    $target = Get-HveProp -InputObject $Claim -Name 'target'
    $observation = Get-HveProp -InputObject $Claim -Name 'observation'
    $valuation = Get-HveProp -InputObject $Claim -Name 'valuation'

    $linksRaw = Get-HveProp -InputObject $Claim -Name 'evidence_links'
    if ($null -eq $linksRaw) {
        $linksRaw = Get-HveProp -InputObject $Claim -Name 'evidenceLinks'
    }
    $evidenceLinks = @(
        if ($null -ne $linksRaw) {
            foreach ($lnk in @($linksRaw)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$lnk)) {
                    ([string]$lnk).Trim()
                }
            }
        }
    )

    $gaps = [System.Collections.Generic.List[string]]::new()
    $missingInputs = [System.Collections.Generic.List[string]]::new()
    $notes = [System.Collections.Generic.List[string]]::new()

    if (-not $category) { $gaps.Add('Missing primary FinOps value category.') }
    if ([string]::IsNullOrWhiteSpace($hypothesis)) { $gaps.Add('Missing explicit benefit hypothesis.') }
    if ([string]::IsNullOrWhiteSpace($beneficiary)) { $gaps.Add('Missing beneficiary/scope.') }
    if ([string]::IsNullOrWhiteSpace($measurementOwner)) { $gaps.Add('Missing measurement owner.') }
    if ($evidenceStatus -eq 'supported' -and $evidenceLinks.Count -eq 0) {
        $gaps.Add('Claim is marked supported but carries no evidence_links.')
    }

    $baseVal = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $baseline -Name 'value') -FieldName "$claimId.baseline.value"
    $baseUnit = [string](Get-HveProp -InputObject $baseline -Name 'unit')
    $targVal = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $target -Name 'value') -FieldName "$claimId.target.value"
    $obsVal = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $observation -Name 'value') -FieldName "$claimId.observation.value"
    $obsUnit = [string](Get-HveProp -InputObject $observation -Name 'unit')

    $unitMismatch = $false
    if (-not [string]::IsNullOrWhiteSpace($baseUnit) -and -not [string]::IsNullOrWhiteSpace($obsUnit) -and
        -not [string]::Equals($baseUnit.Trim(), $obsUnit.Trim(), [System.StringComparison]::OrdinalIgnoreCase)) {
        $unitMismatch = $true
        $gaps.Add("Unit mismatch between baseline ('$baseUnit') and observation ('$obsUnit').")
    }

    $directionRaw = [string](Get-HveProp -InputObject $valuation -Name 'direction')
    $isDecrease = if (-not [string]::IsNullOrWhiteSpace($directionRaw)) {
        $directionRaw.Trim().ToLowerInvariant() -eq 'decrease'
    }
    elseif ($null -ne $baseVal -and $null -ne $targVal -and $targVal -ne $baseVal) {
        $targVal -lt $baseVal
    }
    else {
        $category -in $script:DefaultDecreaseCategories
    }

    $nativeDelta = $null
    $targetNativeDelta = $null
    if (-not $unitMismatch -and $null -ne $baseVal -and $null -ne $obsVal) {
        $nativeDelta = if ($isDecrease) { $baseVal - $obsVal } else { $obsVal - $baseVal }
    }
    if ($null -ne $baseVal -and $null -ne $targVal) {
        $targetNativeDelta = if ($isDecrease) { $baseVal - $targVal } else { $targVal - $baseVal }
    }

    $overlapGroup = [string](Get-HveProp -InputObject $Claim -Name 'overlap_group')
    if ([string]::IsNullOrWhiteSpace($overlapGroup)) {
        $overlapGroup = [string](Get-HveProp -InputObject $Claim -Name 'overlapGroup')
    }
    $primaryInGroup = (Get-HveProp -InputObject $valuation -Name 'primaryInGroup') -eq $true
    $overlapShare = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'overlapShare') -FieldName "$claimId.valuation.overlapShare"
    if ($null -eq $overlapShare) {
        $overlapShare = [decimal]1
    }
    if ($overlapShare -lt 0 -or $overlapShare -gt 1) {
        throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' overlapShare must be between 0 and 1.")
    }

    $valCurrency = [string](Get-HveProp -InputObject $valuation -Name 'currency')
    if ([string]::IsNullOrWhiteSpace($valCurrency)) {
        $valCurrency = $ReportCurrency
    }
    $attributionShare = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'attributionShare') -FieldName "$claimId.valuation.attributionShare"
    $periodFactor = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'periodFactor') -FieldName "$claimId.valuation.periodFactor"
    if ($null -eq $periodFactor) {
        $periodFactor = [decimal]1
    }
    if ($periodFactor -le 0) {
        throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' periodFactor must be positive.")
    }

    $uncertaintyPct = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'uncertaintyPct') -FieldName "$claimId.valuation.uncertaintyPct"
    $financeApprovedFlag = (Get-HveProp -InputObject $valuation -Name 'financeApproved') -eq $true

    $useForecast = ($evidenceStatus -eq 'pending' -and $null -eq $nativeDelta -and $null -ne $targetNativeDelta)
    $workingDelta = if ($useForecast) { $targetNativeDelta } else { $nativeDelta }
    $grossRaw = $null
    $formulaText = $null
    $monetizable = $true

    if ($evidenceStatus -eq 'gap' -or $unitMismatch -or -not $category) {
        $monetizable = $false
    }
    elseif ($evidenceStatus -eq 'supported' -and $evidenceLinks.Count -eq 0) {
        $monetizable = $false
        $missingInputs.Add('evidence_links')
    }
    elseif ($null -eq $valuation) {
        $monetizable = $false
        $missingInputs.Add('valuation')
    }

    if ($monetizable) {
        if ($null -eq $attributionShare) {
            $monetizable = $false
            $missingInputs.Add('valuation.attributionShare')
        }
        elseif ($attributionShare -le 0 -or $attributionShare -gt 1) {
            throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' attributionShare must be in (0, 1].")
        }
    }

    if ($monetizable) {
        $volume = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'volume') -FieldName "$claimId.valuation.volume"
        if ($null -eq $volume) {
            $volume = [decimal]1
        }
        if ($volume -lt 0) {
            throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' volume cannot be negative.")
        }

        switch ($category) {
            'revenue enablement' {
                $pipelineOnly = (Get-HveProp -InputObject $valuation -Name 'pipelineOnly') -eq $true
                $convRate = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'conversionToRecognizedRate') -FieldName "$claimId.valuation.conversionToRecognizedRate"
                $unitValue = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'unitValue') -FieldName "$claimId.valuation.unitValue"
                if ($null -eq $unitValue) {
                    $unitValue = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'unitMargin') -FieldName "$claimId.valuation.unitMargin"
                }
                if ($pipelineOnly -and $null -eq $convRate) {
                    $monetizable = $false
                    $missingInputs.Add('valuation.conversionToRecognizedRate')
                    $notes.Add('Influenced pipeline requires conversionToRecognizedRate to state incremental revenue/margin.')
                }
                elseif ($null -eq $workingDelta -or $workingDelta -le 0 -or $null -eq $unitValue -or $unitValue -le 0) {
                    $monetizable = $false
                    if ($null -eq $unitValue -or $unitValue -le 0) { $missingInputs.Add('valuation.unitValue') }
                }
                else {
                    $effConv = if ($null -ne $convRate) { $convRate } else { [decimal]1 }
                    if ($effConv -le 0 -or $effConv -gt 1) {
                        throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' conversionToRecognizedRate must be in (0, 1].")
                    }
                    $grossRaw = $workingDelta * $volume * $effConv * $unitValue * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * conv($effConv) * unitValue($unitValue) * attr($attributionShare) * period($periodFactor)"
                }
            }
            'cost avoidance' {
                $cfCost = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'counterfactualCost') -FieldName "$claimId.valuation.counterfactualCost"
                $obsCost = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'observedCost') -FieldName "$claimId.valuation.observedCost"
                $unitCost = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'unitCost') -FieldName "$claimId.valuation.unitCost"
                if ($null -ne $cfCost -and $null -ne $obsCost) {
                    $diff = $cfCost - $obsCost
                    if ($diff -le 0) {
                        $monetizable = $false
                    }
                    else {
                        $grossRaw = $diff * $attributionShare * $periodFactor
                        $formulaText = "(counterfactualCost($cfCost) - observedCost($obsCost)) * attr($attributionShare) * period($periodFactor)"
                    }
                }
                elseif ($null -ne $workingDelta -and $workingDelta -gt 0 -and $null -ne $unitCost -and $unitCost -gt 0) {
                    $grossRaw = $workingDelta * $volume * $unitCost * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * unitCost($unitCost) * attr($attributionShare) * period($periodFactor)"
                }
                else {
                    $monetizable = $false
                    $missingInputs.Add('valuation.unitCost or counterfactualCost/observedCost')
                }
            }
            'capacity gained' {
                $hourlyRate = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'hourlyRate') -FieldName "$claimId.valuation.hourlyRate"
                $redeployedShare = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'redeployedShare') -FieldName "$claimId.valuation.redeployedShare"
                $avoidedExpense = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'avoidedExpenseAmount') -FieldName "$claimId.valuation.avoidedExpenseAmount"
                if ($null -ne $avoidedExpense -and $avoidedExpense -gt 0) {
                    $grossRaw = $avoidedExpense * $attributionShare * $periodFactor
                    $formulaText = "avoidedExpenseAmount($avoidedExpense) * attr($attributionShare) * period($periodFactor)"
                }
                elseif ($null -eq $workingDelta -or $workingDelta -le 0 -or $null -eq $hourlyRate -or $hourlyRate -le 0 -or $null -eq $redeployedShare -or $redeployedShare -le 0) {
                    $monetizable = $false
                    if ($null -eq $hourlyRate -or $hourlyRate -le 0) { $missingInputs.Add('valuation.hourlyRate') }
                    if ($null -eq $redeployedShare -or $redeployedShare -le 0) { $missingInputs.Add('valuation.redeployedShare') }
                }
                else {
                    if ($redeployedShare -gt 1) {
                        throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' redeployedShare must be in (0, 1].")
                    }
                    $grossRaw = $workingDelta * $volume * $redeployedShare * $hourlyRate * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * redeployed($redeployedShare) * hourlyRate($hourlyRate) * attr($attributionShare) * period($periodFactor)"
                }
            }
            'labour augmentation' {
                $qualityFloorMet = Get-HveProp -InputObject $valuation -Name 'qualityFloorMet'
                $hourlyRate = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'hourlyRate') -FieldName "$claimId.valuation.hourlyRate"
                $redeployedShare = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'redeployedShare') -FieldName "$claimId.valuation.redeployedShare"
                if ($qualityFloorMet -eq $false) {
                    $monetizable = $false
                    $gaps.Add('Quality floor was violated (qualityFloorMet=false); labour augmentation cannot be monetized when quality degrades.')
                }
                elseif ($null -eq $workingDelta -or $workingDelta -le 0 -or $null -eq $hourlyRate -or $hourlyRate -le 0 -or $null -eq $redeployedShare -or $redeployedShare -le 0) {
                    $monetizable = $false
                    if ($null -eq $hourlyRate -or $hourlyRate -le 0) { $missingInputs.Add('valuation.hourlyRate') }
                    if ($null -eq $redeployedShare -or $redeployedShare -le 0) { $missingInputs.Add('valuation.redeployedShare') }
                }
                else {
                    if ($redeployedShare -gt 1) {
                        throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' redeployedShare must be in (0, 1].")
                    }
                    $grossRaw = $workingDelta * $volume * $redeployedShare * $hourlyRate * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * redeployed($redeployedShare) * hourlyRate($hourlyRate) * attr($attributionShare) * period($periodFactor)"
                }
            }
            'quality' {
                $costPerDefect = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'costPerDefect') -FieldName "$claimId.valuation.costPerDefect"
                if ($null -eq $workingDelta -or $workingDelta -le 0 -or $null -eq $costPerDefect -or $costPerDefect -le 0) {
                    $monetizable = $false
                    $missingInputs.Add('valuation.costPerDefect')
                }
                else {
                    $grossRaw = $workingDelta * $volume * $costPerDefect * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * costPerDefect($costPerDefect) * attr($attributionShare) * period($periodFactor)"
                }
            }
            'speed' {
                $valuePerTimeUnit = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'valuePerTimeUnit') -FieldName "$claimId.valuation.valuePerTimeUnit"
                if ($null -eq $workingDelta -or $workingDelta -le 0 -or $null -eq $valuePerTimeUnit -or $valuePerTimeUnit -le 0) {
                    $monetizable = $false
                    $missingInputs.Add('valuation.valuePerTimeUnit')
                }
                else {
                    $grossRaw = $workingDelta * $volume * $valuePerTimeUnit * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * valuePerTimeUnit($valuePerTimeUnit) * attr($attributionShare) * period($periodFactor)"
                }
            }
            'risk reduction' {
                $baseL = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'baselineLikelihood') -FieldName "$claimId.valuation.baselineLikelihood"
                $obsL = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'observedLikelihood') -FieldName "$claimId.valuation.observedLikelihood"
                $impactAmount = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'impactAmount') -FieldName "$claimId.valuation.impactAmount"
                $costPerIncident = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'costPerIncident') -FieldName "$claimId.valuation.costPerIncident"
                if ($null -ne $baseL -and $null -ne $obsL -and $null -ne $impactAmount -and $impactAmount -gt 0) {
                    $probDelta = $baseL - $obsL
                    if ($probDelta -le 0) {
                        $monetizable = $false
                    }
                    else {
                        $grossRaw = $probDelta * $impactAmount * $attributionShare * $periodFactor
                        $formulaText = "(baselineLikelihood($baseL) - observedLikelihood($obsL)) * impactAmount($impactAmount) * attr($attributionShare) * period($periodFactor)"
                    }
                }
                elseif ($null -ne $workingDelta -and $workingDelta -gt 0 -and $null -ne $costPerIncident -and $costPerIncident -gt 0) {
                    $grossRaw = $workingDelta * $volume * $costPerIncident * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * costPerIncident($costPerIncident) * attr($attributionShare) * period($periodFactor)"
                }
                else {
                    $monetizable = $false
                    $missingInputs.Add('valuation.baselineLikelihood/observedLikelihood/impactAmount or costPerIncident')
                }
            }
            'new capacity' {
                $demandVerified = Get-HveProp -InputObject $valuation -Name 'demandVerified'
                $unitValue = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'unitValue') -FieldName "$claimId.valuation.unitValue"
                if ($demandVerified -eq $false) {
                    $monetizable = $false
                    $gaps.Add('New capacity is not verified against real demand (demandVerified=false).')
                }
                elseif ($null -eq $workingDelta -or $workingDelta -le 0 -or $null -eq $unitValue -or $unitValue -le 0) {
                    $monetizable = $false
                    $missingInputs.Add('valuation.unitValue')
                }
                else {
                    $grossRaw = $workingDelta * $volume * $unitValue * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * unitValue($unitValue) * attr($attributionShare) * period($periodFactor)"
                }
            }
            'engagement' {
                $downRate = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'downstreamConversionRate') -FieldName "$claimId.valuation.downstreamConversionRate"
                $downValue = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $valuation -Name 'downstreamUnitValue') -FieldName "$claimId.valuation.downstreamUnitValue"
                if ($null -eq $workingDelta -or $workingDelta -le 0 -or $null -eq $downRate -or $downRate -le 0 -or $null -eq $downValue -or $downValue -le 0) {
                    $monetizable = $false
                    $missingInputs.Add('valuation.downstreamConversionRate and valuation.downstreamUnitValue')
                }
                else {
                    if ($downRate -gt 1) {
                        throw (Get-HveBenefitValuationStop -Message "Claim '$claimId' downstreamConversionRate must be in (0, 1].")
                    }
                    $grossRaw = $workingDelta * $volume * $downRate * $downValue * $attributionShare * $periodFactor
                    $formulaText = "$workingDelta * volume($volume) * downstreamConv($downRate) * downstreamUnitValue($downValue) * attr($attributionShare) * period($periodFactor)"
                }
            }
        }
    }

    $grossConverted = $null
    if ($monetizable -and $null -ne $grossRaw) {
        $fx = ConvertTo-HveCurrencyAmount -Amount $grossRaw -SourceCurrency $valCurrency -TargetCurrency $ReportCurrency -FxRates $FxRates
        if (-not $fx.Converted) {
            $monetizable = $false
            $gaps.Add($fx.Note)
            $missingInputs.Add("fx_rates.$($valCurrency.Trim().ToUpperInvariant())")
        }
        else {
            $grossConverted = $fx.Amount
        }
    }

    $monetaryBasis = if (-not $monetizable -or $null -eq $grossConverted) {
        'unmonetized-native-only'
    }
    elseif ($useForecast -or $evidenceStatus -eq 'pending') {
        'modeled-counterfactual'
    }
    elseif ($financeApprovedFlag -and $decisionStatus.ToLowerInvariant() -eq 'approved' -and -not [string]::IsNullOrWhiteSpace($decisionRef)) {
        'finance-approved'
    }
    else {
        'stated-indicative'
    }

    $effectiveUncertainty = if ($null -ne $uncertaintyPct) {
        $uncertaintyPct
    }
    elseif ($monetaryBasis -eq 'finance-approved') {
        [decimal]10
    }
    elseif ($monetaryBasis -eq 'stated-indicative') {
        [decimal]25
    }
    else {
        [decimal]35
    }

    return [pscustomobject]@{
        claimId                = $claimId
        category               = $category
        hypothesis             = $hypothesis
        beneficiary            = $beneficiary
        measurementOwner       = $measurementOwner
        decisionOwner          = $decisionOwner
        decisionStatus         = $decisionStatus
        decisionReference      = $decisionRef
        evidenceStatus         = $evidenceStatus
        evidenceLinks          = $evidenceLinks
        nativeUnit             = $(if (-not [string]::IsNullOrWhiteSpace($obsUnit)) { $obsUnit.Trim() } elseif (-not [string]::IsNullOrWhiteSpace($baseUnit)) { $baseUnit.Trim() } else { $null })
        nativeDelta            = $(if ($null -ne $nativeDelta) { [double][Math]::Round($nativeDelta, 4) } else { $null })
        monetaryBasis          = $monetaryBasis
        currency               = $ReportCurrency
        Formula                = $formulaText
        GrossDecimal           = $grossConverted
        OverlapGroup           = $(if ([string]::IsNullOrWhiteSpace($overlapGroup)) { $null } else { $overlapGroup.Trim() })
        PrimaryInGroup         = $primaryInGroup
        OverlapShare           = $overlapShare
        UncertaintyPct         = $effectiveUncertainty
        MissingValuationInputs = @($missingInputs | Select-Object -Unique)
        Gaps                   = @($gaps | Select-Object -Unique)
        Notes                  = @($notes | Select-Object -Unique)
    }
}

<#
.SYNOPSIS
    Computes the deterministic HVE FinOps stated monetary valuation model.
.PARAMETER InputDocument
    Parsed valuation input JSON object containing benefit_claims, cost_evidence, and optional delivery_valuation.
.PARAMETER EvidenceDocument
    Optional parsed evidence snapshot emitted by Collect-HveValueEvidence.ps1.
.PARAMETER AsOf
    Optional YYYY-MM-DD date string for reproducible output.
#>
function Get-HveBenefitValuation {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [AllowNull()]
        [object]$InputDocument,

        [AllowNull()]
        [object]$EvidenceDocument,

        [string]$AsOf = ''
    )
    $asOfText = if (-not [string]::IsNullOrWhiteSpace($AsOf)) {
        $AsOf.Trim()
    }
    elseif ($null -ne (Get-HveProp -InputObject $InputDocument -Name 'as_of')) {
        [string](Get-HveProp -InputObject $InputDocument -Name 'as_of')
    }
    else {
        [DateTimeOffset]::UtcNow.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    $reportId = [string](Get-HveProp -InputObject $InputDocument -Name 'report_id')
    if ([string]::IsNullOrWhiteSpace($reportId)) {
        $reportId = "hve-valuation-$asOfText"
    }

    $currencyRaw = [string](Get-HveProp -InputObject $InputDocument -Name 'currency')
    $currency = if ([string]::IsNullOrWhiteSpace($currencyRaw)) { 'USD' } else { $currencyRaw.Trim().ToUpperInvariant() }
    if ($currency -notmatch '^[A-Z]{3}$') {
        throw (Get-HveBenefitValuationStop -Message "Currency '$currency' must be a 3-letter ISO code.")
    }
    $fxRates = Get-HveProp -InputObject $InputDocument -Name 'fx_rates'
    if ($null -eq $fxRates) {
        $fxRates = Get-HveProp -InputObject $InputDocument -Name 'fxRates'
    }

    $docClaims = Get-HveProp -InputObject $InputDocument -Name 'benefit_claims'
    if ($null -eq $docClaims) {
        $docClaims = Get-HveProp -InputObject $InputDocument -Name 'claims'
    }
    $evaluatedClaims = @(
        if ($null -ne $docClaims) {
            foreach ($c in @($docClaims)) {
                if ($null -ne $c) {
                    Measure-HveSingleClaim -Claim $c -ReportCurrency $currency -FxRates $fxRates
                }
            }
        }
    )

    $overlapAdjustments = [System.Collections.Generic.List[object]]::new()
    $deductionByClaim = @{}
    foreach ($ec in $evaluatedClaims) {
        $deductionByClaim[$ec.claimId] = [decimal]0
    }

    $groups = @(
        $evaluatedClaims |
            Where-Object { $null -ne $_.OverlapGroup -and $_.monetaryBasis -in @('finance-approved', 'stated-indicative') -and $null -ne $_.GrossDecimal } |
            Group-Object -Property OverlapGroup
    )
    foreach ($grp in $groups) {
        if ($grp.Count -le 1) { continue }
        $ordered = @(
            $grp.Group | Sort-Object -Property @(
                @{ Expression = { if ($_.PrimaryInGroup) { 0 } else { 1 } }; Ascending = $true }
                @{ Expression = { if ($_.monetaryBasis -eq 'finance-approved') { 0 } else { 1 } }; Ascending = $true }
                @{ Expression = { $_.GrossDecimal }; Descending = $true }
            )
        )
        $primary = $ordered[0]
        for ($i = 1; $i -lt $ordered.Count; $i++) {
            $sec = $ordered[$i]
            $ded = $sec.GrossDecimal * $sec.OverlapShare
            $deductionByClaim[$sec.claimId] = $ded
            $overlapAdjustments.Add([ordered]@{
                overlapGroup    = $grp.Name
                retainedClaimId = $primary.claimId
                adjustedClaimId = $sec.claimId
                deductedAmount  = [double][Math]::Round($ded, 2)
                currency        = $currency
            })
        }
    }

    $hveDelivery = $null
    $laborFinApproved = [decimal]0
    $laborIndicative = [decimal]0
    $aiCounterfactualSavings = [decimal]0
    $hasAiCounterfactual = $false
    $aiSpendInCurrency = $null
    $crossGaps = [System.Collections.Generic.List[string]]::new()

    if ($null -ne $EvidenceDocument) {
        $rpi = Get-HveProp -InputObject $EvidenceDocument -Name 'rpiDelivery'
        $acc = Get-HveProp -InputObject $EvidenceDocument -Name 'accounting'
        $acceptedCount = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $rpi -Name 'acceptedReviews') -FieldName 'evidence.rpiDelivery.acceptedReviews'
        $producedCount = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $rpi -Name 'deliverablesProduced') -FieldName 'evidence.rpiDelivery.deliverablesProduced'
        $aiCostUsd = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $acc -Name 'costUsd') -FieldName 'evidence.accounting.costUsd'
        $cfBaseUsd = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $acc -Name 'counterfactualBaselineUsd') -FieldName 'evidence.accounting.counterfactualBaselineUsd'

        if ($null -ne $aiCostUsd) {
            $fxAi = ConvertTo-HveCurrencyAmount -Amount $aiCostUsd -SourceCurrency 'USD' -TargetCurrency $currency -FxRates $fxRates
            if ($fxAi.Converted) {
                $aiSpendInCurrency = $fxAi.Amount
            }
            else {
                $crossGaps.Add($fxAi.Note)
            }
        }
        if ($null -ne $aiCostUsd -and $null -ne $cfBaseUsd) {
            $fxCf = ConvertTo-HveCurrencyAmount -Amount ($cfBaseUsd - $aiCostUsd) -SourceCurrency 'USD' -TargetCurrency $currency -FxRates $fxRates
            if ($fxCf.Converted) {
                $aiCounterfactualSavings = $fxCf.Amount
                $hasAiCounterfactual = $true
            }
        }

        $delivVal = Get-HveProp -InputObject $InputDocument -Name 'delivery_valuation'
        if ($null -eq $delivVal) {
            $delivVal = Get-HveProp -InputObject $InputDocument -Name 'deliveryValuation'
        }
        $laborValue = $null
        $laborBasis = 'unmonetized-native-only'
        if ($null -ne $delivVal -and $null -ne $acceptedCount -and $acceptedCount -gt 0) {
            $dHourly = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $delivVal -Name 'hourlyRate') -FieldName 'delivery_valuation.hourlyRate'
            $dRedep = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $delivVal -Name 'redeployedShare') -FieldName 'delivery_valuation.redeployedShare'
            $dSaved = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $delivVal -Name 'hoursSavedPerAcceptedDeliverable') -FieldName 'delivery_valuation.hoursSavedPerAcceptedDeliverable'
            if ($null -eq $dSaved) {
                $dBase = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $delivVal -Name 'baselineHoursPerDeliverable') -FieldName 'delivery_valuation.baselineHoursPerDeliverable'
                $dObs = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $delivVal -Name 'observedHoursPerDeliverable') -FieldName 'delivery_valuation.observedHoursPerDeliverable'
                if ($null -ne $dBase -and $null -ne $dObs) {
                    $dSaved = $dBase - $dObs
                }
            }
            $dAttr = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $delivVal -Name 'attributionShare') -FieldName 'delivery_valuation.attributionShare'
            if ($null -eq $dAttr) { $dAttr = [decimal]1 }
            if ($null -ne $dHourly -and $dHourly -gt 0 -and $null -ne $dRedep -and $dRedep -gt 0 -and $dRedep -le 1 -and $null -ne $dSaved -and $dSaved -gt 0) {
                $laborValue = $acceptedCount * $dSaved * $dRedep * $dHourly * $dAttr
                $finApp = (Get-HveProp -InputObject $delivVal -Name 'financeApproved') -eq $true
                $finRef = [string](Get-HveProp -InputObject $delivVal -Name 'decisionReference')
                $laborBasis = if ($finApp -and -not [string]::IsNullOrWhiteSpace($finRef)) { 'finance-approved' } else { 'stated-indicative' }
                if ($laborBasis -eq 'finance-approved') {
                    $laborFinApproved = $laborValue
                }
                else {
                    $laborIndicative = $laborValue
                }
            }
        }

        $hveDelivery = [ordered]@{
            fileManifestSha256          = [string](Get-HveProp -InputObject $EvidenceDocument -Name 'fileManifestSha256')
            deliverablesProduced        = $(if ($null -ne $producedCount) { [int]$producedCount } else { 0 })
            acceptedDeliverables        = $(if ($null -ne $acceptedCount) { [int]$acceptedCount } else { 0 })
            aiSpend                     = $(if ($null -ne $aiSpendInCurrency) { [double][Math]::Round($aiSpendInCurrency, 4) } else { $null })
            counterfactualAiSavings     = $(if ($hasAiCounterfactual) { [double][Math]::Round($aiCounterfactualSavings, 4) } else { $null })
            statedDeliveryLaborValue    = $(if ($null -ne $laborValue) { [double][Math]::Round($laborValue, 2) } else { $null })
            statedDeliveryLaborBasis    = $laborBasis
        }
    }

    $finApprovedSum = $laborFinApproved
    $indicativeSum = $laborIndicative
    $counterfactualSum = if ($hasAiCounterfactual) { $aiCounterfactualSavings } else { [decimal]0 }
    $hasCf = $hasAiCounterfactual
    $lowBand = ($laborFinApproved * [decimal]0.90) + ($laborIndicative * [decimal]0.75)
    $highBand = ($laborFinApproved * [decimal]1.10) + ($laborIndicative * [decimal]1.25)

    $claimRows = [System.Collections.Generic.List[object]]::new()
    foreach ($ec in $evaluatedClaims) {
        $ded = [decimal]$deductionByClaim[$ec.claimId]
        $net = if ($null -ne $ec.GrossDecimal) { [Math]::Max([decimal]0, ($ec.GrossDecimal - $ded)) } else { $null }
        if ($ec.monetaryBasis -eq 'finance-approved' -and $null -ne $net) {
            $finApprovedSum += $net
            $frac = ($ec.UncertaintyPct / [decimal]100)
            $lowBand += $net * ([decimal]1 - $frac)
            $highBand += $net * ([decimal]1 + $frac)
        }
        elseif ($ec.monetaryBasis -eq 'stated-indicative' -and $null -ne $net) {
            $indicativeSum += $net
            $frac = ($ec.UncertaintyPct / [decimal]100)
            $lowBand += $net * ([decimal]1 - $frac)
            $highBand += $net * ([decimal]1 + $frac)
        }
        elseif ($ec.monetaryBasis -eq 'modeled-counterfactual' -and $null -ne $net) {
            $counterfactualSum += $net
            $hasCf = $true
        }
        foreach ($g in $ec.Gaps) {
            $crossGaps.Add("$($ec.claimId): $g")
        }
        $claimRows.Add([ordered]@{
            claimId                = $ec.claimId
            category               = $ec.category
            evidenceStatus         = $ec.evidenceStatus
            nativeDelta            = $ec.nativeDelta
            nativeUnit             = $ec.nativeUnit
            monetaryBasis          = $ec.monetaryBasis
            formula                = $ec.Formula
            grossMonetaryValue     = $(if ($null -ne $ec.GrossDecimal) { [double][Math]::Round($ec.GrossDecimal, 2) } else { $null })
            overlapDeduction       = $(if ($ded -gt 0) { [double][Math]::Round($ded, 2) } else { 0.0 })
            statedMonetaryValue    = $(if ($null -ne $net -and $ec.monetaryBasis -in @('finance-approved', 'stated-indicative')) { [double][Math]::Round($net, 2) } else { $null })
            modeledMonetaryValue   = $(if ($null -ne $net -and $ec.monetaryBasis -eq 'modeled-counterfactual') { [double][Math]::Round($net, 2) } else { $null })
            missingValuationInputs = $ec.MissingValuationInputs
            gaps                   = $ec.Gaps
        })
    }

    $costSum = [decimal]0
    $hasCost = $false
    $rawCosts = Get-HveProp -InputObject $InputDocument -Name 'cost_evidence'
    if ($null -eq $rawCosts) {
        $rawCosts = Get-HveProp -InputObject $InputDocument -Name 'costEvidence'
    }
    if ($null -ne $rawCosts) {
        foreach ($ce in @($rawCosts)) {
            if ($null -eq $ce) { continue }
            $amt = ConvertTo-HveDecimal -Value (Get-HveProp -InputObject $ce -Name 'amount') -FieldName 'cost_evidence.amount'
            $cCurr = [string](Get-HveProp -InputObject $ce -Name 'currency')
            if ([string]::IsNullOrWhiteSpace($cCurr)) { $cCurr = $currency }
            if ($null -ne $amt -and $amt -ge 0) {
                $fxC = ConvertTo-HveCurrencyAmount -Amount $amt -SourceCurrency $cCurr -TargetCurrency $currency -FxRates $fxRates
                if ($fxC.Converted) {
                    $costSum += $fxC.Amount
                    $hasCost = $true
                }
                else {
                    $crossGaps.Add($fxC.Note)
                }
            }
        }
    }

    $incAiProp = Get-HveProp -InputObject $InputDocument -Name 'includeAiSpendInCost'
    $incAi = if ($null -ne $incAiProp) { [bool]$incAiProp } else { $true }
    if ($incAi -and $null -ne $aiSpendInCurrency) {
        $costSum += $aiSpendInCurrency
        $hasCost = $true
    }

    $evidencedCount = @($evaluatedClaims | Where-Object { $_.monetaryBasis -in @('finance-approved', 'stated-indicative') }).Count
    $hasEvidenced = ($evidencedCount -gt 0 -or $laborFinApproved -gt 0 -or $laborIndicative -gt 0)
    $totalEvidenced = if ($hasEvidenced) { $finApprovedSum + $indicativeSum } else { $null }
    $netStated = if ($null -ne $totalEvidenced -and $hasCost) { $totalEvidenced - $costSum } else { $null }
    $roiPct = if ($null -ne $netStated -and $costSum -gt 0) { ($netStated / $costSum) * [decimal]100 } else { $null }
    $bcr = if ($null -ne $totalEvidenced -and $costSum -gt 0) { $totalEvidenced / $costSum } else { $null }

    $overallBasis = if (-not $hasEvidenced) {
        'unmonetized-native-only'
    }
    elseif ($indicativeSum -eq 0 -and $finApprovedSum -gt 0) {
        'finance-approved'
    }
    elseif ($finApprovedSum -eq 0) {
        'stated-indicative'
    }
    else {
        'mixed-evidenced'
    }

    return [ordered]@{
        schemaVersion      = '1.0'
        reportId           = $reportId
        asOf               = $asOfText
        currency           = $currency
        summary            = [ordered]@{
            overallBasis               = $overallBasis
            financeApprovedValue       = $(if ($hasEvidenced) { [double][Math]::Round($finApprovedSum, 2) } else { $null })
            statedIndicativeValue      = $(if ($hasEvidenced) { [double][Math]::Round($indicativeSum, 2) } else { $null })
            totalStatedEvidencedValue  = $(if ($null -ne $totalEvidenced) { [double][Math]::Round($totalEvidenced, 2) } else { $null })
            sensitivityRange           = $(if ($null -ne $totalEvidenced) {
                    [ordered]@{
                        low    = [double][Math]::Round($lowBand, 2)
                        stated = [double][Math]::Round($totalEvidenced, 2)
                        high   = [double][Math]::Round($highBand, 2)
                    }
                }
                else {
                    $null
                })
            totalEvidencedCost         = $(if ($hasCost) { [double][Math]::Round($costSum, 4) } else { $null })
            netStatedValue             = $(if ($null -ne $netStated) { [double][Math]::Round($netStated, 2) } else { $null })
            benefitCostRatio           = $(if ($null -ne $bcr) { [double][Math]::Round($bcr, 2) } else { $null })
            statedRoiPct               = $(if ($null -ne $roiPct) { [double][Math]::Round($roiPct, 1) } else { $null })
            modeledCounterfactualValue = $(if ($hasCf) { [double][Math]::Round($counterfactualSum, 2) } else { $null })
            overlapDeductionsTotal     = $(
                $deductionTotal = 0.0
                foreach ($dv in $deductionByClaim.Values) { $deductionTotal += [double]$dv }
                [double][Math]::Round($deductionTotal, 2)
            )
        }
        hveDelivery        = $hveDelivery
        claims             = $claimRows.ToArray()
        overlapAdjustments = $overlapAdjustments.ToArray()
        gaps               = @($crossGaps | Select-Object -Unique)
    }
}

<#
.SYNOPSIS
    Renders a deterministic Markdown Stated Monetary Value Report from Get-HveBenefitValuation output.
.PARAMETER Model
    Ordered dictionary returned by Get-HveBenefitValuation.
#>
function ConvertTo-HveBenefitValuationMarkdown {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Model
    )
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $curr = $Model['currency']
    $s = $Model['summary']
    $fmtMoney = {
        param($val, [int]$digits = 2)
        if ($null -eq $val) { return 'unavailable' }
        return "$curr " + ([double]$val).ToString("N$digits", $inv)
    }
    $fmtPct = {
        param($val)
        if ($null -eq $val) { return 'unavailable' }
        return ([double]$val).ToString('N1', $inv) + '%'
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Stated Monetary Value Report: $($Model['reportId'])")
    $lines.Add('')
    $lines.Add("* **As of:** $($Model['asOf'])")
    $lines.Add("* **Currency:** $curr")
    $lines.Add("* **Overall Basis:** ``$($s['overallBasis'])``")
    $lines.Add('')
    $lines.Add('## Executive Stated Value Summary')
    $lines.Add('')
    $lines.Add('| Metric | Value | Basis |')
    $lines.Add('|--------|------:|-------|')
    $lines.Add("| Finance-Approved (Booked) Value | $(& $fmtMoney $s['financeApprovedValue'] 2) | ``finance-approved`` |")
    $lines.Add("| Stated Indicative (Evidenced) Value | $(& $fmtMoney $s['statedIndicativeValue'] 2) | ``stated-indicative`` |")
    $lines.Add("| **Total Stated Evidenced Value** | **$(& $fmtMoney $s['totalStatedEvidencedValue'] 2)** | ``$($s['overallBasis'])`` |")
    $lines.Add("| Total Evidenced Cost | $(& $fmtMoney $s['totalEvidencedCost'] 4) | ``evidenced-cost`` |")
    $lines.Add("| **Net Stated Value** | **$(& $fmtMoney $s['netStatedValue'] 2)** | ``derived`` |")
    $bcrStr = if ($null -ne $s['benefitCostRatio']) { ([double]$s['benefitCostRatio']).ToString('N2', $inv) + 'x' } else { 'unavailable' }
    $lines.Add("| Benefit-Cost Ratio (BCR) | $bcrStr | ``derived`` |")
    $lines.Add("| Stated ROI | $(& $fmtPct $s['statedRoiPct']) | ``derived`` |")
    $lines.Add("| Modeled Counterfactual / Forecast Value | $(& $fmtMoney $s['modeledCounterfactualValue'] 2) | ``modeled-counterfactual`` |")
    $lines.Add('')
    $lines.Add('> **Note** - Stated indicative figures reflect supplied evidence and explicit valuation assumptions; Finance-approved booked value requires human Finance or business-owner sign-off.')
    $lines.Add('')
    return ($lines -join "`n") + "`n"
}

Export-ModuleMember -Function Get-HveBenefitValuation, ConvertTo-HveBenefitValuationMarkdown, Get-HveBenefitValuationStop, Assert-HveSafePath
