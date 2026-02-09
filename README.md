# MemoryLake Skill for Claude Code

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that enables AI agents to search, retrieve, and analyze data from a [MemoryLake](https://memorylake.ai/) server — the memory layer for AI Agents.

## What is MemoryLake?

MemoryLake ingests unstructured files (Excel, PDF, text, etc.), chunks and indexes their content, and exposes it through a [Streamable HTTP MCP Server](https://modelcontextprotocol.io/) for intelligent retrieval and data analysis. It gives AI agents long-term memory over your documents.

## What This Skill Does

This skill teaches Claude Code how to interact with any MemoryLake MCP server directly over HTTP. It provides:

- **Hybrid search** — Semantic + keyword (BM25) search across all indexed documents
- **File exploration** — Browse memorylake contents, file types, and metadata
- **Code-based analysis** — Run Python (pandas, numpy, scikit-learn, etc.) against your data server-side
- **Session management** — A bash client that handles the MCP Streamable HTTP protocol (JSON-RPC, SSE, session lifecycle)

## Project Structure

```
memorylake-skills/
├── SKILL.md                        # Skill definition with workflow and instructions
├── scripts/
│   └── memorylake_client.sh        # HTTP client for MCP Streamable HTTP protocol
├── references/
│   └── mcp-tools.md                # Detailed tool parameters and response formats
└── memorylake-skills.skill         # Packaged distributable (.zip with .skill extension)
```

## Quick Start

### 1. Install the skill

Download `memorylake-skills.skill` from [Releases](https://github.com/memorylake-ai/memorylake-skills/releases) or clone this repo, then install in Claude Code:

```
/skill install memorylake-skills.skill
```

### 2. Provide your MemoryLake URL

When using the skill, provide your MemoryLake MCP Server URL:

```
https://ai.data.cloud/memorylake/mcp/v1?apikey=sk-dset-YOUR_API_KEY
```

### 3. Ask questions about your data

Once installed, Claude Code can:

- *"What files are in my memorylake?"*
- *"Search for budget reports from 2024"*
- *"Analyze the revenue data across all uploaded spreadsheets"*
- *"Summarize the content of my PDF documents"*

## Available Tools

The skill exposes 5 MemoryLake tools via HTTP:

| Tool | Purpose |
|------|---------|
| `get_memorylake_metadata` | Explore memorylake structure and contents |
| `search_memory` | Hybrid semantic + keyword search across all files |
| `fetch_memory` | Get detailed metadata for specific files |
| `create_memory_code_runner` | Create a Python execution environment |
| `run_memory_code` | Run Python code against your data (pandas, numpy, etc.) |

## Using the Client Script Standalone

The included `scripts/memorylake_client.sh` can also be used independently:

```bash
MCP_URL="https://ai.data.cloud/memorylake/mcp/v1?apikey=sk-dset-..."

# Initialize a session
SESSION=$(./scripts/memorylake_client.sh "$MCP_URL" init)

# Explore your memorylake
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" get_memorylake_metadata

# Search for content
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" search_memory '{
  "parsed_query": {
    "bm25_cleaned_query": "revenue report 2024",
    "named_entities": [],
    "bm25_keywords": ["revenue", "report", "2024"],
    "bm25_boost_keywords": ["revenue", "2024"],
    "rewritten_query_for_dense_model": "Annual revenue and financial reports for the year 2024"
  }
}'

# Fetch file details
./scripts/memorylake_client.sh "$MCP_URL" "$SESSION" fetch_memory '{"memory_ids": ["ds-abc123"]}'
```

## Requirements

- **curl** (included on macOS and most Linux distros)
- **Claude Code** for skill installation and usage
- A **MemoryLake API key** from [memorylake.ai](https://memorylake.ai/)

## Links

- [MemoryLake](https://memorylake.ai/) — The memory layer for AI Agents
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — Anthropic's CLI for Claude
- [Model Context Protocol](https://modelcontextprotocol.io/) — The protocol MemoryLake implements

## License

MIT
