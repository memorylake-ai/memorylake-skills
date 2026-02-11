---
name: memorylake
description: >
  Search, retrieve, and analyze data from a MemoryLake Streamable HTTP MCP Server — the memory
  layer for AI Agents that provides intelligent unstructured file content retrieval and data analysis.
  Access the server directly via HTTP/curl (not via pre-configured MCP tools).
  Use this skill when the user wants to: (1) search for information across uploaded files in MemoryLake,
  (2) retrieve specific documents or data from MemoryLake, (3) analyze data stored in MemoryLake
  using Python code execution, (4) explore what's available in a MemoryLake memorylake,
  (5) ask natural-language questions about their files, or (6) perform data analysis, aggregation,
  or comparison across MemoryLake documents. Trigger phrases include: "search my files",
  "find in memorylake", "analyze my data", "what files do I have", "look up", "summarize my documents",
  "compare data across files", "run analysis on my data".
---

# MemoryLake Skill

MemoryLake is the memory layer for AI Agents. It ingests unstructured files (Excel, PDF, text, etc.),
chunks and indexes them, and exposes them through a Streamable HTTP MCP Server for intelligent
retrieval and analysis.

This repo also includes an up-to-date OpenAPI spec for MemoryLake's Project/Drive APIs (see
`references/memorylake-openapi.json`).

## Prerequisites

### 1) Get a MemoryLake API key

1. Go to https://app.memorylake.ai/ and apply for a MemoryLake API key.
2. Use the REST API base URL:

```
https://app.memorylake.ai/openapi/memorylake
```

3. Authenticate requests with:

- `Authorization: Bearer <your API key>`
- `X-User-ID: <your user id>` (required for most endpoints)

### 2) (Later) Get a Streamable HTTP MCP secret

After you create a project, you can create a project API key that becomes a Streamable HTTP MCP secret:

```
https://ai.data.cloud/memorylake/mcp/v1?apikey=<secret>
```

## Client Scripts

### REST API client (projects, uploads, documents)

Use `scripts/memorylake_rest_client.sh` to:
- Create/list projects
- Create a project API key (MCP secret)
- Upload documents (multipart)
- Quick-add documents to a project
- Poll project documents until `status=okay`

It expects env vars:

```bash
export MEMORYLAKE_BASE_URL="https://app.memorylake.ai/openapi/memorylake"
export MEMORYLAKE_API_KEY="<your api key>"
export MEMORYLAKE_USER_ID="<your user id>"
```

### MCP client (search + fetch + code runner)

Use `scripts/memorylake_client.sh` for Streamable HTTP MCP interactions. It handles MCP session
initialization, JSON-RPC protocol, and SSE response parsing.

```bash
# Initialize a session (required before any tool calls)
SESSION=$(./scripts/memorylake_client.sh "$MCP_URL" init)

# Call any tool
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" <tool_name> ['<json_arguments>']
```

**Session management:** Sessions can expire if idle. If a call returns empty or an error,
re-initialize with `init` before retrying. Minimize delay between init and the first tool call.

## Available Tools

| Tool | Arguments | Purpose |
|------|-----------|---------|
| `get_memorylake_metadata` | *(none)* | Explore memorylake: file counts by type, sample memories |
| `search_memory` | `{"parsed_query":{...}}` | Semantic + keyword search across all files |
| `fetch_memory` | `{"memory_ids":["id1",...]}` | Detailed metadata for specific memories |
| `create_memory_code_runner` | *(none)* | Create a Python executor, returns `executor_id` |
| `run_memory_code` | `{"executor_id":"...","code":"..."}` | Execute Python code against data |

See:
- [references/mcp-tools.md](references/mcp-tools.md) for detailed MCP tool parameters and response formats.
- `references/memorylake-openapi.json` for the REST API surface (Projects/Drives/Connectors/etc.).

**Note:** The REST API requires `X-User-ID` on most endpoints (per OpenAPI spec).

## Typical End-to-End Workflow (REST → MCP)

Follow this flow to create a project, ingest documents, then query/analyze them via MCP.

### 1) Create a project (REST)

```bash
./scripts/memorylake_rest_client.sh projects:create '{
  "name": "My Research Project",
  "description": "Optional description"
}'
```

### 2) List projects (REST)

