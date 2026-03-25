<#
.SYNOPSIS
    Tears down the Azure SRE Agent Demo Lab infrastructure.

.DESCRIPTION
    This script removes all Azure resources created by the deployment script.
    Deletes all 3 pre-staged resource groups (infra, monitor, sre).
    Use with caution - this action is irreversible!

.PARAMETER Environment
    Environment prefix for RG naming. Default: EXP

.PARAMETER ProjectName
    Project name for RG naming. Default: SREDEMO

.PARAMETER Location
    Azure region for infra/monitor RGs. Default: centralus

.PARAMETER SreAgentLocation
    Azure region for SRE Agent RG naming. Default: eastus2

.PARAMETER WorkloadName
    Name prefix for resources (used for kubectl context cleanup). Default: expsre

.PARAMETER InfraResourceGroupName
    Override the infra resource group name.
    Default: {ENV}-{PROJECT}-AKS-{REGION}-RG

.PARAMETER MonitorResourceGroupName
    Override the monitor resource group name.
    Default: {ENV}-{PROJECT}-MON-{REGION}-RG

.PARAMETER SreResourceGroupName
    Override the SRE resource group name.
    Default: {ENV}-{PROJECT}-SRE-{SRE_REGION}-RG

.PARAMETER NodeResourceGroupName
    Override the AKS node resource group name (MC_ group) to also delete.

.PARAMETER Force
    Skip confirmation prompt

.EXAMPLE
    .\destroy.ps1

.EXAMPLE
    .\destroy.ps1 -Environment DEV -ProjectName MYPROJECT -Force
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Environment = 'EXP',

    [Parameter()]
    [string]$ProjectName = 'SREDEMO',

    [Parameter()]
    [string]$Location = 'centralus',

    [Parameter()]
    [string]$SreAgentLocation = 'eastus2',

    [Parameter()]
    [string]$WorkloadName = 'srelab',

    [Parameter(HelpMessage = 'Override the infra resource group name')]
    [string]$InfraResourceGroupName,

    [Parameter(HelpMessage = 'Override the monitor resource group name')]
    [string]$MonitorResourceGroupName,

    [Parameter(HelpMessage = 'Override the SRE resource group name')]
    [string]$SreResourceGroupName,

    [Parameter(HelpMessage = 'Override the AKS node resource group name (MC_ group) to also delete')]
    [string]$NodeResourceGroupName,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Region abbreviation mapping for RG naming convention
$regionAbbreviations = @{
    'centralus'      = 'CUS'
    'eastus2'        = 'EAUS2'
    'swedencentral'  = 'SWEC'
    'australiaeast'  = 'AUCE'
}
$regionAbbr = $regionAbbreviations[$Location]
$sreRegionAbbr = $regionAbbreviations[$SreAgentLocation]
$envUpper = $Environment.ToUpper()
$projUpper = $ProjectName.ToUpper()

