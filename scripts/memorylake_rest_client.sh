#!/usr/bin/env bash
set -euo pipefail

# memorylake_rest_client.sh
# Lightweight REST client for MemoryLake API (projects, uploads, documents).
#
# Auth:
#   - Authorization: Bearer <MEMORYLAKE_API_KEY>
#   - X-User-ID: <user id> (required for most endpoints)
# Base URL (per JJ):
#   https://app.memorylake.ai/openapi/memorylake
#
# Examples:
#   export MEMORYLAKE_BASE_URL="https://app.memorylake.ai/openapi/memorylake"
#   export MEMORYLAKE_API_KEY="sk-..."
#   export MEMORYLAKE_USER_ID="12345"
#
#   ./scripts/memorylake_rest_client.sh projects:create '{"name":"My Project","description":"..."}'
#   ./scripts/memorylake_rest_client.sh projects:list
#   ./scripts/memorylake_rest_client.sh projects:create-apikey proj-xxxx '{"description":"mcp"}'
#
#   ./scripts/memorylake_rest_client.sh upload:create-multipart '{"file_size":123456}'
#   ./scripts/memorylake_rest_client.sh upload:upload-parts <upload_json_path> /path/to/file
#   ./scripts/memorylake_rest_client.sh upload:complete-multipart <upload_json_path> /path/to/file
#
#   ./scripts/memorylake_rest_client.sh projects:quick-add proj-xxxx '{"object_key":"...","file_name":"doc.pdf"}'
#   ./scripts/memorylake_rest_client.sh projects:list-documents proj-xxxx

cmd="${1:-}"
shift || true

base_url="${MEMORYLAKE_BASE_URL:-https://app.memorylake.ai/openapi/memorylake}"
api_key="${MEMORYLAKE_API_KEY:-}"
user_id="${MEMORYLAKE_USER_ID:-}"

if [[ -z "${cmd}" ]]; then
  echo "Usage: $0 <command> [args...]" >&2
  exit 2
fi

