#!/usr/bin/env bash
# Opens an SSM port-forwarding tunnel to the Grafana task: http://localhost:<local port>
# Usage: scripts/grafana-tunnel.sh [stage] [local port]
# Requires the AWS CLI and the Session Manager plugin.
set -euo pipefail

STAGE="${1:-mvp}"
LOCAL_PORT="${2:-3000}"
CLUSTER="${STAGE}-cluster"
SERVICE="grafana"

TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" \
  --desired-status RUNNING --query 'taskArns[0]' --output text)

if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
  echo "No running $SERVICE task in $CLUSTER" >&2
  exit 1
fi

RUNTIME_ID=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query "tasks[0].containers[?name=='grafana'].runtimeId | [0]" --output text)

echo "Grafana: http://localhost:${LOCAL_PORT} (admin password: secret /dogood/${STAGE}/grafana)"

aws ssm start-session \
  --target "ecs:${CLUSTER}_${TASK_ARN##*/}_${RUNTIME_ID}" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"3000\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
