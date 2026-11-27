extends PanelContainer

class_name UI_SaveSlotCard

## Card UI component representing a single save slot
## Displays slot information and provides actions (New Game, Continue, Delete)

signal slot_selected(slot_number: int)
signal slot_deleted(slot_number: int)

# Month names for date formatting
const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# Placeholder texture for empty slots
const PLACEHOLDER_TEXTURE = preload("res://Assets/Icons/new_placeholder_texture_2d.tres")

@onready var screenshot_container = $MarginContainer/HBoxContainer/ScreenshotContainer
@onready var screenshot_rect = $MarginContainer/HBoxContainer/ScreenshotContainer/ScreenshotRect
@onready var slot_name_label = $MarginContainer/HBoxContainer/LeftContainer/SlotNameLabel
@onready var slot_info_label = $MarginContainer/HBoxContainer/LeftContainer/SlotInfoLabel
@onready var slot_details_label = $MarginContainer/HBoxContainer/LeftContainer/SlotDetailsLabel
@onready var action_button = $MarginContainer/HBoxContainer/ButtonContainer/ActionButton
@onready var delete_button = $MarginContainer/HBoxContainer/ButtonContainer/DeleteButton

var slot_number: int = -1
var is_occupied: bool = false
var is_corrupted: bool = false

## Configure the card with slot data
func configure(slot_num: int, metadata: Dictionary):
  slot_number = slot_num
  is_occupied = metadata.get("exists", false)
  is_corrupted = metadata.get("corrupted", false)
  
  # Set slot name
  slot_name_label.text = "Slot %d" % slot_number
  
  # Load and display screenshot if available
  _load_screenshot()
  
  if is_corrupted:
    # Handle corrupted save
    slot_info_label.text = "Corrupted Save"
    slot_details_label.text = "This save file is corrupted"
    action_button.text = "New Game"
    action_button.disabled = false
    delete_button.visible = true
    delete_button.disabled = false
  elif is_occupied:
    # Display save information
    var level = metadata.get("player_level", 1)
    var playtime = metadata.get("playtime", 0.0)
    var timestamp = metadata.get("timestamp", 0)
    
    MyLogger.debug("SaveSlotCard", "Slot %d metadata - Level: %d, Playtime: %.2f, Timestamp: %d" % [slot_number, level, playtime, timestamp])
    
    slot_info_label.text = "Level %d" % level
    
    # Format playtime
    var hours = int(playtime / 3600.0)
    var minutes = int((playtime - hours * 3600.0) / 60.0)
    var seconds = int(playtime) % 60
    var playtime_str = ""
    if hours > 0:
      playtime_str = "%dh %dm" % [hours, minutes]
    elif minutes > 0:
      playtime_str = "%dm %ds" % [minutes, seconds]
    else:
      playtime_str = "%ds" % seconds
    
    # Format last played date - convert UTC timestamp to local time
    var local_datetime = Time.get_datetime_dict_from_system()
    
    # Get the offset between UTC and local time
    var utc_now = Time.get_unix_time_from_system()
    var local_offset = Time.get_unix_time_from_datetime_dict(local_datetime) - utc_now
    
    # Apply offset to the saved timestamp to get local time
    var local_timestamp = timestamp + local_offset
    var local_save_datetime = Time.get_datetime_dict_from_unix_time(local_timestamp)
    
    var date_str = "%s %d" % [_get_month_name(local_save_datetime.month), local_save_datetime.day]
    
    slot_details_label.text = "%s | Last played: %s" % [playtime_str, date_str]
    
    action_button.text = "Continue"
    action_button.disabled = false
    delete_button.visible = true
    delete_button.disabled = false
  else:
    # Empty slot
    slot_info_label.text = "Empty Slot"
    slot_details_label.text = "Start a new adventure"
    action_button.text = "New Game"
    action_button.disabled = false
    delete_button.visible = false

## Get month name from month number
func _get_month_name(month: int) -> String:
  if month >= 1 and month <= 12:
    return MONTH_NAMES[month - 1]
  return "???"

## Load screenshot for this save slot
func _load_screenshot():
  var screenshot = SaveManager.get_slot_screenshot(slot_number)
  
  if screenshot:
    # Use actual screenshot
    screenshot_rect.texture = screenshot
    screenshot_container.visible = true
  else:
    # Use placeholder for empty slots
    screenshot_rect.texture = PLACEHOLDER_TEXTURE
    screenshot_container.visible = true

## Handle action button press (New Game or Continue)
func _on_action_button_pressed():
  MyLogger.info("SaveSlotCard", "Action button pressed for slot %d (occupied: %s)" % [slot_number, is_occupied])
  slot_selected.emit(slot_number)

## Handle delete button press
func _on_delete_button_pressed():
  MyLogger.info("SaveSlotCard", "Delete button pressed for slot %d" % slot_number)
  slot_deleted.emit(slot_number)
