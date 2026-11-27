extends GutTest

## Unit tests for SaveManager autoload
## Tests save slot management, atomic writes, and SaveableSystem interface

# Mock saveable system for testing
class MockSaveableSystem:
  var save_key: String
  var save_data: Dictionary
  var loaded_data: Dictionary
  var reset_called: bool = false
  
  func _init(key: String, data: Dictionary = {}):
    save_key = key
    save_data = data
    loaded_data = {}
  
  func get_save_key() -> String:
    return save_key
  
  func get_save_data() -> Dictionary:
    return save_data
  
  func load_data(data: Dictionary) -> void:
    loaded_data = data
  
  func reset_data() -> void:
    reset_called = true
    save_data = {}
    loaded_data = {}

# Test slot number - use a high number to avoid conflicts with other tests
const TEST_SLOT = 9

# Store original managed systems to restore after tests
var original_managed_systems: Array = []
var original_selection_existed: bool
var original_selection: PackedByteArray

func before_all():
  original_selection_existed = FileAccess.file_exists(SaveManager.LAST_SAVE_SLOT_PATH)
  if original_selection_existed:
    original_selection = FileAccess.get_file_as_bytes(SaveManager.LAST_SAVE_SLOT_PATH)

func after_all():
  if original_selection_existed:
    var file := FileAccess.open(SaveManager.LAST_SAVE_SLOT_PATH, FileAccess.WRITE)
    file.store_buffer(original_selection)
    file.close()
  else:
    DirAccess.remove_absolute(SaveManager.LAST_SAVE_SLOT_PATH)

func before_each():
  # Clean up any existing test save files
  _cleanup_test_saves()
  if FileAccess.file_exists(SaveManager.LAST_SAVE_SLOT_PATH):
    DirAccess.remove_absolute(SaveManager.LAST_SAVE_SLOT_PATH)
  
  # Save original managed systems so we can restore them after
  original_managed_systems = SaveManager.managed_systems.duplicate()
  
  # Clear registered systems for isolated unit testing
  SaveManager.managed_systems.clear()
  SaveManager.current_save_slot = -1

func after_each():
  # Clean up test saves after each test
  _cleanup_test_saves()
  
  # Restore original managed systems for other tests
  SaveManager.managed_systems = original_managed_systems.duplicate()

func _cleanup_test_saves():
  # Delete only the test save slot to avoid affecting other tests
  var slot_path = SaveManager.SAVE_SLOT_PATH % TEST_SLOT
  var backup_path = SaveManager.SAVE_SLOT_BACKUP_PATH % TEST_SLOT
  
  if FileAccess.file_exists(slot_path):
    DirAccess.remove_absolute(slot_path)
  if FileAccess.file_exists(backup_path):
    DirAccess.remove_absolute(backup_path)

## Test: Register system with valid interface
func test_register_system_with_valid_interface():
  var mock_system = MockSaveableSystem.new("test_system")
  
  SaveManager.register_system(mock_system)
  
  assert_eq(SaveManager.managed_systems.size(), 1, "Should have 1 registered system")
  assert_eq(SaveManager.managed_systems[0], mock_system, "Should be the mock system")

## Test: Register multiple systems
func test_register_multiple_systems():
  var system1 = MockSaveableSystem.new("system1")
  var system2 = MockSaveableSystem.new("system2")
  
  SaveManager.register_system(system1)
  SaveManager.register_system(system2)
  
  assert_eq(SaveManager.managed_systems.size(), 2, "Should have 2 registered systems")

## Test: Create new game initializes slot
func test_create_new_game():
  var mock_system = MockSaveableSystem.new("test_system", {"value": 100})
  SaveManager.register_system(mock_system)
  
  SaveManager.create_new_game(TEST_SLOT)
  
  assert_eq(SaveManager.current_save_slot, TEST_SLOT, "Current slot should be set")
  assert_true(mock_system.reset_called, "System reset_data should be called")
  
  # Verify save file was created
  var slot_path = SaveManager.SAVE_SLOT_PATH % TEST_SLOT
  assert_true(FileAccess.file_exists(slot_path), "Save file should exist")

## Test: Create new game emits load_completed so downstream listeners (BuildingRegistry, etc.) refresh
func test_create_new_game_emits_load_completed():
  watch_signals(SaveManager)
  
  SaveManager.create_new_game(TEST_SLOT)
  
  assert_signal_emitted(SaveManager, "load_completed", "load_completed should be emitted so downstream systems refresh")

