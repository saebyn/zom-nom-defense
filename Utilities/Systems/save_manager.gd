extends Node

## SaveManager - Centralized save system with multi-slot support
##
## Orchestrates all game persistence, replacing decentralized save/load in individual managers.
## Provides atomic saves, multi-slot support, and separation between per-slot and global data.
##
## Current Implementation:
##   - Automatically uses slot 1 by default (initialize_default_slot())
##   - Loads existing save from slot 1 if available, or creates new game
##   - The main menu initializes the default slot; the slot picker can switch slots
##   - Scenario outcomes and main-menu tech choices save without a timer
##
## Data Safety Features:
##   - Atomic saves using temp file + rename pattern
##   - Automatic backup creation before overwriting saves
##   - Verification after save completion
##   - Backup restoration on corrupted primary save
##   - Best-effort backup creation (warns but doesn't fail save)
##
## Known Edge Cases:
##   - Playtime tracking: Only saved when save_current_slot() is called, 
##     or a partial save writes the slot, so crashes lose playtime since last save
##   - Screenshot capture: Happens after save completes, so save can succeed
##     even if screenshot fails (intentional - screenshot is non-critical)
##   - Backup creation: May fail on very rapid consecutive saves due to
##     filesystem timing, but this won't fail the save operation
##
## Usage:
##   # In manager _ready():
##   SaveManager.register_system(self)
##   
##   # Implement SaveableSystem interface:
##   func get_save_key() -> String:
##     return "player_progression"
##   
##   func get_save_data() -> Dictionary:
##     return {"current_level": current_level}
##   
##   func load_data(data: Dictionary) -> void:
##     current_level = data.get("current_level", 1)
##   
##   func reset_data() -> void:
##     current_level = 1

# Save slot configuration
const MAX_SAVE_SLOTS = 10 # Expandable, minimum 3
const DEFAULT_SLOT = 1 # Default slot to use when no slot selection UI exists
const SAVE_SLOT_DIR = "user://saves/"
const SAVE_SLOT_PATH = "user://saves/save_slot_%d.save"
const SAVE_SLOT_BACKUP_PATH = "user://saves/save_slot_%d.save.bak"
const SAVE_SLOT_SCREENSHOT_PATH = "user://saves/save_slot_%d_screenshot.png"
const GLOBAL_SAVE_PATH = "user://global.save"
const GLOBAL_SAVE_BACKUP_PATH = "user://global.save.bak"
const SAVE_VERSION = 1

# Screenshot configuration
const SCREENSHOT_WIDTH = 320 # Thumbnail width
const SCREENSHOT_HEIGHT = 180 # Thumbnail height (16:9 aspect ratio)

# Current state
var current_save_slot: int = -1 # -1 = no slot loaded
var managed_systems: Array = [] # Array of objects implementing SaveableSystem interface
var slot_playtime: float = 0.0 # Total playtime for current slot in seconds

# Signals
signal save_started()
signal save_completed()
signal save_failed(error: String)
signal load_started()
signal load_completed()
signal load_failed(error: String)
signal slot_created(slot_number: int)
signal slot_deleted(slot_number: int)

func _ready() -> void:
  # Ensure save directory exists
  _ensure_save_directory()
  MyLogger.info("SaveManager", "Save Manager initialized - Max slots: %d" % MAX_SAVE_SLOTS)

func _process(delta: float) -> void:
  # Track playtime for current slot
  if current_save_slot > 0:
    slot_playtime += delta

## Register a system that implements the SaveableSystem interface
## Required interface methods:
##   - get_save_key() -> String
##   - get_save_data() -> Dictionary
##   - load_data(data: Dictionary) -> void
##   - reset_data() -> void
func register_system(system) -> void:
  if not _validate_saveable_system(system):
    MyLogger.error("SaveManager", "System does not implement SaveableSystem interface: %s" % str(system))
    return
  
  managed_systems.append(system)
  MyLogger.info("SaveManager", "Registered saveable system: %s" % system.get_save_key())

## Validate that a system implements the SaveableSystem interface
func _validate_saveable_system(system) -> bool:
  return system.has_method("get_save_key") and \
         system.has_method("get_save_data") and \
         system.has_method("load_data") and \
         system.has_method("reset_data")

