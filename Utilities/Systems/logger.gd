@tool
extends Node

## Comprehensive logging framework for Tower Defense game
## Provides scoped logging with configurable log levels similar to debug npm package
## 
## Usage:
##   MyLogger.info("Player", "Game started with %d enemies" % enemy_count)
##   MyLogger.debug("Combat", "Attack dealt %d damage" % damage)
##   MyLogger.warn("Economy", "Currency running low: %d remaining" % currency)
##   MyLogger.error("System", "Failed to load enemy config: %s" % config_path)

enum LogLevel {
  TRACE,
  DEBUG,
  INFO,
  WARN,
  ERROR,
  NONE # Disables all logging
}

# Current global log level - can be overridden in project settings
var current_log_level: LogLevel = LogLevel.INFO

# Scope-based filtering - similar to debug npm package
# Format: ["scope1", "scope2", "*"] where "*" means all scopes
var enabled_scopes: PackedStringArray = ["*"]

# Internal settings
var _log_level_names: PackedStringArray = ["TRACE", "DEBUG", "INFO", "WARN", "ERROR"]
var _log_level_colors: PackedStringArray = ["[color=gray]", "[color=lightblue]", "[color=green]", "[color=orange]", "[color=red]"]

signal log_message_emitted(level: LogLevel, scope: String, message: String, timestamp: String)

func _ready() -> void:
  # Register settings with the editor (defines types, hints, defaults)
  _define_project_settings()
  # Load settings from project settings
  _load_project_settings()

  # Log framework initialization
  info("MyLogger", "Logging framework initialized - Level: %s, Scopes: %s" % [
    _log_level_names[current_log_level],
    ", ".join(enabled_scopes)
  ])

## Register logging settings with ProjectSettings so they appear correctly in the editor
func _define_project_settings() -> void:
  if not ProjectSettings.has_setting("zom_nom_defense/logging/log_level"):
    ProjectSettings.set_setting("zom_nom_defense/logging/log_level", LogLevel.INFO)
  ProjectSettings.set_initial_value("zom_nom_defense/logging/log_level", LogLevel.INFO)
  ProjectSettings.add_property_info({
    "name": "zom_nom_defense/logging/log_level",
    "type": TYPE_INT,
    "hint": PROPERTY_HINT_ENUM,
    "hint_string": "Trace,Debug,Info,Warn,Error"
  })

  if not ProjectSettings.has_setting("zom_nom_defense/logging/enabled_scopes"):
    ProjectSettings.set_setting("zom_nom_defense/logging/enabled_scopes", "*")
  ProjectSettings.set_initial_value("zom_nom_defense/logging/enabled_scopes", "*")
  ProjectSettings.add_property_info({
    "name": "zom_nom_defense/logging/enabled_scopes",
    "type": TYPE_STRING,
    "hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
    "hint_string": "*, Combat, Economy.Scrap"
  })

  if not ProjectSettings.has_setting("zom_nom_defense/debug/show_navigation_paths"):
    ProjectSettings.set_setting("zom_nom_defense/debug/show_navigation_paths", false)
  ProjectSettings.set_initial_value("zom_nom_defense/debug/show_navigation_paths", false)
  ProjectSettings.add_property_info({
    "name": "zom_nom_defense/debug/show_navigation_paths",
    "type": TYPE_BOOL
  })

  if not ProjectSettings.has_setting("zom_nom_defense/debug/show_debug_panel"):
    ProjectSettings.set_setting("zom_nom_defense/debug/show_debug_panel", false)
  ProjectSettings.set_initial_value("zom_nom_defense/debug/show_debug_panel", false)
  ProjectSettings.add_property_info({
    "name": "zom_nom_defense/debug/show_debug_panel",
    "type": TYPE_BOOL
  })

  if not ProjectSettings.has_setting("zom_nom_defense/debug/bypass_tech_requirements"):
    ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", false)
  ProjectSettings.set_initial_value("zom_nom_defense/debug/bypass_tech_requirements", false)
  ProjectSettings.add_property_info({
    "name": "zom_nom_defense/debug/bypass_tech_requirements",
    "type": TYPE_BOOL
  })

  if not ProjectSettings.has_setting("zom_nom_defense/debug/enable_tools"):
    ProjectSettings.set_setting("zom_nom_defense/debug/enable_tools", false)
  ProjectSettings.set_initial_value("zom_nom_defense/debug/enable_tools", false)
  ProjectSettings.add_property_info({
    "name": "zom_nom_defense/debug/enable_tools",
    "type": TYPE_BOOL
  })

  if not ProjectSettings.has_setting("zom_nom_defense/debug/unlock_all_scenarios"):
    ProjectSettings.set_setting("zom_nom_defense/debug/unlock_all_scenarios", false)
  ProjectSettings.set_initial_value("zom_nom_defense/debug/unlock_all_scenarios", false)
  ProjectSettings.add_property_info({
    "name": "zom_nom_defense/debug/unlock_all_scenarios",
    "type": TYPE_BOOL
  })

