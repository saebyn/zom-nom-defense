extends Control

class_name UI_MainMenu

## Main menu scene that handles navigation between different game states
## Sets the initial game state to MAIN_MENU and provides buttons for starting the game

const SettingsMenuScene = preload("res://Common/UI/settings_menu/settings_menu.tscn")
const TechTreeScene = preload("res://Stages/UI/tech_tree/tech_tree.tscn")
const AchievementListScene = preload("res://Stages/UI/achievement_list/achievement_list.tscn")
const PLAY_SELECT_SCENE := "res://Stages/UI/play_select/play_select.tscn"

var settings_menu = null
var tech_tree_ui = null
var achievement_list_ui = null

func _ready():
  # Set the initial game state when the main menu loads
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  MyLogger.info("MainMenu", "Main menu loaded")
  
  # Ensure a save slot is loaded (loads existing save or creates new game)
  # This must happen before clearing scenario state
  SaveManager.initialize_default_slot()
  
  # Clear any active scenario (we're at menu, not in gameplay)
  # This happens after loading the save to ensure clean menu state
  ScenarioManager.clear_current_scenario()
  
  # Make sure the game is not paused
  get_tree().paused = false
  
  # Create and add settings menu
  _setup_settings_menu()

func _setup_settings_menu():
  settings_menu = SettingsMenuScene.instantiate()
  add_child(settings_menu)
  settings_menu.closed.connect(_on_settings_menu_closed)

func _on_start_button_pressed():
  MyLogger.info("MainMenu", "Start button pressed - opening play mode selection")
  var error = get_tree().change_scene_to_file(PLAY_SELECT_SCENE)
  if error != OK:
    MyLogger.error("MainMenu", "Failed to load play mode selection: %s (Error: %d)" % [PLAY_SELECT_SCENE, error])

func _on_settings_button_pressed():
  MyLogger.info("MainMenu", "Settings button pressed")
  if settings_menu:
    settings_menu.show_menu()

func _on_settings_menu_closed():
  MyLogger.debug("MainMenu", "Settings menu closed")

func _on_tech_tree_button_pressed():
  MyLogger.info("MainMenu", "Tech Tree button pressed")
  _show_tech_tree()

func _show_tech_tree():
  # Create tech tree UI if not already open
  if tech_tree_ui == null:
    tech_tree_ui = TechTreeScene.instantiate()
    add_child(tech_tree_ui)
    tech_tree_ui.closed.connect(_on_tech_tree_closed)
  else:
    tech_tree_ui.visible = true

func _on_tech_tree_closed():
  MyLogger.debug("MainMenu", "Tech tree closed")
  tech_tree_ui = null

func _on_achievements_button_pressed():
  MyLogger.info("MainMenu", "Achievements button pressed")
  _show_achievements()

func _show_achievements():
  # Create achievement list UI if not already open
  if achievement_list_ui == null:
    achievement_list_ui = AchievementListScene.instantiate()
    add_child(achievement_list_ui)
    achievement_list_ui.closed.connect(_on_achievement_list_closed)
  else:
    achievement_list_ui.visible = true

func _on_achievement_list_closed():
  MyLogger.debug("MainMenu", "Achievement list closed")
  achievement_list_ui = null

func _on_load_game_button_pressed():
  MyLogger.info("MainMenu", "Load Game button pressed - transitioning to save slot selection")
  _show_save_slot_selection()

func _on_exit_button_pressed():
  MyLogger.info("MainMenu", "Exit button pressed - quitting game")
  get_tree().quit()

## Starts a specific scenario by loading the game scene
func _start_specific_scenario(scenario_id: String):
  ScenarioManager.set_current_scenario_id(scenario_id)
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Load the main game scene
  var game_scene_path = "res://Stages/Game/main/main.tscn"
  MyLogger.info("MainMenu", "Starting scenario %s - loading game scene: %s" % [scenario_id, game_scene_path])
  
  # Change to the game scene
  var error = get_tree().change_scene_to_file(game_scene_path)
  if error != OK:
    MyLogger.error("MainMenu", "Failed to load game scene: %s (Error: %d)" % [game_scene_path, error])

## Show scenario selection screen
func _show_scenario_select():
  var scenario_select_path = "res://Stages/UI/scenario_select/scenario_select.tscn"
  MyLogger.info("MainMenu", "Loading scenario select scene: %s" % scenario_select_path)
  
  var error = get_tree().change_scene_to_file(scenario_select_path)
  if error != OK:
    MyLogger.error("MainMenu", "Failed to load scenario select scene: %s (Error: %d)" % [scenario_select_path, error])

## Show save slot selection screen
func _show_save_slot_selection():
  var save_slot_path = "res://Stages/UI/save_slot_selection/save_slot_selection.tscn"
  MyLogger.info("MainMenu", "Loading save slot selection scene: %s" % save_slot_path)
  
  var error = get_tree().change_scene_to_file(save_slot_path)
  if error != OK:
    MyLogger.error("MainMenu", "Failed to load save slot selection scene: %s (Error: %d)" % [save_slot_path, error])
