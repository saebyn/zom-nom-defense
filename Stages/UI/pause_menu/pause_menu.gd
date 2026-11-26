extends Control
class_name UI_PauseMenu

const SettingsMenuScene = preload("res://Common/UI/settings_menu/settings_menu.tscn")
const AchievementListScene = preload("res://Stages/UI/achievement_list/achievement_list.tscn")

@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var achievements_button: Button = $VBoxContainer/AchievementsButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var main_menu_button: Button = $VBoxContainer/MainMenuButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

var settings_menu = null
var achievement_list_ui = null

func _ready():
  # Initially hide the pause menu
  visible = false
  
  # Connect to GameManager state changes
  GameManager.game_state_changed.connect(_on_game_state_changed)
  
  # Create and add settings menu
  _setup_settings_menu()

func _setup_settings_menu():
  settings_menu = SettingsMenuScene.instantiate()
  add_child(settings_menu)
  settings_menu.closed.connect(_on_settings_menu_closed)

func _on_game_state_changed(new_state: GameManager.GameState):
  match new_state:
    GameManager.GameState.IN_GAME_MENU:
      visible = true
      # Focus the resume button for keyboard navigation
      resume_button.grab_focus()
    GameManager.GameState.PLAYING:
      visible = false

func _on_resume_pressed():
  MyLogger.info("PauseMenu", "Resume button pressed")
  GameManager.toggle_in_game_menu()

func _on_settings_pressed():
  MyLogger.info("PauseMenu", "Settings button pressed")
  if settings_menu:
    settings_menu.show_menu()


func _on_achievements_pressed():
  MyLogger.info("PauseMenu", "Achievements button pressed")
  _show_achievements()

func _show_achievements():
  # Create achievement list UI if not already open
  if achievement_list_ui == null:
    achievement_list_ui = AchievementListScene.instantiate()
    add_child(achievement_list_ui)
    achievement_list_ui.closed.connect(_on_achievement_list_closed)
  else:
    achievement_list_ui.visible = true

func _on_achievement_list_closed():
  MyLogger.debug("PauseMenu", "Achievement list closed")
  achievement_list_ui = null

func _on_settings_menu_closed():
  MyLogger.debug("PauseMenu", "Settings menu closed")

func _on_restart_pressed():
  MyLogger.info("PauseMenu", "Restart button pressed")
  GameManager.restart_scenario()

func _on_main_menu_pressed():
  GameManager.return_to_main_menu()

func _on_quit_pressed():
  GameManager.quit_game()
