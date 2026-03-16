# Changelog

## v1.1.0

### Added
- **Settings Tab API** — `ModLoader.add_settings_tab(name)` returns a `SettingsTab` builder for injecting custom tabs into the game's Settings Menu
- `SettingsTab.add_slider()` — horizontal slider with label
- `SettingsTab.add_toggle()` — CheckButton with label
- `SettingsTab.add_option()` — OptionButton dropdown with label
- `SettingsTab.add_spinbox()` — SpinBox with label
- `SettingsTab.add_color()` — ColorPickerButton with label
- `SettingsTab.add_text_input()` — LineEdit with label
- `SettingsTab.add_header()` — section header (dimmed label)
- `SettingsTab.add_separator()` — horizontal line
- `SettingsTab.add_label()` — info text with auto-wrap
- `SettingsTab.add_spacer()` — vertical spacing
- `SettingsTab.add_custom()` — insert any Control node
- `SettingsTab.get_container()` — raw VBoxContainer for fully custom layouts
- `SettingsTab.get_value(key)` / `set_value(key, value)` — read/write individual controls
- `SettingsTab.set_values(dict)` — bulk-set (useful for presets)
- `SettingsTab.get_all_values()` — Dictionary of all control values
- `SettingsTab.set_save_prefix(prefix)` — enable auto-persistence via settings_file
- `SettingsTab.load_values()` — load from save file
- `SettingsTab.saved` signal — emitted when Settings Menu save button is pressed
- `SettingsTab.remove()` — cleanup the tab

## v1.0.0

Initial release. Mod loader framework for Lucid Blocks with:
- PCK-based mod loading with mod.cfg metadata
- Lifecycle hooks (game_playable, world_loaded, etc.)
- Dependency resolution and topological load ordering
- Scene injection and node replacement
- Method wrapping/patching
- Item and resource registration
- Mods Menu (F10) with config editor
- Main menu button injection
- Game menu tab injection
- Mod-to-mod messaging