## Test: Save and load slot preserves data
func test_save_and_load_slot():
  # File operations may generate engine errors in headless mode - ignore them
  
  var mock_system = MockSaveableSystem.new("test_system", {"value": 42, "name": "test"})
  SaveManager.register_system(mock_system)
  
  # Create and save
  SaveManager.create_new_game(TEST_SLOT)
  mock_system.save_data = {"value": 100, "name": "updated"}
  SaveManager.save_current_slot()
  
  # Reset system and load
  mock_system.save_data = {}
  mock_system.loaded_data = {}
  SaveManager.current_save_slot = -1
  
  var success = SaveManager.load_save_slot(TEST_SLOT)
  
  assert_true(success, "Load should succeed")
  assert_eq(SaveManager.current_save_slot, TEST_SLOT, "Current slot should be set")
  assert_eq(mock_system.loaded_data.get("value"), 100, "Loaded value should match saved")
  assert_eq(mock_system.loaded_data.get("name"), "updated", "Loaded name should match saved")

func test_full_save_preserves_backup_when_primary_is_invalid():
  var system := MockSaveableSystem.new("test_system")
  SaveManager.register_system(system)
  SaveManager.create_new_game(TEST_SLOT)
  system.save_data = {"value": 42}
  assert_true(SaveManager.save_current_slot(false))
  system.save_data = {"value": 100}
  assert_true(SaveManager.save_current_slot(false), "Saving a new primary keeps the previous progress as a backup")

  # JSON that parses but is not a usable save must not become the next backup.
  var path := SaveManager.SAVE_SLOT_PATH % TEST_SLOT
  var primary := FileAccess.open(path, FileAccess.WRITE)
  primary.store_string("{}")
  primary.close()
  system.save_data = {"value": 200}
  assert_true(SaveManager.save_current_slot(false))
  assert_true(SaveManager.load_save_slot(TEST_SLOT))
  assert_eq(system.loaded_data.get("value"), 200.0, "The full save still writes fresh progress")

  primary = FileAccess.open(path, FileAccess.WRITE)
  primary.store_string("not JSON")
  primary.close()
  assert_true(SaveManager.load_save_slot(TEST_SLOT), "The previous backup remains usable")
  assert_eq(system.loaded_data.get("value"), 42.0, "Recovery loads the previous good backup")

## Test: Load non-existent slot fails
func test_load_nonexistent_slot_fails():
  var success = SaveManager.load_save_slot(99)
  
  assert_false(success, "Loading non-existent slot should fail")

## Test: Get slot metadata for existing slot
func test_get_slot_metadata_existing_slot():
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  SaveManager.create_new_game(TEST_SLOT)
  
  var metadata = SaveManager.get_slot_metadata(TEST_SLOT)
  
  assert_true(metadata.get("exists"), "Slot should exist")
  assert_eq(metadata.get("slot_number"), TEST_SLOT, "Slot number should match")
  assert_true(metadata.has("timestamp"), "Should have timestamp")
  assert_true(metadata.has("playtime"), "Should have playtime")

## Test: Get slot metadata for non-existent slot
func test_get_slot_metadata_nonexistent_slot():
  var metadata = SaveManager.get_slot_metadata(99)
  
  assert_false(metadata.get("exists", false), "Slot should not exist")
  assert_eq(metadata.get("slot_number"), 99, "Slot number should match")

## Test: Delete save slot
func test_delete_save_slot(backup_only = use_parameters([false, true])):
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  # Create a save
  SaveManager.create_new_game(TEST_SLOT)
  var slot_path = SaveManager.SAVE_SLOT_PATH % TEST_SLOT
  if backup_only:
    var backup_path = SaveManager.SAVE_SLOT_BACKUP_PATH % TEST_SLOT
    assert_eq(DirAccess.rename_absolute(slot_path, backup_path), OK)
  assert_true(SaveManager.load_save_slot(TEST_SLOT), "Slot is loadable before deletion")
  
  # Delete it
  var success = SaveManager.delete_save_slot(TEST_SLOT)
  
  assert_true(success, "Delete should succeed")
  assert_false(SaveManager.load_save_slot(TEST_SLOT), "No copy remains loadable after deletion")

## Test: Get available slots
func test_get_available_slots():
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  # Create multiple slots
  SaveManager.create_new_game(1)
  SaveManager.create_new_game(3)
  SaveManager.create_new_game(5)
  assert_eq(DirAccess.rename_absolute(SaveManager.SAVE_SLOT_PATH % 5, SaveManager.SAVE_SLOT_BACKUP_PATH % 5), OK)
  
  var available = SaveManager.get_available_slots()
  
  assert_eq(available.size(), 3, "Should have 3 available slots")
  assert_true(available.has(1), "Should include slot 1")
  assert_true(available.has(3), "Should include slot 3")
  assert_true(available.has(5), "Should include a slot that only has its backup")
  for slot_number in [1, 3, 5]:
    SaveManager.delete_save_slot(slot_number)