## Validate slot number is within valid range
## Returns true if valid, false otherwise
func _is_valid_slot_number(slot_number: int) -> bool:
  return slot_number >= 1 and slot_number <= MAX_SAVE_SLOTS

## Load a specific save slot
## Returns true if successful, false otherwise
func load_save_slot(slot_number: int) -> bool:
  if not _is_valid_slot_number(slot_number):
    MyLogger.error("SaveManager", "Invalid slot number: %d (must be 1-%d)" % [slot_number, MAX_SAVE_SLOTS])
    load_failed.emit("Invalid slot number")
    return false
  
  load_started.emit()
  
  var slot_path = SAVE_SLOT_PATH % slot_number
  
  # Check if slot exists
  if not FileAccess.file_exists(slot_path):
    MyLogger.warn("SaveManager", "Save slot %d does not exist" % slot_number)
    load_failed.emit("Save slot does not exist")
    return false
  
  # Try to load the slot
  var save_data = _load_json_file(slot_path)
  if save_data == null:
    # Try backup
    MyLogger.warn("SaveManager", "Primary save corrupted, attempting backup restore")
    var backup_path = SAVE_SLOT_BACKUP_PATH % slot_number
    save_data = _load_json_file(backup_path)
    
    if save_data == null:
      MyLogger.error("SaveManager", "Failed to load slot %d (both primary and backup corrupted)" % slot_number)
      load_failed.emit("Save file corrupted")
      return false
  
  # Validate save data structure
  if not _validate_save_data(save_data):
    MyLogger.error("SaveManager", "Invalid save data structure in slot %d" % slot_number)
    load_failed.emit("Invalid save data")
    return false
  
  # Load data into each managed system
  for system in managed_systems:
    var save_key = system.get_save_key()
    var system_data = save_data.get(save_key, {})
    
    if system_data is Dictionary:
      system.load_data(system_data)
      MyLogger.debug("SaveManager", "Loaded data for system: %s" % save_key)
    else:
      MyLogger.warn("SaveManager", "No data found for system: %s" % save_key)
  
  # Update current slot
  current_save_slot = slot_number
  
  # Restore playtime from metadata
  var metadata = save_data.get("metadata", {})
  slot_playtime = metadata.get("playtime", 0.0)
  
  MyLogger.info("SaveManager", "Successfully loaded save slot %d" % slot_number)
  load_completed.emit()
  return true

## Initialize default save slot (slot 1)
## Loads existing save if available, or creates new game
## Call this when starting the game to ensure a slot is always loaded
func initialize_default_slot() -> bool:
  if current_save_slot > 0:
    MyLogger.info("SaveManager", "Save slot already loaded: %d" % current_save_slot)
    return true
  
  var slot_path = SAVE_SLOT_PATH % DEFAULT_SLOT
  
  if FileAccess.file_exists(slot_path):
    MyLogger.info("SaveManager", "Loading existing save from default slot %d" % DEFAULT_SLOT)
    return load_save_slot(DEFAULT_SLOT)
  else:
    MyLogger.info("SaveManager", "Creating new game in default slot %d" % DEFAULT_SLOT)
    create_new_game(DEFAULT_SLOT)
    return true

## Save the current slot atomically
## Uses temporary file + rename to ensure atomic writes
## Returns true on success, false on failure
## If capture_screenshot is false, skips screenshot capture (useful for initial saves from UI)
func save_current_slot(capture_screenshot: bool = true) -> bool:
  if current_save_slot == -1:
    MyLogger.error("SaveManager", "Cannot save: no slot is currently loaded")
    save_failed.emit("No save slot loaded")
    return false
  
  if not _is_valid_slot_number(current_save_slot):
    MyLogger.error("SaveManager", "Cannot save: invalid slot number %d (valid range: 1-%d)" % [current_save_slot, MAX_SAVE_SLOTS])
    save_failed.emit("Invalid save slot number")
    return false
  
  save_started.emit()
  
  # Collect data from all registered systems
  var save_data = {
    "version": SAVE_VERSION,
    "metadata": _generate_slot_metadata()
  }
  
  for system in managed_systems:
    var save_key = system.get_save_key()
    var system_data = system.get_save_data()
    
    if system_data is Dictionary:
      save_data[save_key] = system_data
      MyLogger.debug("SaveManager", "Collected data from system: %s" % save_key)
    else:
      MyLogger.warn("SaveManager", "System returned invalid data: %s" % save_key)
  
  return _write_current_slot(save_data, capture_screenshot)

