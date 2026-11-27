# Class Hierarchy and Naming Conventions

This document describes the class hierarchy, naming conventions, and organizational structure for nodes and scripts in Zom Nom Defense.

## Table of Contents

- [Overview](#overview)
- [Naming Conventions](#naming-conventions)
- [Class Organization](#class-organization)
- [Components vs Entities](#components-vs-entities)
- [Complete Class Reference](#complete-class-reference)

---

## Overview

All custom classes in Zom Nom Defense use a prefix-based naming system to organize them logically in Godot's "Create New Node" dialog. This makes it easy to find and use the right classes when building scenes.

### Benefits of Prefix-Based Naming

1. **Logical Grouping**: Related classes appear together alphabetically
2. **Easy Discovery**: Find what you need by category prefix
3. **Clear Purpose**: Class name immediately indicates its role
4. **Scalability**: Easy to add new classes within existing categories

---

## Naming Conventions

### Class Name Format

```gdscript
class_name <Prefix>_<DescriptiveName>
```

### Prefix Categories

| Prefix | Category | Purpose | Examples |
|--------|----------|---------|----------|
| `Component_` | Components | Reusable behavior modules | `Component_Health`, `Component_Attack` |
| `UI_` | User Interface | UI controls and displays | `UI_Hotbar`, `UI_Minimap` |
| `Resource_` | Resources | Data-only resource files | `Resource_EnemyType`, `Resource_BuildingType` |
| `Entity_` | Game Entities | In-game objects with physics | `Entity_PlaceableBuilding`, `Entity_Scrap` |
| `System_` | Game Systems | High-level game logic | `System_EnemySpawner`, `System_Wave` |
| `Effect_` | Visual/Audio Effects | Effect controllers | `Effect_Shake` |
| `Utility_` | Utilities | Helper classes and tools | `Utility_BuildingPlacement` |
| `Stage_` | Stages/Scenarios | Scenario classes | `Stage_Scenario` |

---

## Class Organization

### Components (`Component_*`)

**Location**: `Common/Components/`

Components are reusable, modular pieces of functionality that can be attached to entities as child nodes. They provide specific behaviors like health management, attack logic, or status effects.

**Key Characteristics:**

- Use script classes (`.gd` files) for behavior
- Use reusable scenes (`.tscn` files) when components need child nodes or shared scene setup
- Extend from base Godot nodes (`Node`, `Area3D`, etc.)
- Register themselves in parent's metadata for discovery
- Focus on single responsibility

**Usage Example:**

```gdscript
# Instance health.tscn as a child of the entity.
# Component registers itself automatically in _ready()
var health: Component_Health
func _ready():
  if has_meta("health_component"):
    health = get_meta("health_component")
```

Instantiate the [Health Component scene](../Common/Components/health/health.tscn) for its health display and the [Attack Component scene](../Common/Components/attack/attack.tscn) for its wired attack timer. The game instantiates both scenes as reusable child nodes.

---

### User Interface (`UI_*`)

**Location**: `Common/UI/` and `Stages/UI/`

UI classes handle player interaction, information display, and menu systems.

**Key Characteristics:**

- Extend from Control nodes or UI-specific base classes
- May be scenes with complex hierarchies
- Connected to game systems via signals and autoloads

---

### Resources (`Resource_*`)

**Location**: `Config/`

Resource classes are pure data containers extending Godot's `Resource` class. They store configuration for enemies, buildings, achievements, etc.

**Key Characteristics:**

- Extend from `Resource`
- No logic, only data properties
- Saved as `.tres` files
- Designer-editable in Godot Inspector

**Usage Example:**

```gdscript
# Defined in resource file
@export var enemy_types: Array[Resource_EnemyType] = []

# Loaded from .tres file
var enemy_config = load("res://Config/Enemies/grunt_config.tres") as Resource_EnemyType
```

---

### Entities (`Entity_*`)

**Location**: `Entities/`

Entities are game objects with physics bodies and scene hierarchies. They represent placeable objects in the game world.

**Key Characteristics:**

- ✅ **Should be scenes** (`.tscn` files with attached scripts)
- Extend from physics nodes (`StaticBody3D`, `CharacterBody3D`, etc.)
- Have child nodes (meshes, collision shapes, components)
- Composed with components for behavior

**Why Entities Should Be Scenes:**

1. **Visual Editing**: Easier to position child nodes (meshes, lights, particles)
2. **Hierarchy Management**: Complex node structures are easier in scene editor
3. **3D Model Integration**: Can directly place imported models and adjust transforms
4. **Component Composition**: Easy to add/remove component children visually
5. **Designer-Friendly**: Non-programmers can create variants

---

### Systems (`System_*`)

**Location**: `Common/Systems/`

Systems handle high-level game logic and coordination between entities.

---

### Effects (`Effect_*`)

**Location**: `Common/Effects/`

Effect classes control visual and audio effects.

---

### Utilities (`Utility_*`)

**Location**: `Utilities/`

Utility classes provide helper functionality and tools.

---

### Stages (`Stage_*`)

**Location**: `Stages/`

Stage classes represent levels and scenarios.

---

## Components vs Entities

This is a critical architectural distinction in Zom Nom Defense:

### Components = Reusable Behavior

**What they are:**

- Modules that provide a specific behavior
- Lightweight and reusable
- Can include supporting nodes without representing a full entity

**File structure:**

```
Common/Components/health/
├── health.gd          (class_name Component_Health)
├── health.gd.uid
└── health.tscn        (reusable component scene)
```

**How to use:**

```gdscript
# In the entity scene, instance health.tscn as a child node.
# Script automatically registers in parent metadata

# In entity script:
var health: Component_Health
func _ready():
  if has_meta("health_component"):
    health = get_meta("health_component")
```

### Entities = Scenes (with Scripts)

**What they are:**

- Complete game objects
- Have physics bodies and visual representations
- Composed of multiple child nodes

**File structure:**

```
Entities/Buildings/Templates/placeable_building/
├── building.gd        ✅ (class_name Entity_PlaceableBuilding)
├── building.tscn      ✅ (scene file)
├── building.gd.uid
└── building.tscn.uid
```

**Why the distinction matters:**

1. **Reusability**: Same component on many entity types
2. **Clarity**: Clear separation between behavior (component) and object (entity)
3. **Testing**: Components can be unit tested independently
4. **Maintenance**: Changes to component behavior affect all users automatically

---

## Best Practices

### When Creating New Classes

1. **Choose the right prefix** based on the class's primary role
2. **Follow the naming format**: `<Prefix>_<DescriptiveName>`
3. **Use PascalCase** for the descriptive name part
4. **Be specific** but not verbose: `Component_Health` not `Component_HealthManagementSystem`
5. **Avoid abbreviations** unless universally understood: `UI_FpsOverlay` is OK

### Component Guidelines

✅ **DO:**

- Use a single `.gd` file when a component doesn't need child nodes or shared scene setup
- Extend from appropriate Godot base node
- Register in parent metadata in `_ready()`
- Focus on single responsibility
- Use `@export` for designer-configurable properties

❌ **DON'T:**

- Put game logic in components (they're behavior, not brains)
- Hard-code references to specific entities
- Use `get_node()` to find components (use metadata)

### Entity Guidelines

✅ **DO:**

- Create entities as `.tscn` scenes with attached scripts
- Compose behavior using component children
- Keep entity scripts as "glue" between components
- Use scenes for anything with visual representation

❌ **DON'T:**

- Instantiate entities directly from scripts (load scene instead)
- Duplicate component logic in entity scripts
- Create complex inheritance hierarchies

---

## Conclusion

This naming and organizational system provides:

- ✅ **Discoverability**: Easy to find classes by category
- ✅ **Clarity**: Class purpose is immediately apparent
- ✅ **Consistency**: All classes follow same naming pattern
- ✅ **Scalability**: Easy to add new classes without confusion
- ✅ **Best Practices**: Components and entities clearly separated

When in doubt, refer to this document and follow the established patterns. Consistency is key to maintainability!

---

## Component_DamageNumbers Reference

`Common/Components/damage_numbers/damage_numbers.gd`

Displays floating damage numbers and scrap gain feedback above entities. Creates `Label3D` nodes dynamically — no scene file required. Registers itself in the parent's metadata as `"damage_numbers_component"` for discovery.

### Configuration Exports

| Export | Default | Description |
|---|---|---|
| `fade_duration` | `1.5` | Fade-out duration in seconds |
| `float_distance` | `2.0` | Upward travel distance |
| `vertical_offset` | `2.0` | Height above entity origin |
| `show_damage_numbers` | `true` | Toggle damage number display |
| `show_scrap_gain` | `true` | Toggle scrap gain display |

### Key Methods

- `show_damage(amount, damage_source)` — display a colour-coded damage number
- `show_scrap(amount)` — display a gold "+N" scrap gain number

### Color Mapping

| Type | Color | Trigger |
|---|---|---|
| Normal | White | default |
| Fire | Orange | `"fire"`, `"flame"` |
| Ice | Cyan | `"ice"`, `"frost"`, `"cold"` |
| Poison | Purple | `"poison"`, `"toxic"` |
| Critical | Red | `"critical"`, `"crit"` |
| Scrap gain | Gold | `show_scrap()` |

### Integration Pattern

```gdscript
# Discovery via parent metadata (used by Component_Health and enemy.gd)
if parent.has_meta("damage_numbers_component"):
    var dn = parent.get_meta("damage_numbers_component")
    dn.show_damage(amount, damage_source)
```

Add `Component_DamageNumbers` as a child of any `Node3D` entity (enemies, survivors, buildings, scrap boxes) to enable feedback. The component auto-registers on `_ready()`.