## Test: Invalid slot numbers are rejected
func test_invalid_slot_numbers_rejected():
  assert_false(SaveManager.load_save_slot(0), "Slot 0 should be invalid")
  assert_false(SaveManager.load_save_slot(-1), "Negative slot should be invalid")
  assert_false(SaveManager.load_save_slot(SaveManager.MAX_SAVE_SLOTS + 1), "Slot beyond max should be invalid")

## Test: Save includes version field
func test_save_includes_version():
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  SaveManager.create_new_game(TEST_SLOT)
  
  # Load raw save file and check version
  var slot_path = SaveManager.SAVE_SLOT_PATH % TEST_SLOT
  var file = FileAccess.open(slot_path, FileAccess.READ)
  var json = JSON.new()
  json.parse(file.get_as_text())
  var data = json.get_data()
  file.close()
  
  assert_true(data.has("version"), "Save should include version field")
  assert_eq(data.get("version"), SaveManager.SAVE_VERSION, "Version should match SAVE_VERSION")

## Test: Save includes metadata
func test_save_includes_metadata():
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  SaveManager.create_new_game(TEST_SLOT)
  
  var metadata = SaveManager.get_slot_metadata(TEST_SLOT)
  
  assert_true(metadata.has("timestamp"), "Should have timestamp")
  assert_true(metadata.has("playtime"), "Should have playtime")
  assert_true(metadata.has("player_level"), "Should have player_level")
  assert_true(metadata.has("last_scenario"), "Should have last_scenario")

## Test: Multiple systems save independently
func test_multiple_systems_save_independently():
  # File operations may generate engine errors in headless mode - ignore them
  
  var system1 = MockSaveableSystem.new("system1", {"value1": 100})
  var system2 = MockSaveableSystem.new("system2", {"value2": 200})
  
  SaveManager.register_system(system1)
  SaveManager.register_system(system2)
  
  SaveManager.create_new_game(TEST_SLOT)
  
  # Update values
  system1.save_data = {"value1": 150}
  system2.save_data = {"value2": 250}
  SaveManager.save_current_slot()
  
  # Reset and load
  system1.loaded_data = {}
  system2.loaded_data = {}
  SaveManager.current_save_slot = -1
  
  SaveManager.load_save_slot(TEST_SLOT)
  
  assert_eq(system1.loaded_data.get("value1"), 150, "System1 data should be restored")
  assert_eq(system2.loaded_data.get("value2"), 250, "System2 data should be restored")

## Test: Deleting current slot clears current_save_slot
func test_delete_current_slot_clears_current_save_slot():
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  SaveManager.create_new_game(TEST_SLOT)
  assert_eq(SaveManager.current_save_slot, TEST_SLOT, "Current slot should be set")
  
  SaveManager.delete_save_slot(TEST_SLOT)
  
  assert_eq(SaveManager.current_save_slot, -1, "Current slot should be cleared")

## Test: Save directory is created if missing
func test_save_directory_created():
  # Directory should exist after SaveManager initializes
  var dir = DirAccess.open("user://")
  assert_true(dir.dir_exists("saves"), "Save directory should exist")

## Test: Initialize default slot loads existing save
func test_initialize_default_slot_loads_existing(backup_only = use_parameters([false, true])):
  # File operations may generate engine errors in headless mode - ignore them
  
  var mock_system = MockSaveableSystem.new("test_system", {"value": 42})
  SaveManager.register_system(mock_system)
  
  # Create existing save in slot 1
  SaveManager.create_new_game(SaveManager.DEFAULT_SLOT)
  mock_system.save_data = {"value": 100}
  SaveManager.save_current_slot()
  if backup_only:
    var slot := SaveManager.DEFAULT_SLOT
    assert_eq(DirAccess.rename_absolute(SaveManager.SAVE_SLOT_PATH % slot, SaveManager.SAVE_SLOT_BACKUP_PATH % slot), OK)
  
  # Reset state
  SaveManager.current_save_slot = -1
  mock_system.loaded_data = {}
  assert_eq(DirAccess.remove_absolute(SaveManager.LAST_SAVE_SLOT_PATH), OK)
  
  # Initialize default slot should load existing save
  var success = SaveManager.initialize_active_slot()
  
  assert_true(success, "Should succeed")
  assert_eq(SaveManager.current_save_slot, SaveManager.DEFAULT_SLOT, "Should load default slot")
  assert_eq(mock_system.loaded_data.get("value"), 100, "Should load saved data")