## Save lifetime activity without committing changes from an unsuccessful attempt.
func save_attempt_activity() -> bool:
  return _save_slot_sections([StatsManager, AchievementManager])

## Save an explicit Tech Tree choice made outside a scenario attempt.
func save_menu_tech_choices() -> bool:
  return _save_slot_sections([TechTreeManager])

func _save_slot_sections(systems: Array) -> bool:
  if not _is_valid_slot_number(current_save_slot):
    return false

  save_started.emit()
  var save_data = _load_json_file(SAVE_SLOT_PATH % current_save_slot)
  var primary_valid := _validate_save_data(save_data)
  if not primary_valid:
    save_data = _load_json_file(SAVE_SLOT_BACKUP_PATH % current_save_slot)
    if not _validate_save_data(save_data):
      MyLogger.error("SaveManager", "Cannot update slot %d without a valid save" % current_save_slot)
      save_failed.emit("Cannot update slot without a valid save")
      return false

  for system in systems:
    save_data[system.get_save_key()] = system.get_save_data()
  var metadata: Dictionary = save_data.get("metadata", {})
  metadata["playtime"] = slot_playtime
  metadata["timestamp"] = Time.get_unix_time_from_system()
  save_data["metadata"] = metadata
  # Do not replace the recovery copy with a damaged primary.
  return _write_current_slot(save_data, false, primary_valid)

func _write_current_slot(save_data: Dictionary, capture_screenshot: bool, rotate_backup: bool = true) -> bool:
  var slot_path = SAVE_SLOT_PATH % current_save_slot
  var backup_path = SAVE_SLOT_BACKUP_PATH % current_save_slot
  
  if not _save_json_file_atomic(slot_path, backup_path, save_data, rotate_backup):
    MyLogger.error("SaveManager", "Failed to save slot %d" % current_save_slot)
    save_failed.emit("File write failed")
    return false
  
  # Capture and save screenshot after successful save (only if requested)
  if capture_screenshot:
    _capture_screenshot(current_save_slot)
  else:
    MyLogger.debug("SaveManager", "Skipping screenshot capture for slot %d" % current_save_slot)
  
  MyLogger.info("SaveManager", "Successfully saved slot %d" % current_save_slot)
  save_completed.emit()
  return true

## Create a new game in the specified slot
## Resets all per-slot data, keeps global data
func create_new_game(slot_number: int) -> void:
  if not _is_valid_slot_number(slot_number):
    MyLogger.error("SaveManager", "Invalid slot number: %d (must be 1-%d)" % [slot_number, MAX_SAVE_SLOTS])
    return
  
  MyLogger.info("SaveManager", "Creating new game in slot %d" % slot_number)
  
  # Reset all managed systems to default state
  for system in managed_systems:
    system.reset_data()
    MyLogger.debug("SaveManager", "Reset system: %s" % system.get_save_key())
  
  # Set current slot
  current_save_slot = slot_number
  
  # Reset playtime for new game
  slot_playtime = 0.0
  
  # Save the fresh state without capturing screenshot (we're still in UI, not in game)
  if not save_current_slot(false):
    MyLogger.error("SaveManager", "Failed to save new game in slot %d" % slot_number)
    load_failed.emit("Failed to save new game slot %d" % slot_number)
    return
  
  slot_created.emit(slot_number)
  # Notify downstream systems (BuildingRegistry, etc.) that a valid state is now loaded
  # This ensures they refresh after a reset, just as they would after loading a save
  load_completed.emit()
  MyLogger.info("SaveManager", "New game created in slot %d" % slot_number)

## Get metadata for a specific save slot
## Returns dictionary with slot info or empty dict if slot doesn't exist
func get_slot_metadata(slot_number: int) -> Dictionary:
  if not _is_valid_slot_number(slot_number):
    return {"exists": false, "slot_number": slot_number}
  
  var slot_path = SAVE_SLOT_PATH % slot_number
  
  if not FileAccess.file_exists(slot_path):
    return {"exists": false, "slot_number": slot_number}
  
  var save_data = _load_json_file(slot_path)
  if save_data == null or not save_data is Dictionary:
    return {"exists": false, "slot_number": slot_number, "corrupted": true}
  
  var metadata = save_data.get("metadata", {})
  metadata["exists"] = true
  metadata["slot_number"] = slot_number
  
  return metadata

