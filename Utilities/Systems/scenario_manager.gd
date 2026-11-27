extends Node

## Manages all scenario-related state: runtime session state and persistent progression
## Implements SaveableSystem interface for centralized save management
## 
## Runtime State (per gameplay session):
## - Current scenario being played
## - Current wave within that scenario
## 
## Persistent State (saved across sessions):
## - Completed scenarios
## - Best times per scenario
## - Scenario unlocking logic

const DEFAULT_SCENARIO_ID: String = "scenario_1" ## Default scenario to start with

# Runtime state (resets each attempt)
var current_scenario_id: String = "" # Currently active scenario (e.g., "scenario_1")
var current_wave: int = 0 # Current wave number within the active scenario
var last_scenario_stats: Dictionary = {} # Stats from the last completed/failed scenario for UI display

# Persistent state (saved across sessions)
var completed_scenarios: Array[String] = [] # Array of completed scenario IDs ["scenario_1", "scenario_2"]
var scenario_best_times: Dictionary = {} # scenario_id -> best time in seconds

# Scenario metadata (can be extended to load from resources in the future)
var scenario_metadata: Dictionary = {
  "scenario_1": {
    "name": "Car Defense",
    "scene_path": "res://Stages/Scenarios/scenario_1.tscn",
    "description": "Defend a person on top of a car.",
    "prerequisite": null, # No prerequisite for the first scenario
  },
  "scenario_2": {
    "name": "Campfire Survivors",
    "scene_path": "res://Stages/Scenarios/scenario_2.tscn",
    "description": "Protect two survivors next to a campfire.",
    "prerequisite": "scenario_1" # Must complete scenario_1 to unlock
  },
  "scenario_4": {
    "name": "Pool Party",
    "scene_path": "res://Stages/Scenarios/scenario_pool_party.tscn",
    "description": "Defend survivors in an inflatable pool.",
    "prerequisite": "scenario_2",
  },

  "scenario_test": {
    "name": "Test Scenario",
    "scene_path": "res://Stages/Scenarios/scenario_test.tscn",
    "description": "A test scenario for debugging purposes.",
    "prerequisite": null # No prerequisite
  },
}

# Signals - Persistent progression
signal scenario_completed(scenario_id: String)
signal scenario_unlocked(scenario_id: String)
signal progression_loaded()

# Signals - Runtime state
signal scenario_started(scenario_id: String)
signal wave_changed(scenario_id: String, wave: int)
signal scenario_ended(scenario_id: String)

func _ready():
  # Register with SaveManager
  SaveManager.register_system(self)
  
  MyLogger.info("ScenarioManager", "Scenario Manager initialized")

func instantiate_scenario():
  if current_scenario_id.is_empty():
    current_scenario_id = DEFAULT_SCENARIO_ID

  var metadata = get_scenario_metadata(current_scenario_id)
  var scene_path = metadata.get("scene_path", "")
  if scene_path.is_empty():
    MyLogger.error("ScenarioManager", "No scene path defined for scenario: %s" % current_scenario_id)
    return null

  var scenario_scene: PackedScene = load(scene_path)
  if not scenario_scene:
    MyLogger.error("ScenarioManager", "Failed to load scenario scene: %s" % scene_path)
    return null

  var instance := scenario_scene.instantiate()

  _handle_scenario_loaded(instance)

  return instance

func _handle_scenario_loaded(scenario: Stage_Scenario) -> void:
  MyLogger.info("ScenarioManager", "Waiting for scenario %s to load..." % current_scenario_id)
  await scenario.ready
  scenario_started.emit(current_scenario_id)
  MyLogger.info("ScenarioManager", "Scenario %s instantiated and ready" % current_scenario_id)

## Runtime State Management

## Set the current scenario being played
func set_current_scenario_id(scenario_id: String) -> void:
  if current_scenario_id != scenario_id:
    current_scenario_id = scenario_id
    current_wave = 0 # Reset wave when changing scenarios
    MyLogger.info("ScenarioManager", "Current scenario set to: %s" % scenario_id)
  else:
    MyLogger.debug("ScenarioManager", "Scenario ID %s is already the current scenario" % scenario_id)

## Get the current scenario ID being played
func get_current_scenario_id() -> String:
  return current_scenario_id

## Clear the current scenario (e.g., when returning to menu)
func clear_current_scenario() -> void:
  if not current_scenario_id.is_empty():
    var old_scenario = current_scenario_id
    current_scenario_id = ""
    current_wave = 0
    scenario_ended.emit(old_scenario)
    MyLogger.info("ScenarioManager", "Cleared current scenario: %s" % old_scenario)

