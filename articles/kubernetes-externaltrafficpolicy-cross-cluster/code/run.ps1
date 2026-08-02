[CmdletBinding()]
param(
    [switch]$KeepClusters
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$codeDir = Split-Path -Parent $PSCommandPath
$clusterA = 'cross-a'
$clusterB = 'cross-b'
$contextA = "kind-$clusterA"
$contextB = "kind-$clusterB"
$resultDir = Join-Path $codeDir 'results'
$resultFile = Join-Path $resultDir 'run-output.txt'

function Invoke-Kubectl {
    param([string]$Context, [string[]]$Arguments)
    & kubectl --context $Context @Arguments
    if ($LASTEXITCODE -ne 0) { throw "kubectl failed for context $Context" }
}

function Write-Result {
    param([string[]]$Text)

    $Text | Add-Content -Path $resultFile -Encoding utf8
    Write-Host ($Text -join [Environment]::NewLine)
}

function Test-PaymentApi {
    param([string]$Phase, [string]$Address)

    $command = "wget -T 3 -qO- http://$Address/"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & kubectl --context $contextA exec checkout-client -- sh -c $command 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    Write-Result "[$Phase] exit=$exitCode output=$($output -join ' ')"
    return $exitCode
}

New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
Set-Content -Path $resultFile -Value "Cross-cluster externalTrafficPolicy experiment`n" -Encoding utf8

try {
    try { & kind delete cluster --name $clusterA 2>&1 | Out-Null } catch { }
    try { & kind delete cluster --name $clusterB 2>&1 | Out-Null } catch { }

    & kind create cluster --config (Join-Path $codeDir 'cluster-a.yaml') --wait 90s
    if ($LASTEXITCODE -ne 0) { throw 'Could not create Cluster A.' }
    & kind create cluster --config (Join-Path $codeDir 'cluster-b.yaml') --wait 90s
    if ($LASTEXITCODE -ne 0) { throw 'Could not create Cluster B.' }

    Invoke-Kubectl $contextB @('label', 'node', 'cross-b-worker', 'lab.example/role=api', '--overwrite')
    Invoke-Kubectl $contextB @('apply', '-f', (Join-Path $codeDir 'payment-api.yaml'))
    Invoke-Kubectl $contextB @('rollout', 'status', 'deployment/payment-api', '--timeout=90s')
    Invoke-Kubectl $contextA @('apply', '-f', (Join-Path $codeDir 'client.yaml'))
    Invoke-Kubectl $contextA @('wait', '--for=condition=Ready', 'pod/checkout-client', '--timeout=90s')

    $controlPlaneIp = (& docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' cross-b-control-plane).Trim()
    if ([string]::IsNullOrWhiteSpace($controlPlaneIp)) { throw 'Could not find Cluster B control-plane IP.' }
    $address = "${controlPlaneIp}:30080"

    Write-Result "Cluster B control-plane=$controlPlaneIp; payment endpoint=$address"
    $pods = Invoke-Kubectl $contextB @('get', 'pods', '-o', 'wide')
    Write-Result $pods
    $endpointSlices = Invoke-Kubectl $contextB @('get', 'endpointslice', '-l', 'kubernetes.io/service-name=payment-api', '-o', 'wide')
    Write-Result $endpointSlices

    $clusterExit = Test-PaymentApi 'externalTrafficPolicy=Cluster' $address
    if ($clusterExit -ne 0) { throw 'Expected Cluster policy to reach the worker endpoint.' }

    Invoke-Kubectl $contextB @('apply', '-f', (Join-Path $codeDir 'payment-api-local.yaml'))
    Start-Sleep -Seconds 2
    $localExit = Test-PaymentApi 'externalTrafficPolicy=Local' $address
    if ($localExit -eq 0) { throw 'Expected Local policy to reject traffic received by a node without a local endpoint.' }

    Write-Result 'PASS: Cluster forwards to the remote worker; Local rejects traffic on the endpoint-less control-plane node.'
}
finally {
    if (-not $KeepClusters) {
        try { & kind delete cluster --name $clusterA 2>&1 | Out-Null } catch { }
        try { & kind delete cluster --name $clusterB 2>&1 | Out-Null } catch { }
    }
}
