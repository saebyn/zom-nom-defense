# Logging Framework Documentation

This document describes the logging framework implemented for the Tower Defense game, providing scoped logging with configurable log levels.

## Overview

The logging framework provides:
- **Scoped Logging**: Messages organized by scope (e.g., "Economy", "Combat", "UI")
- **Log Levels**: TRACE, DEBUG, INFO, WARN, ERROR
- **Runtime Configuration**: Change log levels and scopes at runtime through the `MyLogger` API
- **Rich Output**: Colored, timestamped log messages
- **Project Settings Integration**: Configure defaults in project settings

## Basic Usage

### Simple Logging
```gdscript
# Basic logging at different levels
MyLogger.debug("Combat", "Calculating damage: %d" % damage)
MyLogger.info("Player", "Player spawned with %d health" % health)
MyLogger.warn("Economy", "Currency running low: %d remaining" % currency)
MyLogger.error("System", "Failed to load config: %s" % config_path)
```

### Hierarchical Scopes
```gdscript
# Use dot notation for hierarchical scopes
MyLogger.debug("Enemy.AI", "Choosing target")
MyLogger.debug("Enemy.Combat", "Attacking target")
MyLogger.debug("Enemy.Animation", "Playing attack animation")
MyLogger.info("UI.Health", "Updating health display")
```

## Log Levels

| Level | Value | Description | When to Use |
|-------|-------|-------------|-------------|
| `TRACE` | `0` | Most detailed messages | Tracing frequent operations |
| `DEBUG` | `1` | Detailed diagnostic information | Development debugging |
| `INFO` | `2` | General informational messages | Important game events, state changes |
| `WARN` | `3` | Warning conditions | Recoverable errors, deprecated usage |
| `ERROR` | `4` | Error conditions | Unrecoverable errors, critical failures |

`NONE` (`5`) exists in the enum but is not supported by the logger configuration. To suppress all log output, set `logging/enabled_scopes` to an empty string.

## Scope Filtering

### Wildcard Patterns
```gdscript
# Enable all Combat-related logging
MyLogger.set_enabled_scopes(["Combat*"])
# This will show: "Combat", "Combat.Attack", "Combat.Defense", etc.

# Enable specific scopes
MyLogger.set_enabled_scopes(["Player", "Economy", "UI"])
# Only these exact scopes will be shown

# Enable everything
MyLogger.set_enabled_scopes(["*"])
```

### Common Scope Conventions

| Scope | Usage |
|-------|-------|
| `Player` | Player actions, input handling |
| `Enemy` | Enemy behavior, AI |
| `Combat` | Damage, attacks, health |
| `Economy` | Currency, resources |
| `UI` | User interface updates |
| `Navigation` | Pathfinding, movement |
| `Spawner` | Enemy/object spawning |
| `Placement` | Object placement validation |
| `System` | Core system operations |

## Project Settings Configuration

Set `zom_nom_defense/logging/log_level` and `zom_nom_defense/logging/enabled_scopes` in Project Settings, or use this configuration in `project.godot`:

```ini
[zom_nom_defense]

logging/log_level=2
logging/enabled_scopes="*"
```

`logging/enabled_scopes` accepts comma-separated scopes or `*` for all scopes.

## Runtime Configuration

```gdscript
# Change log level at runtime
MyLogger.set_log_level(MyLogger.LogLevel.DEBUG)

# Change enabled scopes
MyLogger.set_enabled_scopes(["Economy", "Combat"])

# Add/remove individual scopes
MyLogger.enable_scope("NewFeature")
MyLogger.disable_scope("OldFeature")

# Get current configuration
var config = MyLogger.get_config()
print("Current level: ", config.log_level_name)
print("Enabled scopes: ", config.enabled_scopes)
```

## Performance Considerations

- Log level checking is very fast - disabled levels have minimal overhead
- Scope checking uses string operations - use sparingly in tight loops
- Consider using DEBUG level for verbose logging that can be disabled in production
- The framework emits signals for custom log handlers (file logging, network logging, etc.)

## Migration from print()

Replace existing print statements:

```gdscript
# Before
print("Enemy spawned at: ", position)
print("Currency earned: ", amount)

# After  
MyLogger.info("Spawner", "Enemy spawned at: %s" % position)
MyLogger.info("Economy", "Currency earned: %d" % amount)
```

## Advanced Features

### Signal-Based Logging
```gdscript
func _ready():
    # Connect to log signals for custom handling
    MyLogger.log_message_emitted.connect(_on_log_message)

func _on_log_message(level: MyLogger.LogLevel, scope: String, message: String, timestamp: String):
    # Custom handling (save to file, send to server, etc.)
    pass
```

### Conditional Logging
```gdscript
# Expensive operations only when debug logging is enabled
if MyLogger.current_log_level <= MyLogger.LogLevel.DEBUG:
    var detailed_info = expensive_debug_calculation()
    MyLogger.debug("System", "Detailed info: %s" % detailed_info)
```

## Examples from Codebase

The framework is already integrated throughout the codebase:

- **Currency System**: `MyLogger.info("Economy", "Earned %d currency")` 
- **Enemy Spawning**: `MyLogger.info("Spawner", "Starting wave %d")`
- **Combat**: `MyLogger.debug("Enemy.Combat", "Enemy took %d damage")`
- **Navigation**: `MyLogger.debug("Navigation", "Rebaking navigation mesh")`
- **Placement**: `MyLogger.warn("Placement", "Cannot place building")`

## Testing

The [logger unit tests](../tests/unit/test_logger.gd) cover scope filtering and runtime configuration.
