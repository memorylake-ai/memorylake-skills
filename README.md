# MemoryLake Skills

A skill that enables AI agents to **create projects, upload documents, and then search/retrieve/analyze** data from a [MemoryLake](https://memorylake.ai/) server — the memory layer for AI Agents.

## Compatible Platforms

This skill works with any AI coding agent that supports MCP or can execute shell commands:

<table>
  <tr>
    <td align="center" width="160">
      <a href="https://docs.anthropic.com/en/docs/claude-code">
        <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Claude_AI_symbol.svg/1280px-Claude_AI_symbol.svg.png" width="48" height="48" alt="Claude Code" /><br />
        <b>Claude Code</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://cursor.com">
        <img src="https://cdn.simpleicons.org/cursor/F54E00" width="48" height="48" alt="Cursor" /><br />
        <b>Cursor</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://openai.com/codex/">
        <img src="https://cdn.simpleicons.org/openai/412991" width="48" height="48" alt="OpenAI Codex" /><br />
        <b>OpenAI Codex</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://manus.im">
        <img src="https://cdn.simpleicons.org/meta/0081FB" width="48" height="48" alt="Manus" /><br />
        <b>Manus</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://antigravity.google">
        <img src="https://brandlogos.net/wp-content/uploads/2025/12/google_antigravity-logo_brandlogos.net_qu4jc-512x472.png" width="48" height="48" alt="Google Antigravity" /><br />
        <b>Google Antigravity</b>
      </a>
    </td>
    <td align="center" width="160">
      <a href="https://openclaw.ai">
        <img src="https://pub-9d9ac8d48a724b8eb296cf20dfd3c940.r2.dev/OpenClaw/ClawBot.png" width="48" height="48" alt="OpenClaw" /><br />
        <b>OpenClaw</b>
      </a>
    </td>
  </tr>
  <tr>
    <td align="center"><sub>Anthropic's agentic<br/>CLI for Claude</sub></td>
    <td align="center"><sub>AI-powered<br/>code editor</sub></td>
    <td align="center"><sub>OpenAI's terminal<br/>coding agent</sub></td>
    <td align="center"><sub>Autonomous AI<br/>agent by Meta</sub></td>
    <td align="center"><sub>Google's agent-first<br/>IDE with Gemini</sub></td>
    <td align="center"><sub>Open-source personal<br/>AI assistant</sub></td>
  </tr>
</table>

> **How it works:**
> - Use the **REST API** (Bearer API key + `X-User-ID`) to create a project, upload documents, and generate an MCP secret.
> - Use the **Streamable HTTP MCP** server (secret in query string) for search + retrieval + code-run analysis.
>
> This repo includes two shell clients:
> - `scripts/memorylake_rest_client.sh` (REST)
> - `scripts/memorylake_client.sh` (MCP)

## What is MemoryLake?

[MemoryLake](https://memorylake.ai/) ingests unstructured files (Excel, PDF, text, etc.), chunks and indexes their content, and exposes it through a [Streamable HTTP MCP Server](https://modelcontextprotocol.io/) for intelligent retrieval and data analysis. It gives AI agents long-term memory over your documents.

## What This Skill Does

- **Hybrid search** — Semantic + keyword (BM25) search across all indexed documents
- **File exploration** — Browse memorylake contents, file types, and metadata
- **Code-based analysis** — Run Python (pandas, numpy, scikit-learn, etc.) against your data server-side
- **Session management** — A bash client that handles the MCP Streamable HTTP protocol (JSON-RPC, SSE, session lifecycle)

## Project Structure

```
memorylake-skills/
├── SKILL.md                          # Skill definition with end-to-end workflow (REST → MCP)
├── scripts/
│   ├── memorylake_rest_client.sh      # REST client (projects, uploads, documents)
│   └── memorylake_client.sh           # MCP client (Streamable HTTP MCP)
├── references/
│   ├── mcp-tools.md                   # MCP tool parameters and response formats
│   └── memorylake-openapi.json         # REST OpenAPI spec (projects/drives/upload/etc.)
└── memorylake-skills.skill             # Packaged distributable (.zip with .skill extension)
```

## Quick Start

### 1. Install the skill

Download `memorylake-skills.skill` from [Releases](https://github.com/memorylake-ai/memorylake-skills/releases) or clone this repo, then install in your AI agent. For example, in Claude Code:

```
/skill install memorylake-skills.skill
```

### 2. Get a MemoryLake API key (REST)

1. Go to https://app.memorylake.ai/ and apply for an API key.
2. REST Base URL:

```
https://app.memorylake.ai/openapi/memorylake
```

Auth headers:
- `Authorization: Bearer <your API key>`
- `X-User-ID: <your user id>`

### 3. Create a project + generate MCP secret

```bash
export MEMORYLAKE_BASE_URL="https://app.memorylake.ai/openapi/memorylake"
export MEMORYLAKE_API_KEY="<your api key>"
export MEMORYLAKE_USER_ID="<your user id>"

# Create project
./scripts/memorylake_rest_client.sh projects:create '{"name":"My Project"}'

# Create project API key (this is the MCP secret)
./scripts/memorylake_rest_client.sh projects:create-apikey <project_id> '{"description":"mcp"}'
```

Use the returned `secret` to form the MCP URL:

```
https://ai.data.cloud/memorylake/mcp/v1?apikey=<secret>
```

### 4. Upload documents + quick-add into project

```bash
# Create multipart upload and complete it (uploads parts to presigned URLs)
./scripts/memorylake_rest_client.sh upload:create-multipart '{"file_size": 123456}' > upload.json
./scripts/memorylake_rest_client.sh upload:complete-multipart upload.json /path/to/file.pdf

# Then quick-add into the project
./scripts/memorylake_rest_client.sh projects:quick-add <project_id> '{"object_key":"<object_key>","file_name":"file.pdf"}'
```

If you have multiple documents, upload + quick-add **one by one**.

### 5. Poll document status until ready

```bash
./scripts/memorylake_rest_client.sh projects:list-documents <project_id>
```

Document status values: `error`, `okay`, `running`, `pending`. Recommended polling interval: **5s**.

### 6. Ask questions about your data (MCP)

Once installed, your AI agent can:

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

## Using the MCP Client Script Standalone

Once you have the MCP URL (`.../mcp/v1?apikey=<secret>`), you can use `scripts/memorylake_client.sh` directly:

```bash
MCP_URL="https://ai.data.cloud/memorylake/mcp/v1?apikey=<secret>"

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
- A **MemoryLake API key** from [memorylake.ai](https://memorylake.ai/)

## Links

- [MemoryLake](https://memorylake.ai/) — The memory layer for AI Agents
- [Model Context Protocol](https://modelcontextprotocol.io/) — The protocol MemoryLake implements
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | [Cursor](https://cursor.com) | [OpenAI Codex](https://openai.com/codex/) | [Manus](https://manus.im) | [Google Antigravity](https://antigravity.google) | [OpenClaw](https://openclaw.ai)

## License

MIT
