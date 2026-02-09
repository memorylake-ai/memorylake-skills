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
retrieval and analysis. This skill accesses the server directly via HTTP using `curl`.

## Prerequisites

The user must provide a MemoryLake MCP Server URL with API key, e.g.:
```
https://ai.data.cloud/memorylake/mcp/v1?apikey=sk-dset-...
```

## Client Script

Use `scripts/memorylake_client.sh` for all interactions. It handles MCP session initialization,
JSON-RPC protocol, and SSE response parsing.

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

See [references/mcp-tools.md](references/mcp-tools.md) for detailed parameters and response formats.

## Workflow

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
