# Discord Rich Presence for Godot

Discord Rich Presence for Godot 4.4+ in pure GDScript. No GDExtension, no
DLLs, no Game SDK. This folder is the whole addon: one script class,
`DiscordRichPresence`, nothing to enable in the editor.

```gdscript
var presence := DiscordRichPresence.new()
presence.app_id = "1234567890123456789"  # Discord Developer Portal
add_child(presence)  # An autoload is the perfect parent.
presence.set_activity({"details": "In the Hub", "state": "Level 12"})
```

Works on Windows (named pipe), and on macOS and Linux (unix socket
bridged through the system `nc`). Everywhere else the node does nothing.

Full documentation and the Godot pitfalls this addon works around are
in the [repository README](https://github.com/SlayHorizon/discord-rich-presence-godot).
[MIT License](LICENSE).
