<#
.SYNOPSIS
    Run breakable fault-injection scenarios against the AKS SRE demo environment.

.DESCRIPTION
    Unified orchestration script for all 10 breakable scenarios.
    - Scenarios 1,2,4,6,7,9 run via Azure Chaos Studio experiments (automated).
    - Scenarios 3,5,8,10 run via kubectl apply (manifest-based misconfigurations).
    
    Each scenario can be started individually, or all Chaos Studio scenarios
    can be run sequentially. The script also provides fix/restore commands.

.PARAMETER Scenario
    Name of the scenario to run. Use 'list' to see all available scenarios.
    Valid values: oom-killed, crash-loop, image-pull-backoff, high-cpu,
    pending-pods, probe-failure, network-block, missing-config,
    mongodb-down, service-mismatch, all-chaos, list

.PARAMETER Action
    Action to perform: 'start' to inject the fault, 'stop' to cancel/fix,
    'status' to check experiment status.

.PARAMETER ResourceGroupName
    Name of the resource group containing the AKS cluster and Chaos experiments.

.PARAMETER WorkloadName
    Workload name prefix used for naming Chaos experiments (default: expsre).

.PARAMETER NoWait
    Don't wait for Chaos Studio experiments to start running.

.EXAMPLE
    .\run-chaos-scenarios.ps1 -Scenario oom-killed -Action start -ResourceGroupName rg-srelab-centralus
    
.EXAMPLE
    .\run-chaos-scenarios.ps1 -Scenario list

.EXAMPLE
    .\run-chaos-scenarios.ps1 -Scenario all-chaos -Action start -ResourceGroupName rg-srelab-centralus
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'oom-killed', 'crash-loop', 'image-pull-backoff', 'high-cpu',
        'pending-pods', 'probe-failure', 'network-block', 'missing-config',
        'mongodb-down', 'service-mismatch', 'all-chaos', 'list'
    )]
    [string]$Scenario,

    [ValidateSet('start', 'stop', 'status')]
    [string]$Action = 'start',

    [string]$ResourceGroupName = '',

    [string]$WorkloadName = 'srelab',

    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

# =============================================================================
# SCENARIO DEFINITIONS
# =============================================================================

$chaosScenarios = @{
    'oom-killed'    = @{
        ExperimentName = "chaos-${WorkloadName}-oom-killed"
        Description    = 'Memory stress on order-service pods (OOMKilled)'
        SrePrompts     = @(
            'Why is the order-service pod restarting repeatedly?'
            'I see OOMKilled events. What memory should I allocate?'
        )
    }
    'crash-loop'    = @{
        ExperimentName = "chaos-${WorkloadName}-crash-loop"
        Description    = 'Pod kill on product-service (CrashLoopBackOff)'
        SrePrompts     = @(
            'Why is product-service in CrashLoopBackOff?'
            'Show me the logs for the crashing pods'
        )
    }
    'high-cpu'      = @{
        ExperimentName = "chaos-${WorkloadName}-high-cpu"
        Description    = 'CPU stress on order-service pods (resource exhaustion)'
        SrePrompts     = @(
            'My application is slow. What is consuming all the CPU?'
            'Analyze CPU usage across my pods'
        )
    }
    'probe-failure' = @{
        ExperimentName = "chaos-${WorkloadName}-probe-failure"
        Description    = 'HTTP fault injection - health endpoints return 500'
        SrePrompts     = @(
            'My pods keep restarting but the app seems fine'
            'Diagnose the health check failures'
        )
    }
    'network-block' = @{
        ExperimentName = "chaos-${WorkloadName}-network-block"
        Description    = 'Network partition blocking order-service traffic'
        SrePrompts     = @(
            'Why can''t store-front reach order-service?'
            'Diagnose network connectivity issues in pets namespace'
        )
    }
    'mongodb-down'  = @{
        ExperimentName = "chaos-${WorkloadName}-mongodb-down"
        Description    = 'Pod kill on mongodb (cascading dependency failure)'
        SrePrompts     = @(
            'The app is up but orders aren''t going through. What''s wrong?'
            'Trace the dependency chain - what broke first?'
        )
    }
}

