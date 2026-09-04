class_name SettingsBus
extends RefCounted

## Signal carrier for [Settings]. A static class cannot declare signals of its own, so it holds
## one of these and listeners connect through it:
## [codeblock]
## Settings.bus.changed.connect(_on_setting_changed)
## [/codeblock]


## Emitted after one setting changes and its applier has run.
signal changed(key: StringName, value: Variant)
