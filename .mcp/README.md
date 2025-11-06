# MCP Server Configuration

This directory contains Model Context Protocol (MCP) server configurations for enhanced AI-assisted development workflows.

## GitHub MCP Server

The GitHub MCP server enables AI assistants to interact directly with GitHub APIs for repository operations, issue management, and PR workflows.

### Setup

1. **Install Node.js** (v18 or higher)

2. **Generate GitHub Personal Access Token**:
   - Go to: <https://github.com/settings/tokens>
   - Click "Generate new token (classic)"
   - Required scopes:
     - `repo` (Full control of private repositories)
     - `read:org` (Read org and team membership)
     - `user` (Read user profile data)
   - Copy the generated token

3. **Configure the MCP Server**:

   **Option A: VS Code Settings (Recommended)**

   Add to your VS Code `settings.json`:

   ```json
   {
     "github.copilot.chat.mcp.enabled": true,
     "github.copilot.chat.mcp.servers": {
       "github": {
         "command": "npx",
         "args": ["-y", "@modelcontextprotocol/server-github"],
         "env": {
           "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_TOKEN_HERE"
         }
       }
     }
   }
   ```

   **Option B: Use Configuration File**

   Copy `github-server.json` and add your token:

   ```json
   {
     "github": {
       "command": "npx",
       "args": ["-y", "@modelcontextprotocol/server-github"],
       "env": {
         "GITHUB_PERSONAL_ACCESS_TOKEN": "your_token_here"
       }
     }
   }
   ```

   **Option C: Environment Variable**

   Set the token as an environment variable:

   ```powershell
   # PowerShell
   $env:GITHUB_PERSONAL_ACCESS_TOKEN = "your_token_here"
   
   # Or add to your PowerShell profile for persistence
   [System.Environment]::SetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN', 'your_token_here', 'User')
   ```

   ```bash
   # Bash/Zsh
   export GITHUB_PERSONAL_ACCESS_TOKEN="your_token_here"
   
   # Or add to ~/.bashrc or ~/.zshrc for persistence
   echo 'export GITHUB_PERSONAL_ACCESS_TOKEN="your_token_here"' >> ~/.bashrc
   ```

4. **Restart VS Code** to load the new configuration

### Available Capabilities

The GitHub MCP server provides the following capabilities:

- **Repository Operations**:
  - Create or update files
  - Get file contents
  - Push multiple files
  - Search repositories
  - Fork repositories
  - Create repositories

- **Branch Management**:
  - Create branches
  - List branches
  - Get branch information

- **Issue Management**:
  - Create issues
  - List issues
  - Update issues
  - Add comments

- **Pull Request Workflows**:
  - Create pull requests
  - List pull requests
  - Update pull requests
  - Merge pull requests

### Usage in GitHub Copilot Chat

Once configured, you can use natural language commands in GitHub Copilot Chat:

```text
@workspace Create a new issue for adding PowerShell script documentation
@workspace List all open pull requests
@workspace Create a branch named feat/new-workflow
@workspace Show me the contents of README.md
```

### Security Notes

- **Never commit your GitHub token** to version control
- Use environment variables or secure credential storage
- Rotate tokens regularly
- Use tokens with minimal required permissions
- Consider using fine-grained personal access tokens for better security

### Troubleshooting

**Server not connecting:**

- Verify Node.js is installed: `node --version`
- Check token is set: `echo $env:GITHUB_PERSONAL_ACCESS_TOKEN` (PowerShell)
- Restart VS Code after configuration changes

**Permission errors:**

- Verify token has required scopes
- Check token hasn't expired
- Ensure token has access to the repository

### References

- [MCP Documentation](https://modelcontextprotocol.io/)
- [GitHub MCP Server](https://github.com/modelcontextprotocol/servers/tree/main/src/github)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
