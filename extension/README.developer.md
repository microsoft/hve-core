# HVE Core - Developer Edition

> AI-powered coding agents and prompts curated for software engineers

HVE Core - Developer Edition provides a focused collection of AI chat agents, prompts, and instructions designed for software engineers working in VS Code with GitHub Copilot. This edition includes the RPI (Research-Plan-Implement) workflow and supporting development tools.

## Features

### 🤖 Chat Agents

| Agent | Description |
| ----- | ----------- |
| **memory** | Conversation memory persistence for session continuity |
| **rpi-agent** | Autonomous RPI orchestrator dispatching task agents through Research, Plan, Implement, Review, and Discover phases |
| **task-implementor** | Executes implementation plans with progressive tracking and change records |
| **task-planner** | Implementation planner for creating actionable implementation plans |
| **task-researcher** | Task research specialist for comprehensive project analysis |
| **task-reviewer** | Reviews completed implementation work for accuracy, completeness, and convention compliance |

### 📝 Prompts

| Prompt | Description |
| ------ | ----------- |
| **checkpoint** | Save or restore conversation context using memory files |
| **rpi** | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks |
| **task-implement** | Locates and executes implementation plans using task-implementor mode |
| **task-plan** | Initiates implementation planning based on user context or research documents |
| **task-research** | Initiates research for implementation planning based on user requirements |
| **task-review** | Initiates implementation review based on user context or automatic artifact discovery |

### 📚 Instructions

| Instruction | Description |
| ----------- | ----------- |
| **commit-message** | Required instructions for creating all commit messages |
| **markdown** | Required instructions for creating or editing any Markdown files |

### ⚡ Skills

| Skill | Description |
| ----- | ----------- |
| **video-to-gif** | Video-to-GIF conversion with FFmpeg two-pass optimization |

## Getting Started

After installing this extension, the chat agents will be available in GitHub Copilot Chat. You can:

1. **Use custom agents** by selecting the custom agent from the agent picker drop-down list in Copilot Chat
2. **Apply prompts** through the Copilot Chat interface
3. **Reference instructions** — They're automatically applied based on file patterns

### Post-Installation Setup

Some chat agents create workflow artifacts in your project directory. See the [installation guide](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/install.md#post-installation-update-your-gitignore) for recommended `.gitignore` configuration and other setup details.

## Usage Examples

### Using Chat Agents

```plaintext
rpi-agent help me research and implement this feature end-to-end
task-planner help me break down this feature into implementable tasks
task-researcher investigate the best approach for adding authentication
```

### Applying Prompts

Prompts are available in the Copilot Chat prompt picker and can be used to generate consistent, high-quality outputs for common tasks.

## Pre-release Channel

HVE Core offers two installation channels:

| Channel     | Description                                             | Maturity Levels                     |
| ----------- | ------------------------------------------------------- | ----------------------------------- |
| Stable      | Production-ready artifacts only                         | `stable`                            |
| Pre-release | Early access to new features and experimental artifacts | `stable`, `preview`, `experimental` |

To install the pre-release version, select **Install Pre-Release Version** from the extension page in VS Code, or use the Extensions view and switch to the pre-release channel.

For more details on maturity levels and the release process, see the [contributing documentation](https://github.com/microsoft/hve-core/blob/main/docs/contributing/release-process.md#extension-channels-and-maturity).

## Requirements

- VS Code version 1.106.1 or higher
- GitHub Copilot extension

## Full Edition

Looking for more agents covering architecture, documentation, Azure DevOps, data science, and security? Check out the full [HVE Core](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) extension.

## License

MIT License - see [LICENSE](LICENSE) for details

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/microsoft/hve-core).

---

Brought to you by Microsoft ISE HVE Essentials
