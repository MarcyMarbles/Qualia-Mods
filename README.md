# QualiaMods

Mod framework for [Lucid Blocks](https://store.steampowered.com/app/2704610/Lucid_Blocks/).

Lucid Blocks already has a basic mod loader that picks up `.pck` files from the `mods/` folder. QualiaMods builds on that - it gives mods a proper lifecycle, hooks into game events, a config system, and an in-game menu to manage everything.

I'm not going to tell you that you must use this framework. It's entirely up to you - your mod works fine without it.

This is a hobby project, I work on it when I have time.

## Installing

Grab `_000_qualiamods.pck` from [Releases](../../releases) and drop it into the `mods/` folder next to `lucid blocks.exe`. Create the folder if there isn't one. That's it - press F10 in game to open the mods menu.

## What you get

- Lifecycle for mods (`_init_mod` -> `_game_ready` -> `_mod_cleanup`)
- Hooks for game events - `game_playable`, `world_loaded`, `game_quit`, etc.
- Scene injection, item registration, method wrapping
- Config system with in-game editing
- Mods menu with enable/disable and per-mod settings
- Dependency resolution so mods load in the right order
- Inter-mod messaging

Full API docs are in [sdk/ENCYCLOPEDIA.md](sdk/ENCYCLOPEDIA.md).

## Making mods

Write your mod the same way as before. If you want QualiaMods integration, add two files to your .pck:

```
mods/yourmod/
  mod.cfg        <- name, version, config defaults
  mod_main.gd    <- entry point
```

Without those files the mod still loads normally, QualiaMods just won't be able to manage it.

## SDK

The `sdk/` folder has some stuff to make development easier:

- **stubs/** - drop these into your Godot project for `ModLoader` and `Ref` autocompletion. Don't include them in your .pck, they're just for the editor.
- **template/** - skeleton `mod.cfg` + `mod_main.gd` to start from
- **examples/** - a minimal mod and a settings menu injection example
- **pack_mod.gd** - universal packer so you don't have to write one per mod: `godot --headless --script res://sdk/pack_mod.gd -- yourmod`
- **ENCYCLOPEDIA.md** - the full reference with every method, hook, and FAQ answer I could think of

## Repo layout

```
framework/        source files for QualiaMods itself
sdk/              everything for mod developers
```

## License

Use it however you want.
