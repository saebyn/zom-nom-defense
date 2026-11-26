extends Node

## Manages achievement tracking, unlocking, and persistence
## Tracks achievement progress and emits signals when achievements are unlocked
## Connects to StatsManager and CurrencyManager to monitor game stats
## Implements SaveableSystem interface for centralized save management
##
## Usage:
##   # Achievements are automatically loaded from Config/Achievements/
##   # Connect to signals to respond to achievement unlocks
##   AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
##
##   # Check achievement status
##   var progress = AchievementManager.get_achievement_progress("first_blood")
##   var is_unlocked = AchievementManager.is_achievement_unlocked("first_blood")

# Achievement storage
var achievements: Dictionary = {} # id (String) -> Resource_Achievement
var achievement_states: Dictionary = {} # id (String) -> AchievementState

# Signals
signal achievement_unlocked(achievement: Resource_Achievement)
signal achievement_progress_updated(achievement: Resource_Achievement, progress: float)
signal achievements_loaded()

# Internal achievement state tracking
class AchievementState:
  var unlocked: bool = false
  var progress: float = 0.0
  var unlock_date: String = "" # ISO 8601 format
  
  func _init(p_unlocked: bool = false, p_progress: float = 0.0, p_unlock_date: String = ""):
    unlocked = p_unlocked
    progress = p_progress
    unlock_date = p_unlock_date
  
  func to_dict() -> Dictionary:
    return {
      "unlocked": unlocked,
      "progress": progress,
      "unlock_date": unlock_date
    }
  
  static func from_dict(data: Dictionary) -> AchievementState:
    return AchievementState.new(
      data.get("unlocked", false),
      data.get("progress", 0.0),
      data.get("unlock_date", "")
    )

func _ready():
  MyLogger.info("AchievementManager", "Achievement system initialized")
  
  # Register with SaveManager
  SaveManager.register_system(self )
  
  # Load all achievements from Config/Achievements/
  _load_achievements()
  
  # Connect to existing systems for stat tracking
  _connect_to_systems.call_deferred()

## Load all achievement resources from the Config/Achievements/ folder
func _load_achievements() -> void:
  var achievements_dir = "res://Config/Achievements/"
  var dir = DirAccess.open(achievements_dir)
  
  if not dir:
    MyLogger.error("AchievementManager", "Failed to open achievements directory: %s" % achievements_dir)
    return
  
  dir.list_dir_begin()
  var file_name = dir.get_next()
  var loaded_count = 0
  
  while file_name != "":
    # Only load .tres resource files
    if file_name.ends_with(".tres"):
      var file_path = achievements_dir + file_name
      var achievement = load(file_path) as Resource_Achievement
      
      if achievement and achievement.is_valid():
        achievements[achievement.id] = achievement
        
        # Initialize state if not already present
        if not achievement.id in achievement_states:
          achievement_states[achievement.id] = AchievementState.new()
        
        loaded_count += 1
        MyLogger.debug("AchievementManager", "Loaded achievement: %s" % achievement.name)
      elif achievement:
        MyLogger.warn("AchievementManager", "Invalid achievement resource: %s" % file_name)
    
    file_name = dir.get_next()
  
  dir.list_dir_end()
  
  MyLogger.info("AchievementManager", "Loaded %d achievements" % loaded_count)

## Connect to game systems for tracking achievement progress
func _connect_to_systems() -> void:
  # Connect to StatsManager for stat-based achievements
  if StatsManager:
    StatsManager.stats_updated.connect(refresh_progress)
    MyLogger.debug("AchievementManager", "Connected to StatsManager")
  else:
    MyLogger.error("AchievementManager", "StatsManager not found!")
  
  # Connect to CurrencyManager for level-based achievements
  if CurrencyManager:
    CurrencyManager.level_up.connect(_on_level_up)
    CurrencyManager.scrap_earned.connect(_on_scrap_earned)
    CurrencyManager.xp_earned.connect(_on_xp_earned)
    MyLogger.debug("AchievementManager", "Connected to CurrencyManager")
  else:
    MyLogger.error("AchievementManager", "CurrencyManager not found!")

## Check all achievements for progress and unlocks
func refresh_progress() -> void:
  for achievement_id in achievements:
    _check_achievement(achievement_id)

