# Changelog

## v1.3.0

### Added
- **i18n system** — runtime localization for the game and mods
  - Translators drop `.cfg` files into `<game_dir>/lang/` — no mod needed
  - Mods can include their own translations in `mods/<id>/lang/`
  - Framework scans global translations first, then per-mod
  - Language menu accessible from main menu (mods | lang row)
  - Locale choice persists across sessions (`lang/settings.cfg`)
  - Automatic `english.cfg` fallback creation if missing
- **Translation format** — Godot ConfigFile with `[meta]` + `[strings]` sections
  - Keys must be quoted to preserve spaces: `"exit game" = "(終了)"`
  - `locale` field for explicit locale code, `displayName` for the selector
  - Fallback locale guessing from displayName if `locale` is omitted
- **Dynamic text translation** — button hover/state changes caught via signal hooks (`mouse_entered`, `mouse_exited`, `pressed`, `visibility_changed`)
- **Public API**
  - `ModLoader.set_locale(locale)` — switch language at runtime
  - `ModLoader.get_locale()` — current locale code
  - `ModLoader.get_available_locales()` — list of loaded locales
  - `ModLoader.get_locale_display_name(locale)` — display name for selector
  - `ModLoader.load_translation(path)` — load a .cfg translation file manually
  - `ModLoader.reload_translations()` — rescan all translation sources
- **SDK** — `sdk/i18n/strings.cfg` template with all game UI strings, translation examples in `sdk/examples/minimal/lang/` and `sdk/template/lang/`

## v1.2.0

### Added
- **Loading screen** — shows mod loading progress during startup with per-mod status indicators and progress bar, styled to match the game's visual language (Silkscreen font, dark theme, pixel-art panels)
- **Splash screen replacement** — replaces the game's default splash image with QualiaMods branding during world startup
- **Async bootstrap** — mods initialize asynchronously, yielding frames for UI updates
- **Subfolder support** — PCK files in subdirectories of `mods/` are now discovered and loaded
- **Config hints** — `[config_min]`, `[config_max]`, `[config_step]` sections in mod.cfg to define numeric ranges for config values
- Config hints applied to SpinBox controls in Mods Menu (default max raised from 100 to 10000)

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
