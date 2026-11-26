extends Control

@onready var survival_time_label = $Panel/MarginContainer/VBoxContainer/SurvivalTimeLabel

func _ready():
  # Initially hide the game over menu
  visible = false
  
  # Connect to GameManager state changes
  GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: GameManager.GameState):
  match new_state:
    GameManager.GameState.GAME_OVER:
      _update_stats()
      visible = true
    _:
      visible = false


func _update_stats() -> void:
  var stats = ScenarioManager.last_scenario_stats
  
  if stats.is_empty():
    MyLogger.warn("GameOverMenu", "No scenario stats available")
    return
  
  # Format and display survival time
  var elapsed_time = stats.get("elapsed_time", 0.0)
  survival_time_label.text = "Survival Time: %s" % _format_time(elapsed_time)


## Format seconds to MM:SS
func _format_time(seconds: float) -> String:
  var minutes = int(seconds) / 60
  var remaining_seconds = int(seconds) % 60
  return "%d:%02d" % [minutes, remaining_seconds]


func _on_button_pressed() -> void:
  GameManager.return_to_main_menu()
