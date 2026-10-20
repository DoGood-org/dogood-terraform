# Opens an SSM port-forwarding tunnel to the Grafana task: http://localhost:<local port>
# Usage: scripts/grafana-tunnel.ps1 [-Stage mvp] [-LocalPort 3000]
# Requires the AWS CLI and the Session Manager plugin.
param(
  [string]$Stage = "mvp",
  [int]$LocalPort = 3000
)

$ErrorActionPreference = "Stop"

$Cluster = "$Stage-cluster"
$Service = "grafana"

$TaskArn = aws ecs list-tasks --cluster $Cluster --service-name $Service `
  --desired-status RUNNING --query "taskArns[0]" --output text
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ([string]::IsNullOrWhiteSpace($TaskArn) -or $TaskArn -eq "None") {
  Write-Error "No running $Service task in $Cluster"
  exit 1
}

$RuntimeId = aws ecs describe-tasks --cluster $Cluster --tasks $TaskArn `
  --query "tasks[0].containers[?name=='grafana'].runtimeId | [0]" --output text
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$TaskId = ($TaskArn -split "/")[-1]

Write-Host "Grafana: http://localhost:$LocalPort (admin password: secret /dogood/$Stage/grafana)"

# Shorthand syntax instead of JSON: Windows PowerShell 5.1 strips inner quotes from native arguments.
aws ssm start-session `
  --target "ecs:${Cluster}_${TaskId}_${RuntimeId}" `
  --document-name AWS-StartPortForwardingSession `
  --parameters "portNumber=3000,localPortNumber=$LocalPort"
exit $LASTEXITCODE
