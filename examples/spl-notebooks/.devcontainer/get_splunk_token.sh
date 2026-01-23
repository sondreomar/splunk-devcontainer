#!/bin/bash
until curl -sk https://localhost:8089 -u admin:$SPLUNK_PASSWORD --max-time 5 >/dev/null; do
  echo "Waiting for Splunk to be available..."
  sleep 5
done

echo "Requesting Splunk auth token..."
token=""
while [ -z "$token" ] || [ "$token" = "null" ]; do
  response=$(
    curl -sk https://localhost:8089/services/authorization/tokens \
      -H "Content-Type: application/json" \
      -u admin:$SPLUNK_PASSWORD \
      -d name=admin \
      -d audience=vscode \
      -d output_mode=json
  )
  token=$(echo "$response" | jq -r '.entry[0].content.token' 2>/dev/null)
  if [ -z "$token" ] || [ "$token" = "null" ]; then
    echo "Token not available yet. Retrying in 5s..."
    sleep 5
  fi
done

echo "Token acquired."

mkdir -p .vscode
cat > .vscode/settings.json << EOF
{
  "splunk.commands.token": "$token"
}
EOF
