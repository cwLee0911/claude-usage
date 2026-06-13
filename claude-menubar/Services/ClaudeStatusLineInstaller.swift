import Foundation

enum ClaudeStatusLineInstaller {
    private static let bridgeCommand = UsagePaths.bridgeScriptURL.path

    static func installIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: UsagePaths.bridgeScriptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: UsagePaths.appSupportDirectory,
            withIntermediateDirectories: true
        )

        try bridgeScript.write(to: UsagePaths.bridgeScriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: UsagePaths.bridgeScriptURL.path
        )

        var settings = try loadSettings()
        let existingStatusLine = settings["statusLine"] as? [String: Any]
        let existingCommand = existingStatusLine?["command"] as? String
        let existingRefreshInterval = existingStatusLine?["refreshInterval"] as? Int

        if existingCommand == bridgeCommand, existingRefreshInterval == 5 {
            return
        }

        try migrateLegacyOriginalCommandIfNeeded()

        if let existingCommand,
           existingCommand != bridgeCommand,
           !isManagedBridgeCommand(existingCommand),
           !existingCommand.isEmpty {
            try existingCommand.write(
                to: UsagePaths.originalStatusLineCommandURL,
                atomically: true,
                encoding: .utf8
            )
        }

        settings["statusLine"] = [
            "type": "command",
            "command": bridgeCommand,
            "padding": 0,
            "refreshInterval": 5
        ]

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: UsagePaths.claudeSettingsURL, options: .atomic)
    }

    private static func loadSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: UsagePaths.claudeSettingsURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: UsagePaths.claudeSettingsURL)
        guard !data.isEmpty else { return [:] }

        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private static func migrateLegacyOriginalCommandIfNeeded() throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: UsagePaths.originalStatusLineCommandURL.path),
              fileManager.fileExists(atPath: UsagePaths.legacyOriginalStatusLineCommandURL.path) else {
            return
        }

        let command = try String(contentsOf: UsagePaths.legacyOriginalStatusLineCommandURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !isManagedBridgeCommand(command) else { return }

        try command.write(
            to: UsagePaths.originalStatusLineCommandURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private static func isManagedBridgeCommand(_ command: String) -> Bool {
        command.contains(UsagePaths.bridgeScriptURL.path)
            || command.contains(UsagePaths.legacyBridgeScriptURL.path)
            || command.contains("claude-menubar-bridge.sh")
            || command.contains("claude-usage-limit-bridge.sh")
    }

    private static let bridgeScript = #"""
#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
support_dir="$HOME/Library/Application Support/ClaudeMenubar"
sessions_dir="$support_dir/sessions"
usage_file="$support_dir/usage.json"
tmp_file="$support_dir/usage.json.tmp.$$"
original_command_file="$HOME/.claude/claude-menubar-original-command.txt"
legacy_original_command_file="$HOME/.claude/claude-usage-limit-original-command.txt"

jq_bin="${CLAUDE_MENUBAR_JQ:-}"
if [ -z "$jq_bin" ]; then
  jq_bin="$(command -v jq 2>/dev/null || true)"
fi
if [ -z "$jq_bin" ] && [ -x /opt/homebrew/bin/jq ]; then
  jq_bin="/opt/homebrew/bin/jq"
fi
if [ -z "$jq_bin" ] && [ -x /usr/bin/jq ]; then
  jq_bin="/usr/bin/jq"
fi

display="--%"
json=""
aggregate_json=""

display_from_json() {
  printf '%s' "$1" | "$jq_bin" -r '
    def clamp: [0, ., 100] | sort | .[1];
    def effective($window):
      if ($window.usedPercentage // null) == null then null
      elif (($window.resetsAt // null) != null and ($window.resetsAt <= now)) then 0
      else ($window.usedPercentage | clamp)
      end;
    (effective(.currentSession) // effective(.weekly)) as $pct
    | if $pct == null then "--%" else (($pct | round | tostring) + "%") end
  ' 2>/dev/null || printf '%s' "--%"
}

write_aggregate() {
  local session_files=("$sessions_dir"/*.json)
  if [ ! -e "${session_files[0]}" ]; then
    return
  fi

  aggregate_json="$("$jq_bin" -s -c '
    def number_or_null:
      if . == null then null
      elif type == "number" then .
      elif type == "string" then (tonumber? // null)
      else null end;
    def clean_window:
      {
        usedPercentage: (.usedPercentage | number_or_null),
        resetsAt: (.resetsAt | number_or_null)
      };
    def aggregate_window($name):
      map(select(.[$name] != null and (.[$name].usedPercentage != null)))
      | if length == 0 then
          { usedPercentage: null, resetsAt: null }
        else
          (map(.[$name].resetsAt // 0) | max) as $latestReset
          | map(select((.[$name].resetsAt // 0) == $latestReset))
          | max_by(.[$name].usedPercentage)
          | .[$name]
          | clean_window
        end;
    def effective($window):
      if ($window.usedPercentage // null) == null then null
      elif (($window.resetsAt // null) != null and ($window.resetsAt <= now)) then 0
      else ([0, $window.usedPercentage, 100] | sort | .[1])
      end;
    map(select(.schemaVersion != null)) as $sessions
    | {
        schemaVersion: 2,
        planName: ($sessions | map(.planName // empty) | last // null),
        currentSession: ($sessions | aggregate_window("currentSession")),
        weekly: ($sessions | aggregate_window("weekly")),
        updatedAt: ($sessions | map(.updatedAt // 0) | max // (now | floor))
      } as $aggregate
    | $aggregate + {
        displayPercentage: (effective($aggregate.currentSession) // effective($aggregate.weekly))
      }
  ' "${session_files[@]}" 2>/dev/null || true)"

  if [ -n "$aggregate_json" ]; then
    printf '%s\n' "$aggregate_json" > "$tmp_file"
    mv "$tmp_file" "$usage_file"
  fi
}

if [ -n "$jq_bin" ]; then
  json="$(printf '%s' "$input" | "$jq_bin" -c '
    def epoch:
      if . == null then null
      elif type == "number" then .
      elif type == "string" then (fromdateiso8601? // tonumber? // null)
      else null end;
    def number_or_null:
      if . == null then null
      elif type == "number" then .
      elif type == "string" then (tonumber? // null)
      else null end;
    .rate_limits as $limits
    | select($limits != null)
    | {
        schemaVersion: 2,
        sessionId: ((.session_id // "unknown") | tostring),
        sessionName: (.session_name // null),
        planName: null,
        currentSession: {
          usedPercentage: ($limits.five_hour.used_percentage | number_or_null),
          resetsAt: (($limits.five_hour.resets_at // null) | epoch)
        },
        weekly: {
          usedPercentage: ($limits.seven_day.used_percentage | number_or_null),
          resetsAt: (($limits.seven_day.resets_at // null) | epoch)
        },
        updatedAt: (now | floor)
      }
    | select(.currentSession.usedPercentage != null or .weekly.usedPercentage != null)
  ' 2>/dev/null || true)"

  if [ -n "$json" ]; then
    mkdir -p "$sessions_dir"
    session_id="$(printf '%s' "$json" | "$jq_bin" -r '.sessionId | gsub("[^A-Za-z0-9._-]"; "_")' 2>/dev/null || printf '%s' "unknown")"
    if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
      session_id="unknown"
    fi

    session_file="$sessions_dir/$session_id.json"
    session_tmp_file="$sessions_dir/$session_id.json.tmp.$$"
    printf '%s\n' "$json" > "$session_tmp_file"
    mv "$session_tmp_file" "$session_file"

    write_aggregate
  elif [ -s "$usage_file" ]; then
    aggregate_json="$(cat "$usage_file")"
  fi

  if [ -n "$aggregate_json" ]; then
    display="$(display_from_json "$aggregate_json")"
  fi
fi

if [ -s "$original_command_file" ]; then
  original_command="$(cat "$original_command_file")"
elif [ -s "$legacy_original_command_file" ]; then
  original_command="$(cat "$legacy_original_command_file")"
else
  original_command=""
fi

case "$original_command" in
  *claude-menubar-bridge.sh*|*claude-usage-limit-bridge.sh*)
    original_command=""
    ;;
esac

if [ -n "$original_command" ]; then
  original_output="$(printf '%s' "$input" | /bin/zsh -lc "$original_command" 2>/dev/null || true)"
  if [ -n "$original_output" ]; then
    printf '%s\n' "$original_output"
    exit 0
  fi
fi

printf 'Claude %s\n' "$display"
"""#

}
