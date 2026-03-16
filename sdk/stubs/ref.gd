extends Node
## Ref - Stub for editor autocompletion.
## Do NOT include this file in your .pck.
## At runtime, Ref is a global autoload with typed references to game nodes.

## ── World & Environment ──
var main: Node                        ## Main scene root
var world: Node                       ## Main/World (LucidBlocksWorld)
var weather: Node                     ## Main/World/Weather
var entity_spawner: Node              ## Main/World/EntitySpawner - call stop_spawning() etc.
var sun: Node                         ## Main/World/Sun
var sun_box: Node                     ## Main/World/SunBoxOffset/SunBox
var sky: Node                         ## Main/World/SkyBoxOffset/Sky
var environment: Node                 ## Main/World/MainEnvironment - .environment for fog/sky/etc.

## ── Player ──
var player: Node                      ## Main/Player
var player_camera: Camera3D           ## Main/Player/%Camera3D
var player_inventory: Node            ## Main/%Player/%Inventory
var player_hotbar: Node               ## Main/%Player/%Hotbar
var player_fuser: Node                ## Main/%Player/%Fuser
var player_fusion_source: Node        ## Main/%Player/%FusionSource
var player_fusion_result: Node        ## Main/%Player/%FusionResult
var player_equipment: Node            ## Main/%Player/%Equipment

## ── Managers ──
var save_file_manager: Node           ## Main/%SaveFileManager - .settings_file, .loaded_file_register
var audio_manager: Node               ## Main/AudioManager
var ambience_manager: Node            ## Main/AudioManager/AmbienceManager
var biome_music_manager: Node         ## Main/%BiomeMusicManager
var preserve_node_manager: Node       ## Main/%PreserveNodeManager
var plot_manager: Node                ## Main/%PlotManager
var boss_manager: Node                ## Main/%BossManager
var discovery_manager: Node           ## Main/%DiscoveryManager
var shader_loader: Node               ## Main/ShaderLoader

## ── UI ──
var ui: CanvasLayer                   ## Main/UI
var cutscene_layer: CanvasLayer       ## Main/CutsceneLayer
var trans: Node                       ## Main/TransitionLayer/Transition - await trans.open() / close()
var water_filter: Node                ## Main/UI/WaterFilter
var game_menu: Node                   ## Main/UI/GameMenu
var cutscene_menu: Node               ## Main/UI/CutsceneMenu
var world_edit_menu: Node             ## Main/UI/WorldEditMenu
var level_up_menu: Node               ## Main/UI/LevelUpMenu
var settings_menu: Node               ## Main/UI/SettingsMenu - .saved signal, %FogQuality etc.
var bead_get_menu: Node               ## Main/UI/BeadGetMenu
var dither_filter: Node               ## Main/UI/%DitheringFilter
var splash_layer: CanvasLayer         ## Main/SplashLayer
var on_screen_keyboard: Control       ## Main/%OnscreenKeyboard
var save_notifier: Node               ## Main/%SaveNotifier
