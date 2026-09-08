extends Node

## Manages the player's resource system (scrap and XP)
## Handles earning and spending scrap, and tracking experience points throughout the game
## Implements SaveableSystem interface for centralized save management

@export var starting_scrap: int = 0 ## Amount of scrap player starts with at beginning of each scenario
@export var scrap_to_xp_conversion_rate: float = 2.0 ## How much scrap converts to 1 XP (e.g., 2.0 means 2 scrap = 1 XP)

var current_scrap: int = 0
var current_xp: int = 0
var current_level: int = 1

signal scrap_changed(new_amount: int)
signal scrap_earned(amount: int)
signal xp_changed(new_amount: int)
signal xp_earned(amount: int)
signal level_up(new_level: int)
signal progression_loaded()
signal display_pulse_requested(value_name: String, duration: float)

func _ready():
  # Register with SaveManager
  SaveManager.register_system(self)
  
  # Initialize with defaults (will be overridden if save is loaded)
  reset_data()
  
  scrap_changed.emit(current_scrap)
  xp_changed.emit(current_xp)
  GameManager.game_state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
  # Save progression only on victory (not on death/game over)
  if new_state == GameManager.GameState.VICTORY:
    SaveManager.save_current_slot()
  
  # Note: We no longer reset progression on MAIN_MENU - progression persists across sessions
  # Starting scrap for each level is handled by game logic, not here

## Add scrap to the player's total
func earn_scrap(amount: int) -> void:
  # do nothing if game state is not playing
  if not GameManager.is_playing():
    return

  if amount <= 0:
    return
  
  current_scrap += amount
  scrap_earned.emit(amount)
  scrap_changed.emit(current_scrap)
  MyLogger.info("Economy", "Earned %d scrap. Total: %d" % [amount, current_scrap])

## Add XP to the player's total
func earn_xp(amount: int) -> void:
  # do nothing if game state is not playing
  if not GameManager.is_playing():
    return

  if amount <= 0:
    return
  
  current_xp += amount
  xp_earned.emit(amount)
  xp_changed.emit(current_xp)
  MyLogger.info("Economy", "Earned %d XP. Total: %d" % [amount, current_xp])
  _check_level_up()

## Calculates the XP required for the next level.
## Scaling approach: Linear (XP required increases by a fixed amount per level).
## Formula: XP required = current_level * xp_per_level_base
## Currently, xp_per_level_base is set to 100, so each level requires 100 more XP than the previous.
## TODO To make this configurable in the future, adjust xp_per_level_base or implement an exponential formula.
@export var xp_per_level_base: int = 100 # Base XP required per level (configurable)
func _get_xp_for_next_level() -> int:
  return current_level * xp_per_level_base

## Check if player has enough XP to level up
func _check_level_up() -> void:
  var xp_for_next_level = _get_xp_for_next_level()
  while current_xp >= xp_for_next_level:
    current_xp -= xp_for_next_level
    current_level += 1
    level_up.emit(current_level)
    # Play level up sound
    AudioManager.play_sound_2d(Resource_SoundEffect.SoundEffect.PLAYER_LEVEL_UP)
    MyLogger.info("Economy", "Leveled up to level %d!" % current_level)
    xp_changed.emit(current_xp)
    xp_for_next_level = _get_xp_for_next_level()

## Spend scrap if player has enough
func spend_scrap(amount: int) -> bool:
  if amount <= 0:
    return false
  
  if current_scrap >= amount:
    current_scrap -= amount
    scrap_changed.emit(current_scrap)
    MyLogger.info("Economy", "Spent %d scrap. Remaining: %d" % [amount, current_scrap])
    return true
  else:
    MyLogger.warn("Economy", "Not enough scrap. Need %d but only have %d" % [amount, current_scrap])
    return false

## Get current scrap amount
func get_scrap() -> int:
  return current_scrap

## Get current XP amount
func get_xp() -> int:
  return current_xp

## Get current player level
func get_level() -> int:
  return current_level

## Request a HUD pulse for a currency value. This can be called from Dialogic.
func pulse_display(value_name: String, duration: float = 3.0) -> void:
  var normalized_name = value_name.to_lower()
  if normalized_name not in ["scrap", "level"]:
    push_warning("Unknown currency display value: %s" % value_name)
    return

  display_pulse_requested.emit(normalized_name, maxf(duration, 0.1))

## Convert all remaining scrap to XP and reset scrap to starting amount
## Returns a dictionary with conversion details: {scrap_converted, xp_gained, starting_scrap}
func convert_remaining_scrap_to_xp() -> Dictionary:
  var scrap_to_convert = current_scrap
  var xp_gained = 0
  
  if scrap_to_convert > 0 and scrap_to_xp_conversion_rate > 0:
    xp_gained = int(scrap_to_convert / scrap_to_xp_conversion_rate)
    
    if xp_gained > 0:
      earn_xp(xp_gained)
      MyLogger.info("Economy", "Converted %d scrap to %d XP (rate: %.1f:1)" % [scrap_to_convert, xp_gained, scrap_to_xp_conversion_rate])
    else:
      MyLogger.info("Economy", "Scrap amount (%d) too low to convert to XP (rate: %.1f:1)" % [scrap_to_convert, scrap_to_xp_conversion_rate])
  
  # Reset scrap to starting amount
  reset_scrap()
  
  return {
    "scrap_converted": scrap_to_convert,
    "xp_gained": xp_gained,
    "starting_scrap": starting_scrap
  }

## Reset scrap to starting amount for a new scenario
func reset_scrap() -> void:
  current_scrap = starting_scrap
  scrap_changed.emit(current_scrap)
  MyLogger.info("Economy", "Scrap reset to starting amount: %d" % starting_scrap)

## Get XP required for next level
func get_xp_for_next_level() -> int:
  return _get_xp_for_next_level()

## SaveableSystem Interface Implementation

## Get unique save key for this system
func get_save_key() -> String:
  return "player_progression"

## Get saveable state as dictionary
func get_save_data() -> Dictionary:
  return {
    "current_level": current_level,
    "current_xp": current_xp,
    "current_scrap": current_scrap
  }

## Load data from saved state
func load_data(data: Dictionary) -> void:
  current_level = data.get("current_level", 1)
  current_xp = data.get("current_xp", 0)
  current_scrap = data.get("current_scrap", starting_scrap)
  
  # Emit signals to update UI
  scrap_changed.emit(current_scrap)
  xp_changed.emit(current_xp)
  
  MyLogger.info("CurrencyManager", "Progression loaded - Level: %d, XP: %d, Scrap: %d" % [current_level, current_xp, current_scrap])
  progression_loaded.emit()

## Reset to default state (for new game)
func reset_data() -> void:
  current_level = 1
  current_xp = 0
  current_scrap = starting_scrap
  
  MyLogger.info("CurrencyManager", "Progression reset to defaults")
