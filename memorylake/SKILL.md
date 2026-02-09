---
name: memorylake
description: >
  Search, retrieve, and analyze data from a MemoryLake MCP Server — the memory layer for AI Agents
  that provides intelligent unstructured file content retrieval and data analysis.
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
chunks and indexes them, and exposes them through an MCP Server for intelligent retrieval and analysis.

## MCP Tools Overview

MemoryLake provides these MCP tools. See [references/mcp-tools.md](references/mcp-tools.md) for detailed usage.

| Tool | Purpose |
|------|---------|
| `get_memorylake_metadata` | Explore memorylake structure: file counts by type, sample memories |
| `search_memory` | Semantic + keyword search across all files |
| `fetch_memory` | Get detailed metadata for specific memory IDs |
| `create_memory_code_runner` | Create a Python executor for stateful code execution |
| `run_memory_code` | Execute Python code against MemoryLake data |

## Workflow

### 1. Orient: Understand the memorylake

Before searching, call `get_memorylake_metadata` to understand what's available — total files,
file types, and sample memories with sheet names and summaries.

### 2. Search: Find relevant content

Use `search_memory` with a structured query. Build high-quality queries by:

- Extracting all named entities into `named_entities` and `bm25_keywords`
- Writing a clean BM25 query (remove stop words, punctuation, normalize)
- Writing a semantic dense query that captures intent and adds synonyms
- Selecting 3-5 boost keywords for the most distinctive terms

**Query construction example** for "What recruitment positions require a master's degree?":

```json
{
  "bm25_cleaned_query": "recruitment positions master degree requirement",
  "named_entities": [],
  "bm25_keywords": ["recruitment", "positions", "master", "degree", "requirement", "hiring"],
  "bm25_boost_keywords": ["master", "recruitment", "degree"],
  "rewritten_query_for_dense_model": "Job positions and recruitment plans that require a master's degree or higher education qualification"
}
```

### 3. Deep-dive: Fetch memory details

After search results identify relevant memories, call `fetch_memory` with their IDs to get:
- File metadata (name, type, author)
- Excel-specific details (worksheet names)
- Content statistics (chunks, tables, figures)

### 4. Analyze: Run code against the data

For quantitative analysis, aggregation, or data transformation:

1. Call `create_memory_code_runner` once to get an `executor_id`
2. Call `run_memory_code` with that `executor_id` and Python code
3. Use `get_memory_path(memory_id, memory_name)` inside code to access files locally
4. State persists across calls with the same `executor_id` — build analysis incrementally

**Available packages:** pandas, numpy, openpyxl, xlrd, scipy, scikit-learn, xgboost.

**Code execution pattern:**

```python
import pandas as pd

path = get_memory_path("ds-abc123", "data.xlsx")
df = pd.read_excel(path, sheet_name="Sheet1")
print(df.describe())
print(df.columns.tolist())
```

Always `print()` results explicitly — this is not an interactive environment.

## Best Practices

- **Start broad, then narrow.** Use `get_memorylake_metadata` first, then targeted searches.
- **Iterate searches.** If initial results are insufficient, refine keywords and semantic queries.
- **Combine search + code.** Search to find relevant files, then use code execution to analyze their contents in detail.
- **Reuse executor_id.** Create one code runner per session and reuse it for all code executions to maintain state (loaded DataFrames, variables, etc.).
- **Handle multilingual content.** MemoryLake files may contain Chinese, English, or mixed content. Write search queries in the language matching the data.
- **Present results clearly.** Summarize findings in natural language. For data analysis, show key numbers and insights rather than raw output.