## Check a specific achievement for unlock conditions
func _check_achievement(achievement_id: String) -> void:
  var achievement = achievements.get(achievement_id)
  if not achievement:
    return
  
  var state = achievement_states.get(achievement_id)
  if not state:
    state = AchievementState.new()
    achievement_states[achievement_id] = state
  
  # Don't check already unlocked achievements
  if state.unlocked:
    return
  
  var old_progress = state.progress
  var current_progress = _calculate_achievement_progress(achievement)
  
  # Update progress
  state.progress = current_progress
  
  # Emit progress update signal if progress changed and achievement is not hidden (or already unlocked)
  if current_progress != old_progress and not achievement.hidden:
    achievement_progress_updated.emit(achievement, current_progress)
  
  # Check if achievement is now unlocked
  if current_progress >= 1.0:
    _unlock_achievement(achievement_id)

## Calculate progress (0.0 to 1.0) for an achievement
func _calculate_achievement_progress(achievement: Resource_Achievement) -> float:
  if achievement.use_multiple_conditions:
    return _calculate_multiple_conditions_progress(achievement)
  else:
    return _calculate_single_condition_progress(achievement)

## Calculate progress for single condition achievements
func _calculate_single_condition_progress(achievement: Resource_Achievement) -> float:
  var current_value = _get_stat_value(achievement.unlock_condition_type, achievement.condition_target)
  var threshold = float(achievement.threshold)
  
  if threshold <= 0:
    return 0.0
  
  return clampf(current_value / threshold, 0.0, 1.0)

## Calculate progress for multiple condition achievements
func _calculate_multiple_conditions_progress(achievement: Resource_Achievement) -> float:
  if achievement.conditions.is_empty():
    return 0.0
  
  if achievement.condition_logic == Resource_Achievement.ConditionLogic.AND:
    # For AND logic, progress is the minimum of all conditions
    var min_progress = 1.0
    for condition in achievement.conditions:
      var current_value = _get_stat_value(condition.condition_type, condition.condition_target)
      var threshold = float(condition.threshold)
      var condition_progress = clampf(current_value / threshold, 0.0, 1.0) if threshold > 0 else 0.0
      min_progress = min(min_progress, condition_progress)
    return min_progress
  else: # OR logic
    # For OR logic, progress is the maximum of all conditions
    var max_progress = 0.0
    for condition in achievement.conditions:
      var current_value = _get_stat_value(condition.condition_type, condition.condition_target)
      var threshold = float(condition.threshold)
      var condition_progress = clampf(current_value / threshold, 0.0, 1.0) if threshold > 0 else 0.0
      max_progress = max(max_progress, condition_progress)
    return max_progress

## Get the current value of a stat for achievement tracking
func _get_stat_value(condition_type: Resource_Achievement.ConditionType, target: String = "") -> float:
  if not StatsManager or not CurrencyManager:
    return 0.0

  match condition_type:
    Resource_Achievement.ConditionType.ENEMIES_DEFEATED_TOTAL:
      return float(StatsManager.get_enemies_defeated_total())
    Resource_Achievement.ConditionType.ENEMIES_DEFEATED_BY_TYPE:
      return float(StatsManager.get_enemies_defeated_by_type(target))
    Resource_Achievement.ConditionType.CLICKS_PERFORMED:
      return float(StatsManager.get_clicks_performed())
    Resource_Achievement.ConditionType.HAND_KILLS:
      return float(StatsManager.get_enemies_defeated_by_hand())
    Resource_Achievement.ConditionType.ENEMY_CLICKS:
      return float(StatsManager.get_enemy_clicks())
    Resource_Achievement.ConditionType.SCRAP_EARNED:
      return float(StatsManager.get_total_scrap_earned())
    Resource_Achievement.ConditionType.BUILDINGS_PLACED:
      return float(StatsManager.get_buildings_placed_total())
    Resource_Achievement.ConditionType.PLAYER_LEVEL_REACHED:
      return float(CurrencyManager.get_level())
    Resource_Achievement.ConditionType.WAVE_COMPLETED:
      return float(StatsManager.get_max_waves_completed())
    Resource_Achievement.ConditionType.GAME_SCENARIO_REACHED:
      # Get the highest completed scenario number
      var completed_scenarios = ScenarioManager.completed_scenarios
      var highest = 0
      for scenario_id in completed_scenarios:
        var num = int(scenario_id.replace("scenario_", ""))
        if num > highest:
          highest = num
      return float(highest)
  
  return 0.0

