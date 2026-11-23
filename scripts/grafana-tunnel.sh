#!/usr/bin/env bash
set -euo pipefail

STAGE="${1:-mvp}"
LOCAL_PORT="${2:-3000}"
REMOTE_PORT="${3:-3000}"
CLUSTER="${STAGE}-monitoring"
SERVICE="monitoring"

TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" \
  --desired-status RUNNING --query 'taskArns[0]' --output text)

if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
  echo "No running $SERVICE task in $CLUSTER" >&2
  exit 1
fi

RUNTIME_ID=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query "tasks[0].containers[?name=='grafana'].runtimeId | [0]" --output text)

echo "http://localhost:${LOCAL_PORT} -> task port ${REMOTE_PORT} (Grafana admin password: secret /dogood/${STAGE}/grafana)"

aws ssm start-session \
  --target "ecs:${CLUSTER}_${TASK_ARN##*/}_${RUNTIME_ID}" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