```bash
./scripts/memorylake_rest_client.sh projects:list
```

### 3) Create a project API key (this becomes the MCP secret) (REST)

```bash
./scripts/memorylake_rest_client.sh projects:create-apikey <project_id> '{"description":"mcp"}'
```

Save the returned `secret` locally. That secret is used like:

```
https://ai.data.cloud/memorylake/mcp/v1?apikey=<secret>
```

### 4) Upload a document (multipart) (REST)

```bash
# 1) Ask server for presigned part upload URLs (file_size in bytes)
./scripts/memorylake_rest_client.sh upload:create-multipart '{"file_size": 123456}' > upload.json

# 2) Upload parts to presigned URLs, then complete multipart
./scripts/memorylake_rest_client.sh upload:complete-multipart upload.json /path/to/file.pdf
```

You will end up with an `object_key` (from create-multipart), which is the server-side key for the uploaded file.

### 5) Add the uploaded document into the project (quick-add) (REST)

```bash
./scripts/memorylake_rest_client.sh projects:quick-add <project_id> '{
  "object_key": "<object_key>",
  "file_name": "file.pdf"
}'
```

If you have multiple documents, upload + quick-add **one by one**.

### 6) Poll project documents until processed (REST)

Check:

```bash
./scripts/memorylake_rest_client.sh projects:list-documents <project_id>
```

Document `status` values: `error`, `okay`, `running`, `pending`.

Recommended polling interval: **5s** until all documents are `okay`.

### 7) Use Streamable HTTP MCP to search/retrieve/analyze

```bash
MCP_URL="https://ai.data.cloud/memorylake/mcp/v1?apikey=<secret>"
SESSION=$(./scripts/memorylake_client.sh "$MCP_URL" init)

./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" get_memorylake_metadata
```

Then do search/fetch/code-runner as usual.

---

## MCP Workflow (inside the MCP phase)

### 1. Initialize session and orient

```bash
MCP_URL="<user-provided-url>"
SESSION=$(./scripts/memorylake_client.sh "$MCP_URL" init)
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" get_memorylake_metadata
```

### 2. Search for relevant content

Build a structured query with both BM25 keywords and a semantic dense query:

```bash
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" search_memory '{
  "parsed_query": {
    "bm25_cleaned_query": "recruitment positions master degree",
    "named_entities": [],
    "bm25_keywords": ["recruitment", "positions", "master", "degree"],
    "bm25_boost_keywords": ["master", "recruitment"],
    "rewritten_query_for_dense_model": "Job positions requiring a master degree or higher"
  }
}'
```

**Query construction tips:**
- Extract all named entities into `named_entities` and `bm25_keywords`
- Clean BM25 query: remove stop words, punctuation, normalize spaces
- Dense query: rewrite to capture intent, expand with synonyms
- Boost keywords: 3-5 most distinctive terms

### 3. Fetch memory details

```bash
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" fetch_memory '{"memory_ids":["ds-abc123"]}'
```

### 4. Analyze with code execution

```bash
# Create executor (once per session)
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" create_memory_code_runner

# Run code (use executor_id from above)
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" run_memory_code '{
  "executor_id": "executor-...",
  "code": "import pandas as pd\npath = get_memory_path(\"ds-abc\", \"file.xlsx\")\ndf = pd.read_excel(path)\nprint(df.describe())"
}'
```

**Available packages:** pandas, numpy, openpyxl, xlrd, scipy, scikit-learn, xgboost.
Always `print()` results — not an interactive environment. `matplotlib` is NOT available.

## Parsing Responses

The script outputs JSON-RPC result lines. Extract data with:

```bash
# Parse with python
RESULT=$(./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" get_memorylake_metadata)
echo "$RESULT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['result']['structuredContent'], indent=2))"
```

The `structuredContent` field contains the typed response object. The `content[0].text` field
contains the same data as a JSON string.

## Best Practices

- **Start broad, then narrow.** Use `get_memorylake_metadata` first, then targeted searches.
- **Reuse sessions.** Initialize once, call multiple tools. Re-init only if session expires.
- **Handle multilingual content.** Write search queries in the language matching the data.
- **Combine search + code.** Search to find files, then analyze with code execution.
- **Reuse executor_id.** Create one code runner and reuse for all code calls to maintain state.
