# OpenCode Notifier

This optional per-user integration sends local Mako notifications for OpenCode
events and can forward attention-required events to a private Telegram chat.
It is intentionally documented rather than deployed by the installer because
the Telegram destination and credentials are personal state.

## Current Personal Status (October 2026)

The `opencode-notifier` package is no longer installed on the host or selected by
the personal recipe. Notifications now use the separate custom
`~/.config/opencode/plugins/opencode-notifier-v2.js` plugin. The compatibility-copy
setup below is historical; do not reinstall or activate it alongside the custom
plugin as a routine dependency update. The personal-assistant bridge remains
separate. This repository update does not export or modify either private runtime.

## Historical Personal Runtime Contract

Ricardo's earlier OpenCode V2 configuration referenced a reviewed compatibility copy
under `~/.config/opencode/vendor/opencode-notifier`. That setup used the AUR package as the
upstream source, rather than referencing its legacy default export directly
until it provides the V2 `{ id, setup }` wrapper. The separate auto-loaded
`~/.config/opencode/plugins/personal-assistant-live.js` integration and the
`~/.local/bin/opencode-live-event` / `~/.local/bin/opencode-telegram-notify`
helpers use a private runtime bridge. Installing the packaged plugin does not
replace that custom integration.

The receiver, private `runtime.conf`, authentication and destination are not
exported here. This document is a contract, not delivery evidence or a host
configuration audit. Do not overwrite either helper, add a second forwarding
route, or remove overlapping paths until the receiver and deduplication behavior
are validated privately. No host OpenCode configuration was changed by this
documentation update.

## Example Local Behavior

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
previous one rather than stacking. OpenCode's native CLI attention notifications
and sounds must remain disabled in `~/.config/opencode/cli.json`; the notifier
plugin is the only owner of local desktop notifications and sounds. Keep the
bundled CLI notification plugin explicitly disabled as well:

```json
{
  "attention": { "notifications": false, "sound": false },
  "plugins": ["-opencode.notifications"]
}
```

## Plugin

Install the package-managed plugin source instead of letting OpenCode download
it from npm. The repository builds it only when the installer receives `--aur`;
on an existing system, install it with:

```bash
yay -S --needed opencode opencode-notifier
```

`opencode` is supplied by the official repository and `opencode-notifier` is an
AUR package. Installing the package does not load the plugin, create a notifier
profile, or configure Telegram. To opt in, add the packaged plugin to the
global `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "plugins": ["file:///home/ricardo/.config/opencode/vendor/opencode-notifier"]
}
```

Verify the upstream package ownership with:

```bash
pacman -Qo /usr/lib/opencode/plugins/opencode-notifier/dist/index.js
```

The compatibility copy must contain the same package release and differ only in
the V2 default-export wrapper. Rebuild and review it after package upgrades.

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
    "permission": { "sound": true, "notification": true, "command": false, "bell": false },
    "complete": { "sound": true, "notification": true, "command": false, "bell": false },
    "subagent_complete": false,
    "error": { "sound": true, "notification": true, "command": false, "bell": false },
    "question": { "sound": true, "notification": true, "command": false, "bell": false },
    "user_cancelled": false,
    "plan_exit": { "sound": true, "notification": true, "command": false, "bell": false },
    "session_started": false,
    "user_message": false,
    "client_connected": false
  },
  "messages": {
    "permission": "OpenCode needs permission to continue: {sessionTitle}",
    "complete": "OpenCode finished the task. Review the result: {sessionTitle}",
    "error": "OpenCode encountered an error. Open the session to review it: {sessionTitle}",
    "question": "OpenCode needs your answer before it can continue: {sessionTitle}",
    "plan_exit": "The implementation plan is ready for your review: {sessionTitle}"
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

The example above is not a replacement for Ricardo's runtime configuration.
The notifier command route stays disabled. Ricardo's auto-loaded
`personal-assistant-live.js` plugin owns private bridge events for permission and
question requests, preserving the session ID and avoiding duplicate delivery.

## Telegram Forwarding

The previous direct Bot API helper example was not a description of Ricardo's
bridge route and must not replace the existing helper. Forwarding is optional
private provisioning, not part of package installation or ISO generation.
Keep runtime credentials and addresses outside Git and source snapshots, in
owner-only directories/files (0700/0600). Never include them in command logs,
debug-configuration dumps, reports or screenshots. No replacement transport
code is shipped until its receiver contract has been established.

## Verification

In a separately approved runtime session, validate each event using synthetic
non-sensitive content. Check local delivery, bridge acknowledgment, receiver
delivery and duplicate suppression independently; a zero helper exit status is
not proof of Telegram delivery. Do not export session titles or prompts merely
to test the route. Keep local focus suppression in mind. Restart OpenCode only
after an actual approved configuration change; no restart is needed for this
documentation-only correction.
