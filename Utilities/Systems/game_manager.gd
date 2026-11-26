extends Node

enum GameState {
  MAIN_MENU, ## When the player is in the main menu
  PLAYING, ## When the player is actively playing a scenario
  IN_GAME_MENU, ## When the in-game menu is open (game is paused)
  IN_TECH_TREE, ## When the tech tree UI is open
  GAME_OVER, ## When the player has lost any scenario
  VICTORY, ## When the player successfully completes any scenario
  ALL_DONE ## Represents the state after the final scenario is completed
}

const DIALOG_BLOCKING_STATES := [GameState.IN_GAME_MENU, GameState.IN_TECH_TREE]

# Variables and signals for general game state.
var current_state: GameState = GameState.MAIN_MENU
var current_speed_multiplier: float = 1.0
var _dialogic_paused_by_game_state := false
var _attempt_active := false
var _attempt_start_tech: Dictionary = {}
var _attempt_start_survivors: Dictionary = {}

signal game_state_changed(new_state: GameState)
signal speed_changed(new_speed: float)

# Variables and signals for tutorial and scenario events.
var was_enemy_attacked: bool = false
var has_enemy_appeared: bool = false
var was_building_placed: bool = false
var has_wave_cleared: bool = false

signal enemy_attacked ## Emitted when the player clicks to attack an enemy; re-emitted from PlayerInputController
signal enemy_appeared ## Emitted when an enemy is visible to the player for the first time
signal building_placed ## Emitted when a building is successfully placed in the world; re-emitted from BuildingPlacement
signal wave_cleared ## Emitted when a wave is fully cleared; proxied from ScenarioManager.wave_changed


func _ready():
  enemy_attacked.connect(func(): was_enemy_attacked = true)
  enemy_appeared.connect(func(): has_enemy_appeared = true)
  building_placed.connect(func(): was_building_placed = true)
  wave_cleared.connect(func(): has_wave_cleared = true)


func set_game_state(new_state: GameState):
    if current_state != new_state:
        current_state = new_state
        _sync_dialogic_pause(new_state)
        game_state_changed.emit(new_state)
        MyLogger.info("GameManager", "Game state changed to: %s" % GameState.keys()[new_state])

func _sync_dialogic_pause(new_state: GameState) -> void:
    if new_state in DIALOG_BLOCKING_STATES:
        if not Dialogic.paused:
            Dialogic.paused = true
            _dialogic_paused_by_game_state = true
    elif _dialogic_paused_by_game_state:
        Dialogic.paused = false
        _dialogic_paused_by_game_state = false

func is_playing() -> bool:
    return current_state == GameState.PLAYING

func pause_game():
    MyLogger.debug("GameManager", "Pausing game...")
    get_tree().paused = true
    speed_changed.emit(0.0)

func resume_game():
    MyLogger.debug("GameManager", "Resuming game...")
    get_tree().paused = false
    speed_changed.emit(current_speed_multiplier)

func toggle_pause():
    MyLogger.debug("GameManager", "Toggling pause state...")
    var tree = get_tree()
    tree.paused = not tree.paused
    speed_changed.emit(0.0 if tree.paused else current_speed_multiplier)

func is_paused() -> bool:
    return get_tree().paused

func set_game_speed(speed_multiplier: float):
    if speed_multiplier <= 0:
        MyLogger.error("GameManager", "Speed multiplier must be greater than 0.")
        return

    if speed_multiplier != current_speed_multiplier:
        current_speed_multiplier = speed_multiplier
        speed_changed.emit(speed_multiplier)
        Engine.time_scale = speed_multiplier
        MyLogger.info("GameManager", "Game speed changed to: %.1fx" % speed_multiplier)

func get_game_speed() -> float:
    return current_speed_multiplier


func toggle_in_game_menu():
    MyLogger.debug("GameManager", "Toggling in-game menu...")
    match current_state:
        GameState.IN_GAME_MENU:
            set_game_state(GameState.PLAYING)
        GameState.IN_TECH_TREE:
            set_game_state(GameState.PLAYING)
        GameState.PLAYING:
            pause_game()
            set_game_state(GameState.IN_GAME_MENU)

## Called before the new scenario enters the tree and assigns survivor profiles.
func begin_scenario_attempt() -> void:
  _attempt_start_tech = TechTreeManager.get_save_data().duplicate(true)
  _attempt_start_survivors = SurvivorNameManager.get_save_data()
  _attempt_active = true
  ScenarioManager.reset_attempt()
  StatsManager.reset_attempt()
  CurrencyManager.reset_scrap()

## An unsuccessful attempt keeps only lifetime activity. Restore attempt-local
## changes from memory even if writing the save fails or no slot is loaded.
func abandon_scenario_attempt() -> void:
  if not _attempt_active:
    return
  _attempt_active = false
  TechTreeManager.load_data(_attempt_start_tech)
  SurvivorNameManager.load_data(_attempt_start_survivors)
  _attempt_start_tech.clear()
  _attempt_start_survivors.clear()
  CurrencyManager.reset_scrap()
  AchievementManager.refresh_progress()
  SaveManager.save_attempt_activity()

## Called after scenario rewards and records are finalized.
func finish_scenario_attempt(result: GameState) -> void:
  if result == GameState.VICTORY:
    _attempt_active = false
    _attempt_start_tech.clear()
    _attempt_start_survivors.clear()
    AchievementManager.refresh_progress()
    if SaveManager.current_save_slot > 0:
      SaveManager.save_current_slot()
  else:
    abandon_scenario_attempt()
  set_game_state(result)
  pause_game()

## Restarts the current scenario from scratch without losing lifetime activity.
func restart_scenario() -> void:
  MyLogger.info("GameManager", "Restarting current scenario")
  var scenario_id = ScenarioManager.get_current_scenario_id()
  abandon_scenario_attempt()
  ScenarioManager.clear_current_scenario()
  ScenarioManager.set_current_scenario_id(scenario_id)
  reset_tutorial_flags()
  resume_game()
  set_game_state(GameState.PLAYING)

  # Reload the game scene so all scene-level nodes are freshly instantiated
  var game_scene_path = "res://Stages/Game/main/main.tscn"
  var error = get_tree().change_scene_to_file(game_scene_path)
  if error != OK:
    MyLogger.error("GameManager", "Failed to reload game scene: %s (Error: %d)" % [game_scene_path, error])

## Quitting through the game's menu keeps lifetime activity, not a live attempt.
func quit_game() -> void:
  abandon_scenario_attempt()
  get_tree().quit()

## Returns to the main menu from any game state
func return_to_main_menu():
  MyLogger.info("GameManager", "Returning to main menu")
  abandon_scenario_attempt()
  resume_game() # Ensure the game is unpaused
  set_game_state(GameState.MAIN_MENU)
  
  # Clear the current scenario in ScenarioManager
  ScenarioManager.clear_current_scenario()

  reset_tutorial_flags()
  
  # Load the main menu scene
  var main_menu_path = "res://Stages/UI/main_menu/main_menu.tscn"
  var error = get_tree().change_scene_to_file(main_menu_path)
  if error != OK:
    MyLogger.error("GameManager", "Failed to load main menu scene: %s (Error: %d)" % [main_menu_path, error])


# Clear flags for the tutorial and scenario events so they can be re-triggered
func reset_tutorial_flags():
  was_enemy_attacked = false
  was_building_placed = false
  has_enemy_appeared = false
  has_wave_cleared = false
