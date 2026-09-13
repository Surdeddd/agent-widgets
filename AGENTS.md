# agent-widgets — engine guide for agents

This repository is the engine: the `aw` CLI, the SwiftUI kit widgets are written against, the preview renderer, templates, the MCP server and the skill. To **make widgets**, read [skills/agent-widgets/SKILL.md](skills/agent-widgets/SKILL.md) instead.

## Layout

| path | what |
|---|---|
| `Kit/` | Swift package: `AWSchema` (shared types), `AWKit` (components, provider, intents, dev slot), `AWPreview` (matrix renderer and checks) |
| `Sources/AWCore/` | CLI logic: workspace, manifests, codegen, build, install, preview pipeline, shots, feeds, daemon, doctor, issue catalog |
| `Sources/AWMCP/` | MCP server over stdio (swift-sdk) — tools call AWCore directly |
| `Sources/aw/` | argument parsing and output only |
| `Templates/` | host app, widget templates, workspace files copied by `aw init` |
| `skills/agent-widgets/` | the skill agents use to build widgets |
| `examples/` | demo workspace |

## Build and test

```sh
swift build                        # the CLI
swift test                         # AWCore + MCP tests, including integration (swiftc, xcodebuild)
AW_SKIP_INTEGRATION=1 swift test   # fast unit run
(cd Kit && swift test)             # kit and preview tests
swiftlint --strict                 # must be clean
make install                       # ~/.local/lib/agent-widgets + ~/.local/bin/aw
```

Requirements: macOS 14+, Xcode 16+, `brew install xcodegen swiftlint`.

## Rules

- Swift 6 toolchain in Swift 5 language mode, macOS 14 deployment target.
- No explanatory comments in code; a one-line `///` contract on public API is fine.
- Every user-facing string is bilingual through `L10n.pick(en:ru:)`; identifiers, JSON keys and commit messages are English.
- Commands print through `Printer`: human output by default, `--json` for machines, issues always carry a `hint`.
- New issue codes go into `IssueCode.all` and get an `IssueCatalog` entry in both languages (a test enforces it).
- Tests prove they bite: break the behavior, watch the test fail, restore.
- Conventional commits (`feat:`, `fix:`, `docs:`, …).

## How the pieces connect

`aw preview` compiles the widget's Swift files with a prebuilt kit (`~/Library/Caches/agent-widgets/kit/<fingerprint>`) into a small binary that renders every family × appearance × mode × sample with `ImageRenderer` and checks overflow and truncation. `aw build` generates `Registry.swift` and `project.yml`, runs xcodegen and xcodebuild; `aw install` swaps the app into `/Applications` with backups; the dev slot (`aw.dev`) renders whichever widget `dev/target.json` in the App Group names, so agents see real WidgetKit output without asking the user to place each widget.
