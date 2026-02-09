# MemoryLake MCP Tools Reference

## get_memorylake_metadata

Returns an overview of the memorylake including total file counts by type and sample memories.

**Parameters:** None

**Response fields:**
- `total_files` — Total number of files in the memorylake
- `total_excel_files`, `total_pdf_files`, `total_txt_files` — Counts by type
- `sample_memories[]` — Array of sample memory objects with:
  - `id` — Memory ID (use with `fetch_memory` and `get_memory_path()`)
  - `name` — Original filename
  - `type` — File type (e.g., `excel_file`, `pdf_file`)
  - `num_chunks`, `num_figures`, `num_tables` — Content statistics
  - `sheet_names` — (Excel only) List of worksheet names

**When to use:** At the start of a session, or when the user asks "what files do I have?" or "what's in my memorylake?"

---

## search_memory

Performs semantic and keyword search across all indexed file content.

**Parameters:** A `parsed_query` object with these required fields:

| Field | Type | Description |
|-------|------|-------------|
| `bm25_cleaned_query` | string | Query optimized for BM25 exact-term matching. Remove stop words, punctuation, normalize spaces. Keep technical terms and proper nouns intact. |
| `named_entities` | string[] | All detected named entities (people, organizations, locations, products). Critical for retrieval. |
| `bm25_keywords` | string[] | Important keywords for BM25 search. Must include all named entities. |
| `bm25_boost_keywords` | string[] | 3-5 boost keywords to increase ranking. Include named entities and distinctive terms. |
| `rewritten_query_for_dense_model` | string | Semantically rewritten query for vector retrieval. Expand with synonyms, capture intent. |

**Response fields:**
- `results[]` — Array of matching memories, each with:
  - `id` — Memory ID
  - `name` — Original filename
  - `summary` — AI-generated summary of the matching content
- `n` — Total number of results

**Query optimization tips:**
- For Chinese content, remove stop words: 的, 了, 吗, 呢, 是, 在, 有, 和, 与, 或
- Remove question words: 什么, 怎么, 如何, 为什么, 哪里, 哪个
- Keep hyphens, underscores, dots in technical terms
- Named entities are the highest-signal terms — always include them in keywords and boost

---

## fetch_memory

Retrieves detailed metadata for one or more memories by ID.

**Parameters:**
- `memory_ids` — string[] — List of memory IDs to fetch

**Response:** Dictionary mapping memory_id to metadata including name, type, description, and type-specific details (e.g., sheet names for Excel files).

**When to use:** After `search_memory` returns results, to get more detail about specific files before deciding whether to analyze them with code.

---

## create_memory_code_runner

Creates a new Python execution environment and returns an `executor_id`.

**Parameters:** None

**Returns:** An `executor_id` string (e.g., `executor-6fd400a155...`)

**Important:** Create one executor per session. Reuse the same `executor_id` for all subsequent `run_memory_code` calls to maintain state (loaded DataFrames, variables, imports).

---

## run_memory_code

Executes Python 3 code in the sandboxed environment.

**Parameters:**
- `executor_id` — string (required) — From `create_memory_code_runner`
- `code` — string (required) — Complete, standalone Python code

**Available packages:** pandas, numpy, openpyxl, xlrd, scipy, scikit-learn, xgboost

**Auto-injected function:**
```python
def get_memory_path(memory_id: str, memory_name: str) -> pathlib.Path
```
Returns a local file path to access the memory file for analysis.

**Key rules:**
- Always `print()` results — not interactive mode
- `matplotlib` is NOT available — do not attempt to render images
- Code must be complete and standalone per call (imports, etc.)
- State persists across calls with the same `executor_id`

**Common patterns:**

Reading an Excel file:
```python
import pandas as pd
path = get_memory_path("ds-abc123", "filename.xlsx")
df = pd.read_excel(path, sheet_name="Sheet1")
print(df.head())
print(df.shape)
```

Reading all sheets:
```python
import pandas as pd
path = get_memory_path("ds-abc123", "filename.xlsx")
sheets = pd.read_excel(path, sheet_name=None)
for name, df in sheets.items():
    print(f"\n=== {name} ===")
    print(df.head())
```

Aggregation across files:
```python
import pandas as pd
files = [
    ("ds-id1", "file1.xlsx"),
    ("ds-id2", "file2.xlsx"),
]
all_data = []
for mid, mname in files:
    path = get_memory_path(mid, mname)
    df = pd.read_excel(path)
    all_data.append(df)
combined = pd.concat(all_data, ignore_index=True)
print(combined.describe())
```