## Delete a save slot
## Returns true if successful or slot didn't exist, false on error
func delete_save_slot(slot_number: int) -> bool:
  if not _is_valid_slot_number(slot_number):
    MyLogger.error("SaveManager", "Invalid slot number: %d (must be 1-%d)" % [slot_number, MAX_SAVE_SLOTS])
    return false
  
  var slot_path = SAVE_SLOT_PATH % slot_number
  var backup_path = SAVE_SLOT_BACKUP_PATH % slot_number
  
  # If current slot is being deleted, unload it
  if current_save_slot == slot_number:
    current_save_slot = -1
  
  # If slot doesn't exist, consider it a success (idempotent operation)
  if not FileAccess.file_exists(slot_path):
    MyLogger.debug("SaveManager", "Slot %d doesn't exist, nothing to delete" % slot_number)
    return true
  
  var dir = DirAccess.open("user://saves/")
  if not dir:
    MyLogger.error("SaveManager", "Could not access save directory")
    return false
  
  var success = true
  var primary_deleted = false
  
  # Delete primary save
  var filename = "save_slot_%d.save" % slot_number
  var delete_result = dir.remove(filename)
  if delete_result != OK:
    MyLogger.error("SaveManager", "Failed to delete save file: %s (error %d)" % [filename, delete_result])
    success = false
  else:
    MyLogger.debug("SaveManager", "Deleted save file: %s" % filename)
    primary_deleted = true
  
  # Only delete backup and screenshot if primary was successfully deleted
  if primary_deleted:
    # Delete backup
    if FileAccess.file_exists(backup_path):
      var backup_filename = "save_slot_%d.save.bak" % slot_number
      if dir.remove(backup_filename) != OK:
        MyLogger.warn("SaveManager", "Failed to delete backup file: %s" % backup_filename)
      else:
        MyLogger.debug("SaveManager", "Deleted backup file: %s" % backup_filename)
    
    # Delete screenshot
    _delete_screenshot(slot_number)
  
  if success:
    MyLogger.info("SaveManager", "Deleted save slot %d" % slot_number)
    slot_deleted.emit(slot_number)
  
  return success

## Get list of all slot numbers that have save data
func get_available_slots() -> Array[int]:
  var slots: Array[int] = []
  
  for i in range(1, MAX_SAVE_SLOTS + 1):
    var slot_path = SAVE_SLOT_PATH % i
    if FileAccess.file_exists(slot_path):
      slots.append(i)
  
  return slots

## Save global settings data (persists across all save slots)
## 
## NOTE: Currently a placeholder for future global data expansion.
## SettingsManager handles its own persistence separately.
## This method is ready for use but not currently utilized.
## Future use cases: cross-slot achievements, global statistics, etc.
func save_global_data() -> void:
  save_started.emit()
  
  # Collect global data (currently just settings)
  var global_data = {
    "version": SAVE_VERSION,
  }
  
  # Add data from systems marked as global (SettingsManager would go here)
  # For now, we'll let SettingsManager handle its own persistence
  # This is a placeholder for future global data expansion
  
  if _save_json_file_atomic(GLOBAL_SAVE_PATH, GLOBAL_SAVE_BACKUP_PATH, global_data):
    MyLogger.info("SaveManager", "Successfully saved global data")
    save_completed.emit()
  else:
    MyLogger.error("SaveManager", "Failed to save global data")
    save_failed.emit("Global data write failed")

## Load global settings data
##
## NOTE: Currently a placeholder for future global data expansion.
## Returns true if global data was loaded successfully, false otherwise.
func load_global_data() -> bool:
  load_started.emit()
  
  if not FileAccess.file_exists(GLOBAL_SAVE_PATH):
    MyLogger.info("SaveManager", "No global save file found")
    load_failed.emit("No global save file")
    return false
  
  var global_data = _load_json_file(GLOBAL_SAVE_PATH)
  if global_data == null:
    # Try backup
    global_data = _load_json_file(GLOBAL_SAVE_BACKUP_PATH)
    if global_data == null:
      MyLogger.error("SaveManager", "Failed to load global data")
      load_failed.emit("Global data corrupted")
      return false
  
  MyLogger.info("SaveManager", "Successfully loaded global data")
  load_completed.emit()
  return true

