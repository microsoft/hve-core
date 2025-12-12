### Resource Access Strategy

**When working from VS Code extension context** and cannot find referenced resources from `docs/`, `scripts/`, or `learning/` directories:

1. **Primary**: Use GitHub MCP server to fetch resources from `hve-learning` repository:
   - Owner: `eedorenko`
   - Repository: `hve-learning` 
   - Use `mcp_github_mcp_get_file_contents` with appropriate paths
   - Examples: `learning/shared/templates/kata-template.md`, `docs/_server/schemas/`, `scripts/kata-validation/`

2. **Fallback**: If GitHub MCP server is not available, use `githubRepo` tool:
   - Repository: `eedorenko/hve-learning`
   - Search for specific files and content as needed

**IMPORTANT**: Do NOT use GitHub MCP server to fetch instruction files from `../instructions/` - these are always locally available in the extension or repository.

**Resource paths in this agent assume local access**. If files are not found locally, automatically fall back to remote GitHub access.