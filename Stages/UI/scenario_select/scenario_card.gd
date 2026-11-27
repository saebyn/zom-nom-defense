extends PanelContainer

## Individual scenario card that displays scenario info and handles selection
## Shows scenario name, status (locked/available/completed), and best time

signal scenario_selected(scenario_id: String)

var scenario_id: String = ""
var is_unlocked: bool = false
var scene_path: String = ""

@onready var scenario_name_label = $MarginContainer/VBoxContainer/HeaderHBox/ScenarioName
@onready var status_label = $MarginContainer/VBoxContainer/HeaderHBox/StatusLabel
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var best_time_label = $MarginContainer/VBoxContainer/BestTimeLabel
@onready var lock_message_label = $MarginContainer/VBoxContainer/LockMessageLabel
@onready var play_button = $MarginContainer/VBoxContainer/PlayButton

func _ready():
  # Connect button signal
  if play_button:
    play_button.pressed.connect(_on_play_button_pressed)

## Configure the scenario card with scenario data
func configure(
  p_scenario_id: String,
  p_scenario_name: String,
  p_description: String,
  p_is_unlocked: bool,
  p_is_completed: bool,
  p_best_time: float
):
  scenario_id = p_scenario_id
  is_unlocked = p_is_unlocked
  
  # Set scenario name
  scenario_name_label.text = p_scenario_name
  
  # Set description
  description_label.text = p_description
  
  # Set status indicator
  if p_is_completed:
    status_label.text = "✅"
    status_label.tooltip_text = "Completed"
  elif p_is_unlocked:
    status_label.text = "⭐"
    status_label.tooltip_text = "Available"
  else:
    status_label.text = "🔒"
    status_label.tooltip_text = "Locked"
  
  # Show/hide elements based on lock status
  if not p_is_unlocked:
    # Show lock message
    var required_scenario = ScenarioManager.get_unlock_requirement(scenario_id)
    var required_metadata = ScenarioManager.get_scenario_metadata(required_scenario)
    var required_name = required_metadata.get("name", required_scenario)
    lock_message_label.text = "Complete %s to unlock" % required_name
    lock_message_label.visible = true
    
    # Hide best time and play button
    best_time_label.visible = false
    play_button.visible = false
    play_button.disabled = true
  else:
    # Hide lock message
    lock_message_label.visible = false
    
    # Show best time if completed
    best_time_label.visible = p_is_completed
    if p_is_completed:
      var minutes = int(p_best_time) / 60
      var seconds = int(p_best_time) % 60
      best_time_label.text = "Best Time: %d:%02d" % [minutes, seconds]
    
    # Show play button
    play_button.visible = true
    play_button.disabled = false

## Handle play button press
func _on_play_button_pressed():
  if is_unlocked:
    MyLogger.info("ScenarioCard", "Scenario selected: %s" % scenario_id)
    scenario_selected.emit(scenario_id)