$kubectlScenarios = @{
    'image-pull-backoff' = @{
        ScenarioFile = 'k8s/scenarios/image-pull-backoff.yaml'
        FixCommand   = 'kubectl apply -f k8s/base/application.yaml'
        Description  = 'Deploy bad image reference (ImagePullBackOff)'
        SrePrompts   = @(
            'Why can''t my pods start? I see ImagePullBackOff'
            'Help me troubleshoot the container image issue'
        )
    }
    'pending-pods'       = @{
        ScenarioFile = 'k8s/scenarios/pending-pods.yaml'
        FixCommand   = 'kubectl delete deployment resource-hog -n pets'
        Description  = 'Deploy pods requesting impossible resources (Pending)'
        SrePrompts   = @(
            'Why are my pods stuck in Pending?'
            'Analyze cluster capacity and pending pods'
        )
    }
    'missing-config'     = @{
        ScenarioFile = 'k8s/scenarios/missing-config.yaml'
        FixCommand   = 'kubectl delete deployment misconfigured-service -n pets'
        Description  = 'Deploy with non-existent ConfigMap reference'
        SrePrompts   = @(
            'My pod won''t start. Says something about ConfigMap?'
            'What configuration is missing for my deployment?'
        )
    }
    'service-mismatch'   = @{
        ScenarioFile = 'k8s/scenarios/service-mismatch.yaml'
        FixCommand   = 'kubectl apply -f k8s/base/application.yaml'
        Description  = 'Apply wrong Service selector (silent networking failure)'
        SrePrompts   = @(
            'The site loads but placing an order fails. Everything looks healthy.'
            'Why does the order-service have no endpoints?'
        )
    }
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Show-ScenarioList {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Breakable Scenarios - Chaos Studio + kubectl               ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║                                                                          ║" -ForegroundColor Cyan
    Write-Host "║  CHAOS STUDIO (automated, 10-min duration, auto-cleanup):                ║" -ForegroundColor Cyan
    Write-Host "║                                                                          ║" -ForegroundColor Cyan

    $i = 1
    foreach ($name in ($chaosScenarios.Keys | Sort-Object)) {
        $desc = $chaosScenarios[$name].Description
        $num = $i.ToString().PadLeft(2)
        Write-Host "║   $num. $($name.PadRight(18)) $($desc.PadRight(42))║" -ForegroundColor Cyan
        $i++
    }

    Write-Host "║                                                                          ║" -ForegroundColor Cyan
    Write-Host "║  KUBECTL (manifest-based, manual cleanup required):                      ║" -ForegroundColor Cyan
    Write-Host "║                                                                          ║" -ForegroundColor Cyan

    foreach ($name in ($kubectlScenarios.Keys | Sort-Object)) {
        $desc = $kubectlScenarios[$name].Description
        $num = $i.ToString().PadLeft(2)
        Write-Host "║   $num. $($name.PadRight(18)) $($desc.PadRight(42))║" -ForegroundColor Cyan
        $i++
    }

    Write-Host "║                                                                          ║" -ForegroundColor Cyan
    Write-Host "║  SPECIAL:                                                                ║" -ForegroundColor Cyan
    Write-Host "║   all-chaos         Run all 6 Chaos Studio experiments sequentially       ║" -ForegroundColor Cyan
    Write-Host "║                                                                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Start-ChaosExperiment {
    param([string]$Name, [hashtable]$Config)

    Write-Host "  🔥 Starting Chaos Experiment: $Name" -ForegroundColor Yellow
    Write-Host "     $($Config.Description)" -ForegroundColor Gray

    $result = az rest --method POST `
        --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Chaos/experiments/$($Config.ExperimentName)/start?api-version=2024-01-01" `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "     ❌ Failed to start experiment: $result" -ForegroundColor Red
        return $false
    }

    Write-Host "     ✅ Experiment started successfully" -ForegroundColor Green

    if (-not $NoWait) {
        Write-Host "     ⏳ Waiting for experiment to enter Running state..." -ForegroundColor Gray
        $maxWait = 60
        $waited = 0
        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 5
            $waited += 5
            $status = az rest --method GET `
                --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Chaos/experiments/$($Config.ExperimentName)/statuses?api-version=2024-01-01" `
                --query "value[0].properties.status" -o tsv 2>$null
            if ($status -eq 'Running') {
                Write-Host "     🟢 Experiment is Running (duration: 10 minutes)" -ForegroundColor Green
                break
            }
        }
        if ($waited -ge $maxWait) {
            Write-Host "     ⚠️  Experiment may still be starting. Check status manually." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "     📋 SRE Agent Prompts to try:" -ForegroundColor Cyan
    foreach ($prompt in $Config.SrePrompts) {
        Write-Host "        > `"$prompt`"" -ForegroundColor White
    }
    Write-Host ""
    return $true
}

function Stop-ChaosExperiment {
    param([string]$Name, [hashtable]$Config)

    Write-Host "  🛑 Cancelling Chaos Experiment: $Name" -ForegroundColor Yellow

    $subscriptionId = az account show --query id -o tsv
    az rest --method POST `
        --url "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Chaos/experiments/$($Config.ExperimentName)/cancel?api-version=2024-01-01" `
        --output none 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "     ✅ Experiment cancelled. Chaos Mesh will clean up automatically." -ForegroundColor Green
    }
    else {
        Write-Host "     ⚠️  Experiment may not be running or already completed." -ForegroundColor Yellow
    }
}

function Get-ChaosExperimentStatus {
    param([string]$Name, [hashtable]$Config)

    $subscriptionId = az account show --query id -o tsv
    $status = az rest --method GET `
        --url "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Chaos/experiments/$($Config.ExperimentName)/statuses?api-version=2024-01-01" `
        --query "value[0].properties.status" -o tsv 2>$null

    if ($status) {
        $color = switch ($status) {
            'Running' { 'Yellow' }
            'Success' { 'Green' }
            'Failed' { 'Red' }
            'Cancelled' { 'Gray' }
            default { 'White' }
        }
        Write-Host "  📊 $($Name.PadRight(18)) Status: $status" -ForegroundColor $color
    }
    else {
        Write-Host "  📊 $($Name.PadRight(18)) Status: No executions found" -ForegroundColor Gray
    }
}

function Start-KubectlScenario {
    param([string]$Name, [hashtable]$Config)

    Write-Host "  🔥 Applying kubectl scenario: $Name" -ForegroundColor Yellow
    Write-Host "     $($Config.Description)" -ForegroundColor Gray

    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $scenarioPath = Join-Path $scriptRoot $Config.ScenarioFile

    if (-not (Test-Path $scenarioPath)) {
        # Try relative to current directory
        $scenarioPath = $Config.ScenarioFile
    }

    kubectl apply -f $scenarioPath 2>&1 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "     ✅ Scenario applied successfully" -ForegroundColor Green
    }
    else {
        Write-Host "     ❌ Failed to apply scenario" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "     📋 SRE Agent Prompts to try:" -ForegroundColor Cyan
    foreach ($prompt in $Config.SrePrompts) {
        Write-Host "        > `"$prompt`"" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "     🔧 To fix: $($Config.FixCommand)" -ForegroundColor Magenta
    Write-Host ""
}

function Stop-KubectlScenario {
    param([string]$Name, [hashtable]$Config)

    Write-Host "  🛑 Fixing kubectl scenario: $Name" -ForegroundColor Yellow

    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $fixParts = $Config.FixCommand -split ' '

    # Execute the fix command
    Invoke-Expression $Config.FixCommand 2>&1 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "     ✅ Scenario reverted successfully" -ForegroundColor Green
    }
    else {
        Write-Host "     ⚠️  Fix command returned non-zero exit code. Check manually." -ForegroundColor Yellow
    }
}

# =============================================================================
# MAIN LOGIC
# =============================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              Azure SRE Demo - Chaos Scenario Runner                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Handle 'list' scenario
if ($Scenario -eq 'list') {
    Show-ScenarioList
    exit 0
}

# Handle 'all-chaos' - run all 6 Chaos Studio experiments
if ($Scenario -eq 'all-chaos') {
    if ($Action -eq 'status') {
        Write-Host "📊 Chaos Studio Experiment Status:" -ForegroundColor Cyan
        Write-Host ""
        foreach ($name in ($chaosScenarios.Keys | Sort-Object)) {
            Get-ChaosExperimentStatus -Name $name -Config $chaosScenarios[$name]
        }
        Write-Host ""
        exit 0
    }

    if ($Action -eq 'stop') {
        Write-Host "🛑 Cancelling all Chaos Studio experiments..." -ForegroundColor Yellow
        Write-Host ""
        foreach ($name in ($chaosScenarios.Keys | Sort-Object)) {
            Stop-ChaosExperiment -Name $name -Config $chaosScenarios[$name]
        }
        Write-Host ""
        Write-Host "✅ All experiments cancelled." -ForegroundColor Green
        exit 0
    }

    Write-Host "🚀 Starting all 6 Chaos Studio experiments sequentially..." -ForegroundColor Yellow
    Write-Host "   Each experiment runs for 10 minutes." -ForegroundColor Gray
    Write-Host ""

    foreach ($name in ($chaosScenarios.Keys | Sort-Object)) {
        Start-ChaosExperiment -Name $name -Config $chaosScenarios[$name]
        Write-Host "   ───────────────────────────────────────────────" -ForegroundColor DarkGray
    }

    Write-Host "✅ All Chaos Studio experiments started." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Handle individual scenarios
if ($chaosScenarios.ContainsKey($Scenario)) {
    $config = $chaosScenarios[$Scenario]

    switch ($Action) {
        'start' { Start-ChaosExperiment -Name $Scenario -Config $config }
        'stop' { Stop-ChaosExperiment -Name $Scenario -Config $config }
        'status' { Get-ChaosExperimentStatus -Name $Scenario -Config $config }
    }
}
elseif ($kubectlScenarios.ContainsKey($Scenario)) {
    $config = $kubectlScenarios[$Scenario]

    switch ($Action) {
        'start' { Start-KubectlScenario -Name $Scenario -Config $config }
        'stop' { Stop-KubectlScenario -Name $Scenario -Config $config }
        'status' {
            Write-Host "  📊 kubectl scenarios don't have a status API." -ForegroundColor Gray
            Write-Host "     Check pod status: kubectl get pods -n pets" -ForegroundColor Gray
        }
    }
}

Write-Host ""