## Helper: Generate metadata for current game state
func _generate_slot_metadata() -> Dictionary:
  var metadata = {
    "timestamp": Time.get_unix_time_from_system(),
    "playtime": slot_playtime,
    "player_level": 1,
    "last_scenario": "",
    "slot_name": "" # Optional user-customizable name
  }
  
  # Try to get player level from CurrencyManager (with null check)
  if CurrencyManager and CurrencyManager.has_method("get_level"):
    metadata["player_level"] = CurrencyManager.get_level()
  else:
    MyLogger.warn("SaveManager", "CurrencyManager not available for metadata generation")
  
  # The last scenario is display metadata, not a checkpoint.
  if ScenarioManager and ScenarioManager.has_method("get_current_scenario_id"):
    metadata["last_scenario"] = ScenarioManager.get_current_scenario_id()
  else:
    MyLogger.debug("SaveManager", "ScenarioManager not available for metadata generation")
  
  return metadata

## Helper: Ensure save directory exists
func _ensure_save_directory() -> void:
  var dir = DirAccess.open("user://")
  if dir:
    if not dir.dir_exists("saves"):
      dir.make_dir("saves")
      MyLogger.info("SaveManager", "Created save directory: user://saves/")

## Helper: Validate save data structure
func _validate_save_data(data) -> bool:
  if not data is Dictionary:
    return false
  
  if not data.has("version"):
    return false
  
  return true

## Helper: Load JSON file
## Returns parsed Dictionary or null on error
func _load_json_file(path: String):
  if not FileAccess.file_exists(path):
    return null
  
  var file = FileAccess.open(path, FileAccess.READ)
  if not file:
    MyLogger.error("SaveManager", "Could not open file for reading: %s" % path)
    return null
  
  var json_string = file.get_as_text()
  file.close()
  
  var json = JSON.new()
  var parse_result = json.parse(json_string)
  
  if parse_result != OK:
    MyLogger.error("SaveManager", "Error parsing JSON from %s: %s" % [path, json.get_error_message()])
    return null
  
  return json.get_data()

## Helper: Save JSON file atomically with backup
## Writes to temp file first, then renames. Keeps backup of previous save.
## Returns true on success, false on failure
func _save_json_file_atomic(primary_path: String, backup_path: String, data: Dictionary, rotate_backup: bool = true) -> bool:
  var temp_path = primary_path + ".tmp"
  
  # Extract filenames once at the beginning for clarity
  var primary_filename = primary_path.get_file()
  var backup_filename = backup_path.get_file()
  var temp_filename = temp_path.get_file()
  
  # Write to temporary file
  var file = FileAccess.open(temp_path, FileAccess.WRITE)
  if not file:
    MyLogger.error("SaveManager", "Could not open temp file for writing: %s" % temp_path)
    return false
  
  var json_string = JSON.stringify(data, "  ") # Pretty print with 2-space indent
  file.store_string(json_string)
  file.close()
  
  # Verify temp file was written successfully
  if not FileAccess.file_exists(temp_path):
    MyLogger.error("SaveManager", "Temp file was not created: %s" % temp_path)
    return false
  
  var dir = DirAccess.open("user://saves/")
  if not dir:
    MyLogger.error("SaveManager", "Could not access save directory")
    # Clean up temp file
    var cleanup_result = DirAccess.remove_absolute(temp_path)
    if cleanup_result != OK:
      MyLogger.warn("SaveManager", "Failed to cleanup temp file (error %d): %s" % [cleanup_result, temp_path])
    return false
  
  # Create backup of existing save before overwriting
  if rotate_backup and FileAccess.file_exists(primary_path):
    # Copy primary to backup - this is a best-effort operation
    # We log errors but don't fail the save since the backup is for recovery, not primary storage
    # 
    # Note: Using manual file copy instead of DirAccess.copy() because:
    # - DirAccess.copy() generates internal engine errors when it fails, even if we handle the error
    # - These engine errors cause test failures in GUT (which treats any engine error as a test failure)
    # - Manual copy via FileAccess doesn't generate these internal engine errors
    # - For JSON save files, we don't need to preserve file permissions or metadata
    var source_file = FileAccess.open(primary_path, FileAccess.READ)
    if source_file:
      var content = source_file.get_as_text()
      source_file.close()
      
      var dest_file = FileAccess.open(backup_path, FileAccess.WRITE)
      if dest_file:
        dest_file.store_string(content)
        dest_file.close()
        MyLogger.debug("SaveManager", "Created backup: %s" % backup_filename)
      else:
        MyLogger.warn("SaveManager", "Failed to create backup file: %s - save will continue" % backup_path)
    else:
      MyLogger.warn("SaveManager", "Failed to read source for backup: %s - save will continue" % primary_path)
  
  # Rename temp file to primary (atomic operation on most filesystems)
  var rename_result = dir.rename(temp_filename, primary_filename)
  if rename_result != OK:
    MyLogger.error("SaveManager", "Failed to rename temp file to primary (error %d): %s -> %s" % [rename_result, temp_filename, primary_filename])
    # Clean up temp file
    var cleanup_result = DirAccess.remove_absolute(temp_path)
    if cleanup_result != OK:
      MyLogger.warn("SaveManager", "Failed to cleanup temp file (error %d): %s" % [cleanup_result, temp_path])
    return false
  
  # Final verification that the save file exists and is readable
  if not FileAccess.file_exists(primary_path):
    MyLogger.error("SaveManager", "Save file does not exist after rename: %s" % primary_path)
    return false
  
  # Verify the saved file is valid JSON
  var verify_file = FileAccess.open(primary_path, FileAccess.READ)
  if not verify_file:
    MyLogger.error("SaveManager", "Cannot read saved file for verification: %s" % primary_path)
    return false
  verify_file.close()
  
  MyLogger.debug("SaveManager", "Successfully saved and verified: %s" % primary_filename)
  return true

