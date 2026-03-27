<#
.SYNOPSIS
    Build and deploy the Chaos Engineering Portal to AKS.

.DESCRIPTION
    This script:
    1. Builds the API and Web container images using `az acr build` (no local Docker needed)
    2. Creates the ops namespace and RBAC
    3. Creates a ConfigMap with scenario YAML files
    4. Deploys the portal to the AKS cluster
    5. Configures Workload Identity federated credentials

.PARAMETER ResourceGroupName
    Resource group containing the AKS cluster and ACR.

.PARAMETER WorkloadName
    Workload name prefix (default: srelab).

.PARAMETER SubscriptionId
    Azure subscription ID. If not provided, uses current context.

.PARAMETER SkipBuild
    Skip container image builds (use existing images).

.EXAMPLE
    .\build-portal.ps1 -ResourceGroupName EXP-SREDEMO-AKS-CUS-RG

.EXAMPLE
    .\build-portal.ps1 -ResourceGroupName EXP-SREDEMO-AKS-CUS-RG -SkipBuild
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$WorkloadName = 'srelab',

    [string]$SubscriptionId = '',

    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSScriptRoot
$portalDir = Join-Path $scriptRoot 'portal'

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              Chaos Engineering Portal - Build & Deploy                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── Resolve subscription and resources ──────────────────────────────────────
if (-not $SubscriptionId) {
    $SubscriptionId = az account show --query id -o tsv
    Write-Host "  Using subscription: $SubscriptionId" -ForegroundColor Gray
}

$acrName = az acr list --resource-group $ResourceGroupName --query "[0].name" -o tsv
if (-not $acrName) {
    Write-Host "  ❌ No ACR found in resource group $ResourceGroupName" -ForegroundColor Red
    exit 1
}
Write-Host "  ACR: $acrName" -ForegroundColor Green

$aksName = az aks list --resource-group $ResourceGroupName --query "[0].name" -o tsv
if (-not $aksName) {
    Write-Host "  ❌ No AKS cluster found in resource group $ResourceGroupName" -ForegroundColor Red
    exit 1
}
Write-Host "  AKS: $aksName" -ForegroundColor Green

# Get AKS OIDC issuer for Workload Identity
$oidcIssuer = az aks show --resource-group $ResourceGroupName --name $aksName --query "oidcIssuerProfile.issuerUrl" -o tsv
Write-Host "  OIDC Issuer: $oidcIssuer" -ForegroundColor Gray

# ─── Build container images ──────────────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "  📦 Building API image..." -ForegroundColor Yellow
    az acr build `
        --registry $acrName `
        --image chaos-portal-api:latest `
        --file "$portalDir/Dockerfile.api" `
        "$portalDir/api"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ API image build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ API image built" -ForegroundColor Green

    Write-Host ""
    Write-Host "  📦 Building Web image..." -ForegroundColor Yellow

    # Copy nginx.conf into web context for the build
    Copy-Item "$portalDir/nginx.conf" "$portalDir/web/nginx.conf" -Force

    az acr build `
        --registry $acrName `
        --image chaos-portal-web:latest `
        --file "$portalDir/Dockerfile.web" `
        "$portalDir/web"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ Web image build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ Web image built" -ForegroundColor Green
}

# ─── Get AKS credentials ────────────────────────────────────────────────────
Write-Host ""
Write-Host "  🔑 Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroupName --name $aksName --overwrite-existing

# ─── Create managed identity + federated credential for Workload Identity ────
$identityName = "id-chaos-portal-$WorkloadName"
$existingId = az identity show --resource-group $ResourceGroupName --name $identityName --query "clientId" -o tsv 2>$null

if (-not $existingId) {
    Write-Host "  🔐 Creating managed identity: $identityName" -ForegroundColor Yellow
    az identity create --resource-group $ResourceGroupName --name $identityName --output none
    Start-Sleep -Seconds 10  # Wait for AAD replication
    $existingId = az identity show --resource-group $ResourceGroupName --name $identityName --query "clientId" -o tsv
}
$identityClientId = $existingId
$identityPrincipalId = az identity show --resource-group $ResourceGroupName --name $identityName --query "principalId" -o tsv
Write-Host "  Identity Client ID: $identityClientId" -ForegroundColor Gray