## Unlock an achievement
func _unlock_achievement(achievement_id: String) -> void:
  var achievement = achievements.get(achievement_id)
  if not achievement:
    MyLogger.warn("AchievementManager", "Attempted to unlock non-existent achievement: %s" % achievement_id)
    return
  
  var state = achievement_states.get(achievement_id)
  if not state:
    state = AchievementState.new()
    achievement_states[achievement_id] = state
  
  # Don't unlock twice
  if state.unlocked:
    return
  
  # Mark as unlocked
  state.unlocked = true
  state.progress = 1.0
  state.unlock_date = Time.get_datetime_string_from_system(false, true)
  
  MyLogger.info("AchievementManager", "Achievement unlocked: %s" % achievement.name)
  
  # Emit unlock signal (notification UI will play the sound)
  achievement_unlocked.emit(achievement)
  
  # If achievement was hidden, now emit progress update
  if achievement.hidden:
    achievement_progress_updated.emit(achievement, 1.0)

## Event handlers for stat changes

func _on_level_up(_new_level: int) -> void:
  refresh_progress()

func _on_scrap_earned(_amount: int) -> void:
  refresh_progress()

func _on_xp_earned(_amount: int) -> void:
  refresh_progress()

## Public API methods

## Check if an achievement is unlocked
func is_achievement_unlocked(achievement_id: String) -> bool:
  var state = achievement_states.get(achievement_id)
  return state.unlocked if state else false

## Get achievement progress (0.0 to 1.0)
func get_achievement_progress(achievement_id: String) -> float:
  var state = achievement_states.get(achievement_id)
  return state.progress if state else 0.0

## Get all unlocked achievements
func get_unlocked_achievements() -> Array[Resource_Achievement]:
  var unlocked: Array[Resource_Achievement] = []
  for achievement_id in achievements:
    if is_achievement_unlocked(achievement_id):
      unlocked.append(achievements[achievement_id])
  return unlocked

## Get all achievements (including locked ones)
func get_all_achievements() -> Array[Resource_Achievement]:
  var all_achievements: Array[Resource_Achievement] = []
  for achievement in achievements.values():
    all_achievements.append(achievement)
  return all_achievements

## Get achievement by ID
## Returns the Resource_Achievement for the given achievement_id, or null if not found.
## If the achievement_id does not exist, returns null and logs a warning.
func get_achievement(achievement_id: String) -> Resource_Achievement:
  if not achievements.has(achievement_id):
    MyLogger.warn("AchievementManager", "Requested achievement_id '%s' does not exist." % achievement_id)
    return null
  return achievements.get(achievement_id)

## SaveableSystem Interface Implementation

## Get unique save key for this system
func get_save_key() -> String:
  return "achievements"

## Get saveable state as dictionary
func get_save_data() -> Dictionary:
  # Convert achievement states to dictionary format
  var states_dict = {}
  for achievement_id in achievement_states:
    states_dict[achievement_id] = achievement_states[achievement_id].to_dict()
  
  return {
    "states": states_dict
  }

## Load data from saved state
func load_data(data: Dictionary) -> void:
  # Load achievement states
  var states_dict = data.get("states", {})
  if states_dict is Dictionary:
    achievement_states.clear()
    for achievement_id in states_dict:
      var state_data = states_dict[achievement_id]
      if state_data is Dictionary:
        achievement_states[achievement_id] = AchievementState.from_dict(state_data)
  
  MyLogger.info("AchievementManager", "Achievement states loaded - %d achievements tracked" % achievement_states.size())
  achievements_loaded.emit()

## Reset to default state (for new game)
func reset_data() -> void:
  achievement_states.clear()
  
  # Re-initialize states for all loaded achievements
  for achievement_id in achievements:
    achievement_states[achievement_id] = AchievementState.new()
  
  MyLogger.info("AchievementManager", "Achievement states reset")