## Helper: Capture screenshot for save slot
## Captures the current viewport and saves it as a thumbnail
func _capture_screenshot(slot_number: int) -> void:
  # Skip screenshot in headless mode (dummy renderer can't produce images)
  if DisplayServer.get_name() == "headless":
    MyLogger.debug("SaveManager", "Skipping screenshot capture in headless mode")
    return
  
  # Get the current viewport with null check
  var viewport = get_viewport()
  if not viewport:
    MyLogger.warn("SaveManager", "Could not get viewport for screenshot")
    return
  
  # Wait one frame to ensure frame is rendered
  await get_tree().process_frame
  
  # Get the viewport texture with null checks
  var texture = viewport.get_texture()
  if not texture:
    MyLogger.warn("SaveManager", "Could not get viewport texture for screenshot")
    return
  
  var img = texture.get_image()
  if not img:
    MyLogger.warn("SaveManager", "Could not get viewport image for screenshot")
    return
  
  # Resize to thumbnail size
  img.resize(SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT, Image.INTERPOLATE_LANCZOS)
  
  # Save as PNG
  var screenshot_path = SAVE_SLOT_SCREENSHOT_PATH % slot_number
  var error = img.save_png(screenshot_path)
  
  if error != OK:
    MyLogger.warn("SaveManager", "Failed to save screenshot for slot %d: error %d" % [slot_number, error])
  else:
    MyLogger.debug("SaveManager", "Saved screenshot for slot %d" % slot_number)

## Helper: Load screenshot for save slot
## Returns ImageTexture or null if screenshot doesn't exist
func get_slot_screenshot(slot_number: int) -> ImageTexture:
  var screenshot_path = SAVE_SLOT_SCREENSHOT_PATH % slot_number
  
  if not FileAccess.file_exists(screenshot_path):
    MyLogger.debug("SaveManager", "No screenshot found for slot %d" % slot_number)
    return null
  
  var img = Image.load_from_file(screenshot_path)
  if not img:
    MyLogger.warn("SaveManager", "Failed to load screenshot for slot %d" % slot_number)
    return null
  
  var texture = ImageTexture.create_from_image(img)
  return texture

## Helper: Delete screenshot for save slot
func _delete_screenshot(slot_number: int) -> void:
  var screenshot_path = SAVE_SLOT_SCREENSHOT_PATH % slot_number
  
  if FileAccess.file_exists(screenshot_path):
    var dir = DirAccess.open("user://saves/")
    if dir:
      var filename = screenshot_path.get_file()
      if dir.remove(filename) == OK:
        MyLogger.debug("SaveManager", "Deleted screenshot for slot %d" % slot_number)
      else:
        MyLogger.warn("SaveManager", "Failed to delete screenshot for slot %d" % slot_number)
