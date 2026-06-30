#!/bin/bash
# PreToolUse(Bash) hook — enforces `make gate` before any `git commit`.
# Reads the tool-input JSON on stdin and only acts on git-commit commands.
#
# IMPORTANT (Claude Code hook semantics): a PreToolUse hook only BLOCKS the tool
# when it exits with code **2** (stderr is then fed back to Claude). ANY other
# exit code — including 1 — is treated as NON-blocking and Claude proceeds with
# the commit. So the gate MUST exit 2 on failure, or it does nothing but print.
# Ref: https://code.claude.com/docs/en/hooks  (exit-code semantics)
DIR="${CLAUDE_PROJECT_DIR:-.}"
INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', d.get('input', {})).get('command', ''))
except Exception:
    pass
" 2>/dev/null)

# Only gate actual commits; every other Bash command passes straight through.
echo "$CMD" | grep -q "git commit" || exit 0

# Run the gate; route its (verbose) output to stderr so stdout stays clean for
# the hook protocol. Exit 2 to BLOCK the commit when the gate is red.
if ! make -C "$DIR" gate >&2; then
    echo "BLOCKED: 'make gate' failed (smoke/test) — fix it before committing." >&2
    exit 2
fi
exit 0
