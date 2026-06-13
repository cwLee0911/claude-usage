#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/claude-menubar/Services/ClaudeStatusLineInstaller.swift"
BRIDGE_SCRIPT="$(mktemp)"
TMP_HOME="$(mktemp -d)"
TMP_HOME_EXPIRED="$(mktemp -d)"

cleanup() {
  rm -f "$BRIDGE_SCRIPT"
  rm -rf "$TMP_HOME" "$TMP_HOME_EXPIRED"
}
trap cleanup EXIT

awk '
  /private static let bridgeScript = #"""/ { in_script = 1; next }
  in_script && /^"""#/ { exit }
  in_script { print }
' "$SOURCE_FILE" > "$BRIDGE_SCRIPT"
chmod +x "$BRIDGE_SCRIPT"
bash -n "$BRIDGE_SCRIPT"

now="$(date +%s)"
future_reset=$((now + 3600))
next_reset=$((now + 7200))
week_reset=$((now + 86400))
past_reset=$((now - 3600))

run_bridge() {
  HOME="$TMP_HOME" "$BRIDGE_SCRIPT"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

json_a="$(printf '{"session_id":"term-a","rate_limits":{"five_hour":{"used_percentage":72,"resets_at":%s},"seven_day":{"used_percentage":15,"resets_at":%s}}}' "$future_reset" "$week_reset")"
json_b="$(printf '{"session_id":"term-b","rate_limits":{"five_hour":{"used_percentage":82,"resets_at":%s},"seven_day":{"used_percentage":16,"resets_at":%s}}}' "$future_reset" "$week_reset")"
json_new="$(printf '{"session_id":"term-c","rate_limits":{"five_hour":{"used_percentage":5,"resets_at":%s},"seven_day":{"used_percentage":17,"resets_at":%s}}}' "$next_reset" "$week_reset")"
json_expired="$(printf '{"session_id":"old-term","rate_limits":{"five_hour":{"used_percentage":72,"resets_at":%s},"seven_day":{"used_percentage":15,"resets_at":%s}}}' "$past_reset" "$week_reset")"

assert_eq "$(printf '%s' "$json_a" | run_bridge)" "Claude 72%" "first terminal writes 72%"
assert_eq "$(printf '%s' "$json_b" | run_bridge)" "Claude 82%" "second terminal raises aggregate to 82%"
assert_eq "$(printf '%s' "$json_a" | run_bridge)" "Claude 82%" "older same-window terminal cannot lower aggregate"

usage_file="$TMP_HOME/Library/Application Support/ClaudeMenubar/usage.json"
assert_eq "$(jq -r '.currentSession.usedPercentage' "$usage_file")" "82" "aggregate keeps max within same reset window"

assert_eq "$(printf '%s' "$json_new" | run_bridge)" "Claude 5%" "newer reset window replaces old window"
assert_eq "$(jq -r '.currentSession.usedPercentage' "$usage_file")" "5" "aggregate tracks newer reset window"

assert_eq "$(printf '%s' "$json_expired" | HOME="$TMP_HOME_EXPIRED" "$BRIDGE_SCRIPT")" "Claude 0%" "expired window displays reset usage"
expired_usage_file="$TMP_HOME_EXPIRED/Library/Application Support/ClaudeMenubar/usage.json"
assert_eq "$(jq -r '.displayPercentage' "$expired_usage_file")" "0" "expired aggregate display is zero"

echo "usage bridge verification passed"