## Load logging configuration from project settings
func _load_project_settings() -> void:
  # Log level setting
  current_log_level = ProjectSettings.get_setting("zom_nom_defense/logging/log_level", LogLevel.INFO)
  
  # Scopes setting - comma-separated string
  var scopes_setting = ProjectSettings.get_setting("zom_nom_defense/logging/enabled_scopes", "*")
  if scopes_setting is String:
    enabled_scopes = scopes_setting.split(",")
    # Trim whitespace from each scope
    for i in range(enabled_scopes.size()):
      enabled_scopes[i] = enabled_scopes[i].strip_edges()

## Main logging function - checks level and scope before outputting
func _log(level: LogLevel, scope: String, message: String) -> void:
  # Check if logging level is enabled
  if level < current_log_level:
    return
  
  # Check if scope is enabled
  if not _is_scope_enabled(scope):
    return
  
  # Format timestamp
  var time = Time.get_datetime_dict_from_system()
  var unix_time = Time.get_unix_time_from_system()
  var milliseconds = int((unix_time - int(unix_time)) * 1000)
  var timestamp = "%02d:%02d:%02d.%03d" % [
    time.hour, time.minute, time.second, milliseconds
  ]
  
  # Format the log message
  var level_name = _log_level_names[level]
  var color_tag = _log_level_colors[level]
  var formatted_message = "%s[%s] [%s] %s: %s[/color]" % [
    color_tag, timestamp, level_name, scope, message
  ]
  
  # Output to console
  print_rich(formatted_message)
  
  # Emit signal for external listeners (UI, file logging, etc.)
  log_message_emitted.emit(level, scope, message, timestamp)

## Check if a scope is enabled for logging
func _is_scope_enabled(scope: String) -> bool:
  # If "*" is in enabled scopes, all scopes are enabled
  if "*" in enabled_scopes:
    return true
  
  # Check for exact scope match
  if scope in enabled_scopes:
    return true
  
  # Check for wildcard patterns (e.g., "Combat*" matches "Combat.Attack")
  for enabled_scope in enabled_scopes:
    if enabled_scope.ends_with("*"):
      var prefix = enabled_scope.trim_suffix("*")
      if scope.begins_with(prefix):
        return true
  
  return false

## Public logging methods for each level

func trace(scope: String, message: String) -> void:
  _log(LogLevel.TRACE, scope, message)

func debug(scope: String, message: String) -> void:
  _log(LogLevel.DEBUG, scope, message)

func info(scope: String, message: String) -> void:
  _log(LogLevel.INFO, scope, message)

func warning(scope: String, message: String) -> void:
  _log(LogLevel.WARN, scope, message)

func warn(scope: String, message: String) -> void:
  _log(LogLevel.WARN, scope, message)

func error(scope: String, message: String) -> void:
  _log(LogLevel.ERROR, scope, message)

## Runtime configuration methods

## Set the current log level
func set_log_level(level: LogLevel) -> void:
  current_log_level = level
  info("MyLogger", "Log level changed to: %s" % _log_level_names[level])

## Set enabled scopes (array of scope names or wildcard patterns)
func set_enabled_scopes(scopes: PackedStringArray) -> void:
  enabled_scopes = scopes
  info("MyLogger", "Enabled scopes changed to: %s" % ", ".join(scopes))

## Add a scope to the enabled scopes list
func enable_scope(scope: String) -> void:
  if scope not in enabled_scopes:
    enabled_scopes.append(scope)
    info("MyLogger", "Enabled scope: %s" % scope)

## Remove a scope from the enabled scopes list
func disable_scope(scope: String) -> void:
  var index = enabled_scopes.find(scope)
  if index >= 0:
    enabled_scopes.remove_at(index)
    info("MyLogger", "Disabled scope: %s" % scope)

## Utility method to get current configuration as a dictionary
func get_config() -> Dictionary:
  return {
    "log_level": current_log_level,
    "log_level_name": _log_level_names[current_log_level],
    "enabled_scopes": enabled_scopes
  }
