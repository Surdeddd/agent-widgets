# agent-widgets

Native macOS desktop widgets built by your AI agent. You say what you want to see on the desktop; the agent writes a small SwiftUI view and a feed script, and `aw` does the rest: WidgetKit plumbing, previews of every size with layout checks, a signed build, the install and a screenshot of the real widget.

This package ships the prebuilt universal `aw` binary with its kit, templates, skill and a gallery of ready-made widgets: AI limits for Claude and Codex, running agent sessions, GitHub contributions, AI spend, 2048, a system monitor and a focus timer.

## MCP server

```sh
npx -y agent-widgets mcp --workspace ~/Widgets
```

Claude Code:

```sh
claude mcp add agent-widgets -- npx -y agent-widgets mcp --workspace ~/Widgets
```

Any other client:

```json
{
  "mcpServers": {
    "agent-widgets": {
      "command": "npx",
      "args": ["-y", "agent-widgets", "mcp", "--workspace", "~/Widgets"]
    }
  }
}
```

The folder may be empty: the `aw_init` tool sets it up, `aw_gallery` lists the ready-made widgets.

## CLI

```sh
npm install -g agent-widgets
aw init ~/Widgets && cd ~/Widgets
aw gallery add ai-limits
aw feed run ai-limits
aw ship ai-limits
aw skill install
```

## Requirements

macOS 14+, Xcode 16+ with a free Apple ID (Personal Team is enough) and `brew install xcodegen`. `aw doctor` checks all of it.

Documentation, screenshots and the Russian README: <https://github.com/Surdeddd/agent-widgets>.
