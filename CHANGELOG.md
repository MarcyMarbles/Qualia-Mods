# Changelog

## v2.0.0-RC1

### Added
- **`_early_setup()` lifecycle hook** — mods can now override `_early_setup()` to run code synchronously during bootstrap, before game autoloads (ItemMap, etc.) start their async work. The node is already in the tree so `get_tree()` works, but no `await` is allowed. Enables interception of game nodes like IconGenerator before they execute.
- **ModBase class** — new base class for zero-boilerplate mod development
  - Auto-detects `mod_id` from folder name
  - Pre-populates `config` from mod.cfg + user overrides
  - Auto-wires `_on_<hook>()` methods — just define the method, no manual `add_hook()` needed
  - Convenience helpers: `log_info()`, `get_cfg()`, `settings_tab()`
  - Full lifecycle: `_early_setup()` → `_setup()` → `_game_ready()` → `_config_changed()` → `_cleanup()`
- **Godot editor plugin** — SDK addon for the Godot editor
  - **New Mod dialog** — scaffolds mod directory with mod.cfg and mod_main.gd
  - **Pack Mod** — select a mod from `res://mods/`, one-click .pck export with .gd.remap generation
  - **Hooks Browser** — lists all available hooks with phase, description, and "Insert into current script" button
  - **One-click framework installer** — "Setup QualiaMods" button downloads all framework files from GitHub
  - **mod.cfg dock** — inspector panel for editing mod metadata
- **Editor dev mode** — `_scan_editor_mods()` discovers loose mod directories in `res://mods/` when running from the Godot editor, no .pck packing needed for testing

### Changed
- `log()` renamed to `log_info()` to avoid conflict with GDScript builtin `log()` (natural logarithm)
- Mod instances created in `_early_init_mods()` are reused by `_initialize_mods_async()` instead of being recreated

## v1.3.1

### Added
- **Lang subfolder support** — translations can now live in subfolders like `lang/ja/japanese.cfg` alongside font files, instead of only flat `lang/*.cfg`
- **Per-locale custom fonts** — `font = "filename.ttf"` and `fontSize = 12` in `[meta]` section of translation `.cfg`; font path resolved relative to the `.cfg` file
- **Language button without mods** — "Language" button now appears in main menu even with zero mods installed (shows "lang" when mods are present)
- **Packer: imported resource support** — `pack_qualiamods.gd` now parses `.import` files to find compiled resources in `.godot/imported/` (`.ctex`, `.fontdata`, etc.) and packs them alongside source files automatically
- **Packer: directory scanning** — `SCAN_DIRS` array for recursive resource discovery; moddders add their directory and the packer picks up fonts, textures, themes, etc.

### Fixed
- **i18n no longer depends on mods** — global translations from `<game_dir>/lang/` now load even when no mods are installed; previously the early return on empty mods list skipped i18n initialization entirely
- Split i18n init into two phases: global translations load before the mods check, per-mod translations load after dependency resolution
- **Locale restore** — switching back to English now restores original text and fonts; previously switching away from a non-English locale was a one-way operation

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