## Test: Initialize default slot creates new game if no save exists
func test_initialize_default_slot_creates_new():
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  # Ensure no save exists
  SaveManager.delete_save_slot(SaveManager.DEFAULT_SLOT)
  
  # Initialize should create new game
  var success = SaveManager.initialize_active_slot()
  
  assert_true(success, "Should succeed")
  assert_eq(SaveManager.current_save_slot, SaveManager.DEFAULT_SLOT, "Should create default slot")
  assert_true(mock_system.reset_called, "Should reset system data")

## Test: Initialize default slot does nothing if already loaded
func test_initialize_default_slot_already_loaded():
  var mock_system = MockSaveableSystem.new("test_system")
  SaveManager.register_system(mock_system)
  
  # Load slot 2
  SaveManager.create_new_game(2)
  
  # Initialize should not change slot
  var success = SaveManager.initialize_active_slot()
  
  assert_true(success, "Should succeed")
  assert_eq(SaveManager.current_save_slot, 2, "Should keep existing slot")

func test_startup_restores_last_selected_slot_and_its_progress(
  selection = use_parameters(["new slot", "existing slot", "backup only"])
):
  var system := MockSaveableSystem.new("test_system")
  SaveManager.register_system(system)
  SaveManager.create_new_game(TEST_SLOT)
  system.save_data = {"value": 42}
  assert_true(SaveManager.save_current_slot(false))
  if selection != "new slot":
    SaveManager.create_new_game(SaveManager.DEFAULT_SLOT)
    assert_true(SaveManager.load_save_slot(TEST_SLOT))
  if selection == "backup only":
    assert_eq(DirAccess.rename_absolute(
      SaveManager.SAVE_SLOT_PATH % TEST_SLOT, SaveManager.SAVE_SLOT_BACKUP_PATH % TEST_SLOT
    ), OK)

  var restarted_manager = _new_save_manager()
  var restarted_system := MockSaveableSystem.new("test_system")
  restarted_manager.register_system(restarted_system)

  assert_true(restarted_manager.initialize_active_slot())
  assert_eq(restarted_manager.current_save_slot, TEST_SLOT)
  assert_eq(restarted_system.loaded_data.get("value"), 42.0)

func test_startup_does_not_switch_slots_when_the_last_selection_is_unusable(
  delete_slot = use_parameters([true, false])
):
  assert_true(SaveManager.create_new_game(SaveManager.DEFAULT_SLOT))
  assert_true(SaveManager.create_new_game(TEST_SLOT))
  if delete_slot:
    assert_true(SaveManager.delete_save_slot(TEST_SLOT))
  else:
    var primary := FileAccess.open(SaveManager.SAVE_SLOT_PATH % TEST_SLOT, FileAccess.WRITE)
    primary.store_string("not JSON")
    primary.close()

  var restarted_manager = _new_save_manager()
  assert_false(restarted_manager.initialize_active_slot())
  assert_eq(restarted_manager.current_save_slot, -1)
  assert_false(restarted_manager.initialize_active_slot(), "Returning to the menu still requires a selection")

  assert_true(restarted_manager.load_save_slot(SaveManager.DEFAULT_SLOT), "The player can select a different slot")
  var next_launch = _new_save_manager()
  assert_true(next_launch.initialize_active_slot())
  assert_eq(next_launch.current_save_slot, SaveManager.DEFAULT_SLOT)

func test_failed_slot_creation_does_not_replace_the_remembered_selection():
  assert_true(SaveManager.create_new_game(SaveManager.DEFAULT_SLOT))
  # Block the temporary save write without affecting the previous slot.
  var temp_path := (SaveManager.SAVE_SLOT_PATH % TEST_SLOT) + ".tmp"
  assert_eq(DirAccess.make_dir_absolute(temp_path), OK)
  var created := SaveManager.create_new_game(TEST_SLOT)
  assert_eq(DirAccess.remove_absolute(temp_path), OK)

  assert_false(created)
  assert_eq(SaveManager.current_save_slot, -1)
  var next_launch = _new_save_manager()
  assert_true(next_launch.initialize_active_slot())
  assert_eq(next_launch.current_save_slot, SaveManager.DEFAULT_SLOT)

func _new_save_manager():
  return autofree(load("res://Utilities/Systems/save_manager.gd").new())
