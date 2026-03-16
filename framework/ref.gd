extends Node


@onready var main: Main = get_tree().get_root().get_node("Main")
@onready var world: LucidBlocksWorld = get_tree().get_root().get_node("Main/World")
@onready var weather: Weather = get_tree().get_root().get_node("Main/World/Weather")
@onready var entity_spawner: EntitySpawner = get_tree().get_root().get_node("Main/World/EntitySpawner")
@onready var player: Player = get_tree().get_root().get_node("Main/Player")
@onready var player_camera: PlayerCamera = get_tree().get_root().get_node("Main/Player/%Camera3D")

@onready var sun: Sun = get_tree().get_root().get_node("Main/World/Sun")
@onready var sun_box: SunBox = get_tree().get_root().get_node("Main/World/SunBoxOffset/SunBox")
@onready var sky: SkyPlane = get_tree().get_root().get_node("Main/World/SkyBoxOffset/Sky")

@onready var save_file_manager: SaveFileManager = get_tree().get_root().get_node("Main/%SaveFileManager")
@onready var audio_manager: AudioManager = get_tree().get_root().get_node("Main/AudioManager")
@onready var ambience_manager: AudioManager = get_tree().get_root().get_node("Main/AudioManager/AmbienceManager")
@onready var biome_music_manager: BiomeMusicManager = get_tree().get_root().get_node("Main/%BiomeMusicManager")
@onready var preserve_node_manager: PreserveNodeManager = get_tree().get_root().get_node("Main/%PreserveNodeManager")
@onready var plot_manager: PlotManager = get_tree().get_root().get_node("Main/%PlotManager")
@onready var boss_manager: BossManager = get_tree().get_root().get_node("Main/%BossManager")
@onready var discovery_manager: DiscoveryManager = get_tree().get_root().get_node("Main/%DiscoveryManager")

@onready var player_inventory: Inventory = get_tree().get_root().get_node("Main/%Player/%Inventory")
@onready var player_hotbar: Inventory = get_tree().get_root().get_node("Main/%Player/%Hotbar")
@onready var player_fuser: Fuser = get_tree().get_root().get_node("Main/%Player/%Fuser")
@onready var player_fusion_source: Inventory = get_tree().get_root().get_node("Main/%Player/%FusionSource")
@onready var player_fusion_result: Inventory = get_tree().get_root().get_node("Main/%Player/%FusionResult")
@onready var player_equipment: Inventory = get_tree().get_root().get_node("Main/%Player/%Equipment")

@onready var ui: CanvasLayer = get_tree().get_root().get_node("Main/UI")
@onready var cutscene_layer: CanvasLayer = get_tree().get_root().get_node("Main/CutsceneLayer")
@onready var trans: Transition = get_tree().get_root().get_node("Main/TransitionLayer/Transition")
@onready var environment: MainEnvironment = get_tree().get_root().get_node("Main/World/MainEnvironment")
@onready var water_filter: WaterFilter = get_tree().get_root().get_node("Main/UI/WaterFilter")
@onready var game_menu: GameMenu = get_tree().get_root().get_node("Main/UI/GameMenu")
@onready var cutscene_menu: CutsceneMenu = get_tree().get_root().get_node("Main/UI/CutsceneMenu")
@onready var world_edit_menu: WorldEditMenu = get_tree().get_root().get_node("Main/UI/WorldEditMenu")
@onready var level_up_menu: LevelUpMenu = get_tree().get_root().get_node("Main/UI/LevelUpMenu")
@onready var settings_menu: SettingsMenu = get_tree().get_root().get_node("Main/UI/SettingsMenu")
@onready var bead_get_menu: BeadGetMenu = get_tree().get_root().get_node("Main/UI/BeadGetMenu")
@onready var dither_filter: DitheringFilter = get_tree().get_root().get_node("Main/UI/%DitheringFilter")
@onready var shader_loader: ShaderLoader = get_tree().get_root().get_node("Main/ShaderLoader")
@onready var splash_layer: CanvasLayer = get_tree().get_root().get_node("Main/SplashLayer")
@onready var on_screen_keyboard: Control = get_tree().get_root().get_node("Main/%OnscreenKeyboard")
@onready var save_notifier: SaveNotifier = get_tree().get_root().get_node("Main/%SaveNotifier")


# inject qualiamods into the existing ModLoader node
func _ready() -> void:
	var qm_script = load("res://mods/qualiamods/qualiamods.gd")
	if qm_script:
		var mod_loader_node = get_node_or_null("/root/ModLoader")
		if mod_loader_node:
			mod_loader_node.set_script(qm_script)
			mod_loader_node._bootstrap()
			print("[QualiaMods] Bootstrap complete.")
		else:
			printerr("[QualiaMods] ModLoader node not found!")
	else:
		printerr("[QualiaMods] Could not load qualiamods.gd")
