# MemoryLake MCP Tools Reference

## HTTP Protocol

MemoryLake uses the MCP Streamable HTTP protocol:
- **Transport:** HTTPS POST with SSE (Server-Sent Events) responses
- **Session:** Initialize first to get a `Mcp-Session-Id`, then pass it in all subsequent requests
- **Format:** JSON-RPC 2.0 over SSE — responses come as `event: message` / `data: {...}` lines
- **Result extraction:** Filter for `data:` lines containing the request `"id"`, take the last one

The `scripts/memorylake_client.sh` handles all of this automatically.

---

## get_memorylake_metadata

Returns an overview of the memorylake including total file counts by type and sample memories.

**Arguments:** `{}` (none)

**Response `structuredContent.result` fields:**
- `total_files` — Total number of files
- `total_excel_files`, `total_pdf_files`, `total_txt_files` — Counts by type
- `sample_memories[]` — Array of sample memory objects:
  - `id` — Memory ID (use with `fetch_memory` and `get_memory_path()`)
  - `name` — Original filename
  - `type` — `excel_file`, `pdf_file`, or `txt_file`
  - `num_chunks`, `num_figures`, `num_tables` — Content statistics
  - `sheet_names` — (Excel only) List of worksheet names

**When to use:** At the start of a session, or when the user asks "what files do I have?"

---

## search_memory

Performs hybrid semantic + keyword search across all indexed file content.

**Arguments:** `{"parsed_query": {...}}` with these required fields:

| Field | Type | Description |
|-------|------|-------------|
| `bm25_cleaned_query` | string | Query for BM25 matching. Remove stop words, punctuation, normalize spaces. Keep technical terms intact. |
| `named_entities` | string[] | All named entities (people, orgs, locations, products). Critical for retrieval. |
| `bm25_keywords` | string[] | Important keywords. Must include all named entities. |
| `bm25_boost_keywords` | string[] | 3-5 boost keywords. Include named entities and distinctive terms. |
| `rewritten_query_for_dense_model` | string | Semantic query for vector retrieval. Expand with synonyms, capture intent. |

**Response `structuredContent.result` fields:**
- `results[]` — Matching memories, each with `id`, `name`, `summary`
- `n` — Total result count

**Query tips:**
- Chinese stop words to remove: 的, 了, 吗, 呢, 是, 在, 有, 和, 与, 或
- Chinese question words to remove: 什么, 怎么, 如何, 为什么, 哪里, 哪个
- Keep hyphens, underscores, dots in technical terms
- Named entities are highest-signal — always boost them

---

## fetch_memory

Retrieves detailed metadata for one or more memories by ID.

**Arguments:** `{"memory_ids": ["ds-id1", "ds-id2"]}`

**Response `structuredContent` fields:** Dictionary mapping memory_id to metadata:
- `id`, `name`, `source_type` — Basic info
- `summary` — AI-generated summary
- `presigned_url` — Direct download URL (may be null)

---

## create_memory_code_runner

Creates a Python execution environment. Returns an `executor_id`.

**Arguments:** `{}` (none)

**Response:** `{"result": {"executor_id": "executor-..."}}`

Create one per session. Reuse for all `run_memory_code` calls.

---

## run_memory_code

Executes Python 3 code in a sandboxed environment.

**Arguments:**
- `executor_id` — string (from `create_memory_code_runner`)
- `code` — string (complete Python code)

**Available packages:** pandas, numpy, openpyxl, xlrd, scipy, scikit-learn, xgboost

**Auto-injected function:**
```python
def get_memory_path(memory_id: str, memory_name: str) -> pathlib.Path
```

**Key rules:**
- Always `print()` results — not interactive mode
- `matplotlib` is NOT available
- Code must be standalone per call (include imports)
- State persists across calls with the same `executor_id`

**Common patterns:**

```python
import pandas as pd
path = get_memory_path("ds-abc123", "filename.xlsx")
df = pd.read_excel(path, sheet_name="Sheet1")
print(df.head())
```
