extends Control

class_name UI_ScenarioSelect

## Scenario selection UI that displays available scenarios and handles scenario loading
## Shows completion status and best times, and enforces unlock progression

@onready var scenario_container = $MarginContainer/VBoxContainer/ScrollContainer/ScenarioContainer
@onready var back_button = $MarginContainer/VBoxContainer/TopBar/BackButton

# Scenario card scene to be instantiated for each scenario
const ScenarioCardScene = preload("res://Stages/UI/scenario_select/scenario_card.tscn")

func _ready():
  # Keep the active Save Slot or restore the startup selection.
  SaveManager.initialize_active_slot()
  
  # Set the game state
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  MyLogger.info("ScenarioSelect", "Scenario selection screen loaded")
  
  # Make sure the game is not paused
  get_tree().paused = false
  
  # Connect signals
  back_button.pressed.connect(_on_back_button_pressed)
  
  # Populate scenario list
  _populate_scenarios()

## Populate the scenario container with scenario cards
func _populate_scenarios():
  # Clear existing children (if any)
  for child in scenario_container.get_children():
    child.queue_free()
  
  # Get all scenario IDs and create a card for each
  var scenario_ids = ScenarioManager.get_all_scenario_ids()
  
  for scenario_id in scenario_ids:
    var scenario_card = ScenarioCardScene.instantiate()
    scenario_container.add_child(scenario_card)
    
    # Configure the card
    var metadata = ScenarioManager.get_scenario_metadata(scenario_id)
    var is_unlocked = ScenarioManager.is_scenario_unlocked(scenario_id)
    var is_completed = ScenarioManager.is_scenario_completed(scenario_id)
    var best_time = ScenarioManager.get_best_time(scenario_id)
    
    scenario_card.configure(
      scenario_id,
      metadata.get("name", "Unknown Scenario"),
      metadata.get("description", ""),
      is_unlocked,
      is_completed,
      best_time
    )
    
    # Connect the scenario selection signal
    scenario_card.scenario_selected.connect(_on_scenario_selected)

## Handle scenario selection
func _on_scenario_selected(scenario_id: String):
  var metadata = ScenarioManager.get_scenario_metadata(scenario_id)
  var scene_path = metadata.get("scene_path", "")
  
  # Check if scenario is unlocked
  if not ScenarioManager.is_scenario_unlocked(scenario_id):
    MyLogger.warn("ScenarioSelect", "Attempted to select locked scenario: %s" % scenario_id)
    return
  
  # Check if scene path exists
  if scene_path.is_empty():
    MyLogger.error("ScenarioSelect", "Scenario %s has no scene path configured" % scenario_id)
    # Show a message to the user
    _show_scenario_unavailable_message(metadata.get("name", scenario_id))
    return
  
  # Set the current scenario in ScenarioManager
  MyLogger.info("ScenarioSelect", "Setting scenario: %s (scene: %s)" % [scenario_id, scene_path])
  ScenarioManager.set_current_scenario_id(scenario_id)
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Always load the main game scene, which will dynamically load the selected scenario
  var game_scene_path = "res://Stages/Game/main/main.tscn"
  MyLogger.info("ScenarioSelect", "Loading main game scene: %s" % game_scene_path)
  
  var error = get_tree().change_scene_to_file(game_scene_path)
  if error != OK:
    MyLogger.error("ScenarioSelect", "Failed to load game scene: %s (Error: %d)" % [game_scene_path, error])

## Show a message when scenario is not yet available
func _show_scenario_unavailable_message(scenario_name: String):
  # For now, just log it - could be enhanced with a popup dialog in the future
  MyLogger.info("ScenarioSelect", "Scenario '%s' is coming soon!" % scenario_name)

## Handle back button press - return to main menu
func _on_back_button_pressed():
  MyLogger.info("ScenarioSelect", "Back button pressed - returning to main menu")
  var main_menu_path = "res://Stages/UI/main_menu/main_menu.tscn"
  var error = get_tree().change_scene_to_file(main_menu_path)
  if error != OK:
    MyLogger.error("ScenarioSelect", "Failed to load main menu: %s (Error: %d)" % [main_menu_path, error])
