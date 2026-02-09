#!/usr/bin/env bash
# MemoryLake MCP HTTP Client
# Accesses MemoryLake Streamable HTTP MCP Server directly via curl.
#
# Usage:
#   memorylake_client.sh <mcp_url> init                         — Initialize session, prints SESSION_ID
#   memorylake_client.sh <mcp_url> <session_id> <tool> [json]   — Call a tool, prints result JSON
#
# Examples:
#   SESSION=$(./memorylake_client.sh "https://...?apikey=sk-..." init)
#   ./memorylake_client.sh "https://...?apikey=sk-..." "$SESSION" get_memorylake_metadata
#   ./memorylake_client.sh "https://...?apikey=sk-..." "$SESSION" search_memory '{"parsed_query":{...}}'
#   ./memorylake_client.sh "https://...?apikey=sk-..." "$SESSION" fetch_memory '{"memory_ids":["ds-abc"]}'
#   ./memorylake_client.sh "https://...?apikey=sk-..." "$SESSION" create_memory_code_runner
#   ./memorylake_client.sh "https://...?apikey=sk-..." "$SESSION" run_memory_code '{"executor_id":"...","code":"..."}'

set -uo pipefail

MCP_URL="$1"
ACTION="$2"

if [ "$ACTION" = "init" ]; then
  RESPONSE=$(curl -s --max-time 15 -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -D /tmp/memorylake_headers.txt \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"memorylake-skill","version":"1.0"}}}' 2>&1)

  SESSION_ID=$(grep -i 'mcp-session-id' /tmp/memorylake_headers.txt 2>/dev/null | tr -d '\r' | awk '{print $2}')
  if [ -z "$SESSION_ID" ]; then
    echo "ERROR: Failed to get session ID. Response: $RESPONSE" >&2
    exit 1
  fi
  echo "$SESSION_ID"
else
  SESSION_ID="$ACTION"
  TOOL_NAME="$3"
  ARGUMENTS="${4:-{}}"

  RESPONSE=$(curl -s --max-time 120 -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL_NAME\",\"arguments\":$ARGUMENTS}}" 2>&1)

  # Extract the final result JSON from SSE stream (last data line containing "id":2)
  RESULT=$(echo "$RESPONSE" | grep '^data: ' | grep '"id":2' | tail -1 | sed 's/^data: //')
  if [ -z "$RESULT" ]; then
    echo "ERROR: No result received. Raw response:" >&2
    echo "$RESPONSE" >&2
    exit 1
  fi
  echo "$RESULT"
fi