# Assign Chaos Studio operator role on the resource group
$rgId = az group show --name $ResourceGroupName --query "id" -o tsv
az role assignment create `
    --assignee-object-id $identityPrincipalId `
    --assignee-principal-type ServicePrincipal `
    --role "Chaos Studio Operator" `
    --scope $rgId `
    --output none 2>$null
Write-Host "  ✅ Chaos Studio Operator role assigned" -ForegroundColor Green

# Create federated credential
$fedCredName = "chaos-portal-fedcred"
$existingFedCred = az identity federated-credential show `
    --identity-name $identityName `
    --resource-group $ResourceGroupName `
    --name $fedCredName `
    --query "name" -o tsv 2>$null

if (-not $existingFedCred) {
    Write-Host "  🔗 Creating federated credential..." -ForegroundColor Yellow
    az identity federated-credential create `
        --identity-name $identityName `
        --resource-group $ResourceGroupName `
        --name $fedCredName `
        --issuer $oidcIssuer `
        --subject "system:serviceaccount:ops:chaos-portal" `
        --audience "api://AzureADTokenExchange" `
        --output none
    Write-Host "  ✅ Federated credential created" -ForegroundColor Green
}

# ─── Deploy Kubernetes resources ─────────────────────────────────────────────
Write-Host ""
Write-Host "  🚀 Deploying portal to AKS..." -ForegroundColor Yellow

$k8sDir = Join-Path $portalDir 'k8s'

# Apply namespace first
kubectl apply -f "$k8sDir/namespace.yaml"

# Create ConfigMap from scenario files
$scenariosDir = Join-Path $scriptRoot 'k8s' 'scenarios'
$baseDir = Join-Path $scriptRoot 'k8s' 'base'

# Create ConfigMap with all scenario YAMLs and baseline
$configMapArgs = @("create", "configmap", "chaos-scenarios", "-n", "ops", "--dry-run=client", "-o", "yaml")

# Add scenario files
Get-ChildItem "$scenariosDir/*.yaml" | ForEach-Object {
    $configMapArgs += "--from-file=$($_.Name)=$($_.FullName)"
}
# Add baseline
$configMapArgs += "--from-file=application.yaml=$baseDir/application.yaml"

$configMapYaml = kubectl @configMapArgs
$configMapYaml | kubectl apply -f -

# Apply service account with actual client ID
$saContent = Get-Content "$k8sDir/serviceaccount.yaml" -Raw
$saContent = $saContent.Replace('${WORKLOAD_IDENTITY_CLIENT_ID}', $identityClientId)
$saContent | kubectl apply -f -

# Apply RBAC
kubectl apply -f "$k8sDir/rbac.yaml"

# Apply deployments with substitutions
foreach ($file in @('api-deployment.yaml', 'web-deployment.yaml')) {
    $content = Get-Content "$k8sDir/$file" -Raw
    $content = $content.Replace('${ACR_NAME}', $acrName)
    $content = $content.Replace('${AZURE_SUBSCRIPTION_ID}', $SubscriptionId)
    $content = $content.Replace('${AZURE_RESOURCE_GROUP}', $ResourceGroupName)
    $content = $content.Replace('${WORKLOAD_NAME}', $WorkloadName)
    $content | kubectl apply -f -
}

# Apply services
kubectl apply -f "$k8sDir/service.yaml"

# ─── Wait for rollout ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ⏳ Waiting for portal pods..." -ForegroundColor Yellow
kubectl rollout status deployment/chaos-portal-api -n ops --timeout=120s
kubectl rollout status deployment/chaos-portal-web -n ops --timeout=120s

# ─── Get portal URL ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ⏳ Waiting for LoadBalancer IP..." -ForegroundColor Yellow
$maxWait = 120
$waited = 0
$portalIp = ''
while ($waited -lt $maxWait) {
    $portalIp = kubectl get svc chaos-portal-web -n ops -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($portalIp) { break }
    Start-Sleep -Seconds 5
    $waited += 5
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Chaos Engineering Portal - Deployed!                       ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Green
if ($portalIp) {
    Write-Host "║  Portal URL: http://$($portalIp.PadRight(52))║" -ForegroundColor Green
} else {
    Write-Host "║  Portal URL: (pending — run: kubectl get svc -n ops)                 ║" -ForegroundColor Yellow
}
Write-Host "║  Namespace:  ops                                                        ║" -ForegroundColor Green
Write-Host "║  API:        chaos-portal-api (port 3001)                               ║" -ForegroundColor Green
Write-Host "║  Web:        chaos-portal-web (port 80 → 8080)                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
