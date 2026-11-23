param(
  [string]$Stage = "mvp",
  [int]$LocalPort = 3000,
  [int]$RemotePort = 3000
)

$ErrorActionPreference = "Stop"

$Cluster = "$Stage-monitoring"
$Service = "monitoring"

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

Write-Host "http://localhost:$LocalPort -> task port $RemotePort (Grafana admin password: secret /dogood/$Stage/grafana)"

# Shorthand: PS 5.1 strips JSON quotes
aws ssm start-session `
  --target "ecs:${Cluster}_${TaskId}_${RuntimeId}" `
  --document-name AWS-StartPortForwardingSession `
  --parameters "portNumber=$RemotePort,localPortNumber=$LocalPort"
exit $LASTEXITCODE
