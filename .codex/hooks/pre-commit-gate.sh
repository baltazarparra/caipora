#!/bin/bash
# PreToolUse hook - runs make gate before any git commit.
# Receives tool input as JSON via stdin.
DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    candidates = [
        d.get('tool_input', {}),
        d.get('input', {}),
        d,
    ]
    cmd = ''
    for candidate in candidates:
        if isinstance(candidate, dict):
            cmd = candidate.get('command') or candidate.get('cmd') or ''
            if cmd:
                break
    print(cmd)
except Exception:
    pass
" 2>/dev/null)
if echo "$CMD" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    make -C "$DIR" gate </dev/null
fi