## Reset attempt-local state, including on a replay of the same scenario.
func reset_attempt() -> void:
  current_wave = 0
  last_scenario_stats.clear()

## Set the current wave number (within the current scenario)
func set_current_wave(wave: int) -> void:
  if current_wave != wave:
    current_wave = wave
    wave_changed.emit(current_scenario_id, wave)
    MyLogger.info("ScenarioManager", "Wave changed to %d in scenario %s" % [wave, current_scenario_id])

## Get the current wave number
func get_current_wave() -> int:
  return current_wave

## Persistent Progression Management

## Mark a scenario as completed
func mark_scenario_complete(scenario_id: String, time: float = 0.0) -> void:
  if scenario_id not in completed_scenarios:
    completed_scenarios.append(scenario_id)
    scenario_completed.emit(scenario_id)
    MyLogger.info("ScenarioManager", "Scenario %s marked as complete" % scenario_id)
    
    # Check if we unlocked the next scenario
    var next_scenario = _get_next_scenario_id(scenario_id)
    if next_scenario and is_scenario_unlocked(next_scenario):
      scenario_unlocked.emit(next_scenario)
  
  # Update best time (if better or first time)
  if time > 0.0:
    if scenario_id not in scenario_best_times or time < scenario_best_times[scenario_id]:
      scenario_best_times[scenario_id] = time
      MyLogger.info("ScenarioManager", "New best time for %s: %.2f seconds" % [scenario_id, time])

## Check if a scenario is unlocked
func is_scenario_unlocked(scenario_id: String) -> bool:
  if not scenario_metadata.has(scenario_id):
    return false

  if ProjectSettings.get_setting("zom_nom_defense/debug/unlock_all_scenarios"):
    return true

  var prerequisite_id := get_unlock_requirement(scenario_id)

  if prerequisite_id == "":
    return true

  return completed_scenarios.has(prerequisite_id)


## Check if a scenario is completed
func is_scenario_completed(scenario_id: String) -> bool:
  return completed_scenarios.has(scenario_id)

## Get best time for a scenario (0.0 if not played)
func get_best_time(scenario_id: String) -> float:
  return scenario_best_times.get(scenario_id, 0.0)

## Get scenario metadata
func get_scenario_metadata(scenario_id: String) -> Dictionary:
  return scenario_metadata.get(scenario_id, {})

## Get all available scenario IDs
func get_all_scenario_ids() -> Array[String]:
  var ids: Array[String] = []
  for key in scenario_metadata.keys():
    ids.append(key)
  ids.sort()
  return ids

## Get the previous scenario requirement for unlocking
func get_unlock_requirement(scenario_id: String) -> String:
  var scenario := get_scenario_metadata(scenario_id)
  var prerequisite_id = scenario.get("prerequisite")
  if prerequisite_id == null:
    return ""
  else:
    return prerequisite_id


## Helper to get next scenario ID
func _get_next_scenario_id(scenario_id: String) -> String:
  # XXX note: This will assume that there is only one next scenario in sequence.
  # If we have branching scenarios in the future, this will need to be updated.
  for candidate_scenario_key in scenario_metadata.keys():
    var prereq = scenario_metadata[candidate_scenario_key].get("prerequisite")
    if prereq == scenario_id:
      return candidate_scenario_key

  return "" # No next scenario found

## SaveableSystem Interface Implementation

## Get unique save key for this system
## Note: Kept as "level_progression" for backwards compatibility with existing save files
func get_save_key() -> String:
  return "level_progression"

## Get saveable state as dictionary
func get_save_data() -> Dictionary:
  return {
    "completed_scenarios": completed_scenarios,
    "scenario_best_times": scenario_best_times,
  }

## Load data from saved state
func load_data(data: Dictionary) -> void:
  # Load the data with fallbacks
  var loaded_completed: Array = data.get("completed_scenarios", [])
  
  # Backwards compatibility: migrate from old "completed_levels" key
  if loaded_completed.is_empty() and data.has("completed_levels"):
    loaded_completed = data.get("completed_levels", [])
    MyLogger.info("ScenarioManager", "Migrating old save data from 'completed_levels' to 'completed_scenarios'")
  
  completed_scenarios.clear()
  for scenario in loaded_completed:
    if scenario is String:
      completed_scenarios.append(scenario)
  
  scenario_best_times = data.get("scenario_best_times", data.get("level_best_times", {}))
  
  MyLogger.info("ScenarioManager", "Scenario progression loaded - Completed: %s" % str(completed_scenarios))
  progression_loaded.emit()

## Reset to default state (for new game)
func reset_data() -> void:
  completed_scenarios.clear()
  scenario_best_times.clear()
  
  MyLogger.info("ScenarioManager", "Scenario progression reset")
