#!/bin/sh
if command -v aw >/dev/null 2>&1; then
  exit 0
fi
case "${AW_LANG:-${LANG:-en}}" in
  ru*)
    printf '%s\n' "agent-widgets: команды aw нет в PATH, поэтому MCP-сервер agent-widgets не запустится. Поставь: brew install surdeddd/tap/agent-widgets (или git clone https://github.com/Surdeddd/agent-widgets && make install) и перезапусти Claude Code."
    ;;
  *)
    printf '%s\n' "agent-widgets: the aw command is not on PATH, so the agent-widgets MCP server cannot start. Install it with brew install surdeddd/tap/agent-widgets (or git clone https://github.com/Surdeddd/agent-widgets && make install), then restart Claude Code."
    ;;
esac
