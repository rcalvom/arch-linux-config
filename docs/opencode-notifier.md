# OpenCode Notifier

This optional per-user integration sends local Mako notifications for OpenCode
events and can forward attention-required events to a private Telegram chat.
It is intentionally documented rather than deployed by the installer because
the Telegram destination and credentials are personal state.

## Behavior

The recommended local configuration uses five-second notifications, matching
the battery notices configured in Waybar and Mako. Notifications include the
event type and session title, but do not use an icon.

| Event | Local notification | Sound | Telegram |
| --- | --- | --- | --- |
| `permission` | Yes | `message-new-instant.oga` | Yes |
| `question` | Yes | `message-new-instant.oga` | Yes |
| `plan_exit` | Yes | `message-new-instant.oga` | Yes |
| `complete` | Yes | `message.oga` | No |
| `error` | Yes | `dialog-warning.oga` | Yes |
| `subagent_complete`, `user_cancelled`, `session_started`, `user_message`, `client_connected` | No | No | No |

Notifications are suppressed while the OpenCode terminal is focused. Linux
notification grouping is enabled, so a new OpenCode notice replaces the
previous one rather than stacking.

## Plugin

Install the package-managed plugin instead of letting OpenCode download it from
npm:

```bash
yay -S --needed opencode opencode-notifier
```

`opencode` is supplied by the official repository and `opencode-notifier` is an
AUR package. The global `~/.config/opencode/opencode.json` must contain:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "plugin": ["file:///usr/lib/opencode/plugins/opencode-notifier/dist/index.js"]
}
```

The file URL keeps the plugin under package ownership. Verify it with:

```bash
pacman -Qo /usr/lib/opencode/plugins/opencode-notifier/dist/index.js
```

Create `~/.config/opencode/opencode-notifier.json` with the selected profile:

```json
{
  "sound": true,
  "notification": true,
  "bell": false,
  "timeout": 5,
  "showProjectName": true,
  "showFullPath": false,
  "showSessionTitle": true,
  "showIcon": false,
  "suppressWhenFocused": true,
  "linux": { "grouping": true },
  "events": {
    "permission": { "sound": true, "notification": true, "command": true, "bell": false },
    "complete": { "sound": true, "notification": true, "command": false, "bell": false },
    "subagent_complete": false,
    "error": { "sound": true, "notification": true, "command": true, "bell": false },
    "question": { "sound": true, "notification": true, "command": true, "bell": false },
    "user_cancelled": false,
    "plan_exit": { "sound": true, "notification": true, "command": true, "bell": false },
    "session_started": false,
    "user_message": false,
    "client_connected": false
  },
  "messages": {
    "permission": "🔐 Permission required: {sessionTitle}",
    "complete": "✅ Task completed: {sessionTitle}",
    "error": "🚨 Error: {sessionTitle}",
    "question": "❓ Question pending: {sessionTitle}",
    "plan_exit": "📝 Plan ready for review: {sessionTitle}"
  },
  "sounds": {
    "permission": "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga",
    "complete": "/usr/share/sounds/freedesktop/stereo/message.oga",
    "error": "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga",
    "question": "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga",
    "plan_exit": "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
  }
}
```

Add the `command` block described below when Telegram forwarding is wanted. The
plugin must be restarted after configuration changes.

## Telegram Forwarding

The notifier's command hook can call a local script. The script accepts the
event name and rendered notification message, then sends the message through
the Telegram Bot API. It requires `curl`; `jq` is useful when discovering the
chat ID.

Keep credentials outside the repository:

```text
~/.config/opencode/secrets/                     mode 700
~/.config/opencode/secrets/telegram-bot.token   mode 600
~/.config/opencode/secrets/telegram-chat-id     mode 600
~/.local/bin/opencode-telegram-notify           mode 700
```

Create the bot through BotFather, send `/start` to it from the intended private
chat, then obtain that chat's numeric ID through the Bot API. Do not commit or
paste bot tokens into configuration files, shell history, issue trackers, or
chat transcripts. Revoke any token that has been exposed.

Configure the command hook as follows. Set `command: false` for events that
must remain local-only, such as `complete`.

```json
{
  "command": {
    "enabled": true,
    "path": "/home/USER/.local/bin/opencode-telegram-notify",
    "args": ["{event}", "{message}"],
    "minDuration": 0
  }
}
```

Use this helper as `~/.local/bin/opencode-telegram-notify`:

```bash
#!/usr/bin/env bash
set -euo pipefail

token_file="$HOME/.config/opencode/secrets/telegram-bot.token"
chat_id_file="$HOME/.config/opencode/secrets/telegram-chat-id"

[[ $# -eq 2 && -r "$token_file" && -r "$chat_id_file" ]] || exit 0

token=$(<"$token_file")
chat_id=$(<"$chat_id_file")

curl --fail --silent --show-error --max-time 15 \
  --data-urlencode "chat_id=$chat_id" \
  --data-urlencode "text=$2" \
  --data-urlencode "disable_web_page_preview=true" \
  "https://api.telegram.org/bot${token}/sendMessage" >/dev/null
```

Make the helper executable with mode `700`. Do not print either secret or place
the token in a tracked script.

## Verification

Restart OpenCode after changing its global configuration, notifier profile, or
helper script. If OpenCode runs through the shared user service, restart that
service. Verify the plugin is registered with:

```bash
systemctl --user restart opencode-server.service
opencode debug config
```

For a local Telegram check, invoke the helper with a harmless test message.
The command should exit successfully and the private chat should receive one
message. Keep OpenCode unfocused when testing local notifications; focus
suppression is enabled by design.