json_or_empty() {
  if [[ $# -eq 0 ]]; then
    echo "{}"
  else
    echo "$1"
  fi
}

require_env() {
  local name="$1"
  local val="$2"
  if [[ -z "$val" ]]; then
    echo "Missing env: $name" >&2
    exit 2
  fi
}

api() {
  local method="$1"; shift
  local path="$1"; shift
  local body="${1:-}"

  require_env MEMORYLAKE_API_KEY "$api_key"

  # X-User-ID is required on most non-admin endpoints.
  local headers=(-H "Authorization: Bearer ${api_key}" -H "Content-Type: application/json")
  if [[ -n "$user_id" ]]; then
    headers+=( -H "X-User-ID: ${user_id}" )
  fi

  local url="${base_url%/}${path}"

  if [[ "$method" == "GET" ]]; then
    curl -fsS "$url" "${headers[@]}"
  else
    curl -fsS -X "$method" "$url" "${headers[@]}" --data "$body"
  fi
}

# Upload helpers (pre-signed URLs)
upload_parts() {
  local upload_json_path="$1"
  local file_path="$2"

  python3 - "$upload_json_path" "$file_path" <<'PY'
import json,sys,hashlib
from pathlib import Path

upload = json.load(open(sys.argv[1],'r',encoding='utf-8'))
file_path = Path(sys.argv[2])

# Support both wrapped and unwrapped schemas.
# Expected upload.data.part_items = [{number,size,upload_url}, ...]
obj = upload.get('data') or upload
parts = obj.get('part_items') or obj.get('partItems') or []
if not parts:
    raise SystemExit('No part_items found in upload json')

# Upload each part with PUT to presigned URL. Compute etag by reading response header.
import subprocess

with file_path.open('rb') as f:
    for p in parts:
        number = p.get('number')
        size = int(p.get('size'))
        url = p.get('upload_url') or p.get('uploadUrl')
        if not (number and size and url):
            raise SystemExit(f'Invalid part item: {p}')
        chunk = f.read(size)
        if len(chunk) != size:
            raise SystemExit(f'Unexpected EOF reading part {number}: got {len(chunk)} bytes expected {size}')
        # Use curl to upload the part; capture ETag
        proc = subprocess.run([
            'curl','-fsS','-X','PUT',
            '-H','Content-Type: application/octet-stream',
            '--data-binary','@-',
            '-D','-',
            url
        ], input=chunk, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            sys.stderr.write(proc.stderr.decode('utf-8','ignore'))
            raise SystemExit(f'Failed uploading part {number}')
        headers = proc.stdout.decode('utf-8','ignore').splitlines()
        etag = None
        for line in headers:
            if line.lower().startswith('etag:'):
                etag = line.split(':',1)[1].strip()
                break
        if not etag:
            raise SystemExit(f'No ETag returned for part {number}')
        print(json.dumps({'number': int(number), 'etag': etag}))
PY
}

complete_multipart() {
  local upload_json_path="$1"
  local file_path="$2"

  # Upload parts and collect etags
  local etags_json
  etags_json=$(upload_parts "$upload_json_path" "$file_path" | python3 - <<'PY'
import sys,json
items=[json.loads(l) for l in sys.stdin if l.strip()]
print(json.dumps(items))
PY
)

  python3 - "$upload_json_path" <<PY
import json,sys
upload=json.load(open(sys.argv[1],'r',encoding='utf-8'))
obj=upload.get('data') or upload
print(json.dumps({'upload_id': obj.get('upload_id') or obj.get('uploadId'), 'object_key': obj.get('object_key') or obj.get('objectKey')}))
PY

  local ids
  ids=$(python3 - "$upload_json_path" <<'PY'
import json,sys
upload=json.load(open(sys.argv[1],'r',encoding='utf-8'))
obj=upload.get('data') or upload
print((obj.get('upload_id') or obj.get('uploadId') or '') + '\n' + (obj.get('object_key') or obj.get('objectKey') or ''))
PY
)
  local upload_id object_key
  upload_id=$(echo "$ids" | sed -n '1p')
  object_key=$(echo "$ids" | sed -n '2p')

  if [[ -z "$upload_id" || -z "$object_key" ]]; then
    echo "Missing upload_id/object_key in upload json" >&2
    exit 2
  fi

  local payload
  payload=$(python3 - "$upload_id" "$object_key" "$etags_json" <<'PY'
import json,sys
upload_id=sys.argv[1]
object_key=sys.argv[2]
etags=json.loads(sys.argv[3])
print(json.dumps({'upload_id': upload_id, 'object_key': object_key, 'part_eTags': etags}))
PY
)

  api POST /api/v1/upload/complete-multipart "$payload"
}

case "$cmd" in
  projects:create)
    body=$(json_or_empty "${1:-}")
    api POST /api/v1/projects "$body" ;;
  projects:list)
    api GET /api/v1/projects ;;
  projects:get)
    id="$1"; api GET "/api/v1/projects/${id}" ;;
  projects:update)
    id="$1"; body=$(json_or_empty "${2:-}"); api PUT "/api/v1/projects/${id}" "$body" ;;
  projects:delete)
    id="$1"; api DELETE "/api/v1/projects/${id}" "{}" ;;

  projects:create-apikey)
    id="$1"; body=$(json_or_empty "${2:-}"); api POST "/api/v1/projects/${id}/apikeys" "$body" ;;
  projects:list-documents)
    id="$1"; api GET "/api/v1/projects/${id}/documents" ;;
  projects:quick-add)
    id="$1"; body=$(json_or_empty "${2:-}"); api POST "/api/v1/projects/${id}/documents/quick-add" "$body" ;;

  upload:create-multipart)
    body=$(json_or_empty "${1:-}"); api POST /api/v1/upload/create-multipart "$body" ;;

  upload:upload-parts)
    upload_json_path="$1"; file_path="$2"; upload_parts "$upload_json_path" "$file_path" ;;

  upload:complete-multipart)
    upload_json_path="$1"; file_path="$2"; complete_multipart "$upload_json_path" "$file_path" ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 2
    ;;
esac