$infraRg = if ($InfraResourceGroupName) { $InfraResourceGroupName } else { "$envUpper-$projUpper-AKS-$regionAbbr-RG" }
$monitorRg = if ($MonitorResourceGroupName) { $MonitorResourceGroupName } else { "$envUpper-$projUpper-MON-$regionAbbr-RG" }
$sreRg = if ($SreResourceGroupName) { $SreResourceGroupName } else { "$envUpper-$projUpper-SRE-$sreRegionAbbr-RG" }
$allRgs = @($infraRg, $monitorRg, $sreRg)
if ($NodeResourceGroupName) {
    $allRgs += $NodeResourceGroupName
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                    Azure SRE Agent Demo Lab - DESTROY                        ║
║                                                                              ║
║                         ⚠️  WARNING ⚠️                                        ║
║                                                                              ║
║  This will PERMANENTLY DELETE all 3 resource groups and their contents!      ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Red

# Check which resource groups exist
$existingRgs = @()
$keyVaultNames = @()
$rgLocations = @{}

foreach ($rgName in $allRgs) {
    $rg = az group show --name $rgName --output json 2>$null | ConvertFrom-Json
    if ($rg) {
        $existingRgs += $rgName
        $rgLocations[$rgName] = $rg.location
        Write-Host "📋 $rgName ($($rg.location))" -ForegroundColor White

        $resources = az resource list --resource-group $rgName --output json 2>$null | ConvertFrom-Json
        foreach ($resource in $resources) {
            Write-Host "   • $($resource.type) - $($resource.name)" -ForegroundColor Gray
        }

        $kvNames = @($resources | Where-Object { $_.type -eq 'Microsoft.KeyVault/vaults' } | ForEach-Object { $_.name })
        if ($kvNames.Count -gt 0) {
            $keyVaultNames += $kvNames
        }

        Write-Host "   Total: $($resources.Count) resources`n" -ForegroundColor White
    }
    else {
        Write-Host "⏭️  $rgName — not found, skipping" -ForegroundColor Gray
    }
}

if ($existingRgs.Count -eq 0) {
    Write-Host "❌ No resource groups found. Nothing to delete." -ForegroundColor Yellow
    exit 0
}

# Confirmation
if (-not $Force) {
    Write-Host "`n⚠️  This action cannot be undone!" -ForegroundColor Red
    $confirm = Read-Host "Type 'DELETE' to confirm"

    if ($confirm -ne 'DELETE') {
        Write-Host "`nDestroy cancelled." -ForegroundColor Green
        exit 0
    }
}

# Delete all existing resource groups
foreach ($rgName in $existingRgs) {
    Write-Host "`n🗑️  Deleting resource group '$rgName'..." -ForegroundColor Yellow
    try {
        az group delete --name $rgName --yes --no-wait
        Write-Host "  ✅ Deletion initiated" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Failed to delete: $_" -ForegroundColor Red
    }
}

# Wait for infra RG deletion (contains Key Vault) then purge KVs
if ($keyVaultNames.Count -gt 0) {
    $kvRg = $existingRgs | Where-Object { $_ -eq $infraRg } | Select-Object -First 1
    if ($kvRg) {
        Write-Host "`n🔐 Waiting for infra RG deletion so Key Vault names can be purged..." -ForegroundColor Yellow
        $deadline = (Get-Date).AddMinutes(20)
        $groupDeleted = $false

        do {
            $groupExists = az group exists --name $kvRg --output tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and $groupExists -eq 'false') {
                $groupDeleted = $true
                break
            }
            Start-Sleep -Seconds 10
        } while ((Get-Date) -lt $deadline)

        if ($groupDeleted) {
            Write-Host "  ✅ Infra resource group deleted" -ForegroundColor Green
            Write-Host "`n🧹 Purging deleted Key Vault records..." -ForegroundColor Yellow

            $kvLocation = $rgLocations[$kvRg]
            foreach ($keyVaultName in $keyVaultNames) {
                $vaultDeadline = (Get-Date).AddMinutes(5)
                $deletedVaultFound = $false

                do {
                    $deletedCount = az keyvault list-deleted --query "[?name=='$keyVaultName'] | length(@)" --output tsv 2>$null
                    if ($LASTEXITCODE -eq 0 -and $deletedCount -eq '1') {
                        $deletedVaultFound = $true
                        break
                    }
                    Start-Sleep -Seconds 5
                } while ((Get-Date) -lt $vaultDeadline)

                if (-not $deletedVaultFound) {
                    Write-Host "   ⚠️  Deleted vault not found for $keyVaultName" -ForegroundColor Yellow
                    continue
                }

                $purgeOutput = az keyvault purge --name $keyVaultName --location $kvLocation 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Purged $keyVaultName" -ForegroundColor Green
                }
                else {
                    Write-Host "   ⚠️  Failed to purge $keyVaultName" -ForegroundColor Yellow
                    if (-not [string]::IsNullOrWhiteSpace($purgeOutput)) {
                        Write-Host "      $($purgeOutput.Trim())" -ForegroundColor Gray
                    }
                }
            }
        }
        else {
            Write-Host "  ⚠️  Infra RG deletion still in progress. Key Vault purge was not attempted." -ForegroundColor Yellow
        }
    }
}

# Clean up local files
Write-Host "`n🧹 Cleaning up local files..." -ForegroundColor Yellow

$outputsFile = Join-Path $PSScriptRoot "deployment-outputs.json"
if (Test-Path $outputsFile) {
    Remove-Item $outputsFile -Force
    Write-Host "   ✅ Removed deployment-outputs.json" -ForegroundColor Green
}

# Remove kubectl context
Write-Host "`n🔑 Cleaning up kubectl context..." -ForegroundColor Yellow
kubectl config delete-context "aks-$WorkloadName" 2>$null
Write-Host "   ✅ kubectl context cleaned up" -ForegroundColor Green

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                        Cleanup Complete! 🧹                                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  Resource group deletions have been submitted for:                           ║
║    • $($infraRg.PadRight(60))║
║    • $($monitorRg.PadRight(58))║
║    • $($sreRg.PadRight(61))║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
