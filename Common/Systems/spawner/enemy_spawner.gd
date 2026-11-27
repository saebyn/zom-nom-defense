extends Node3D
class_name System_EnemySpawner

@export var spawn_areas: Array[MeshInstance3D] = []
@export var initial_spawn_delay: float = 2.0

var _spawned_enemies: int = 0

var current_enemies: Array[Node3D] = []

# Wave system
var _waves: Array[System_Wave] = []
var _current_wave_index: int = 0

# Signals for wave system
signal wave_started(wave: System_Wave)
signal wave_completed(wave: System_Wave)
signal all_waves_completed()
signal enemy_spawned(enemy: Node3D)

func _ready() -> void:
    # Warn if another spawner is already registered (prevents silent multi-instance bugs)
    if get_tree().get_nodes_in_group("enemy_spawner").size() > 0:
        MyLogger.warn("Spawner", "Another node is already in the 'enemy_spawner' group; only one should be active at a time.")
    add_to_group("enemy_spawner")
    # Monitor child nodes exiting tree to track enemies
    child_exiting_tree.connect(_on_child_exiting_tree)
    # Defer node detection to ensure all children are ready
    _detect_node.call_deferred()

func _detect_node() -> void:
    spawn_areas = spawn_areas.filter(func(a): return a != null)
    if spawn_areas.is_empty():
        MyLogger.warn("Spawner", "No spawn areas assigned in EnemySpawner!")

    # Check for Wave child nodes
    _waves.clear() # Clear in case of multiple calls
    for child in get_children():
        if child is System_Wave:
            _waves.append(child)
    
    MyLogger.info("Spawner", "Using wave node with %d waves" % _waves.size())
    _setup_wave_node()

func _setup_wave_node() -> void:
    # Connect wave signals
    for wave in _waves:
        wave.wave_started.connect(_on_wave_started)
        wave.wave_completed.connect(_on_wave_completed)
        wave.enemy_spawned.connect(_on_enemy_spawned_from_wave)
    
    # Start the first wave
    if not _waves.is_empty():
        _start_next_wave()

func _start_next_wave() -> void:
    if _current_wave_index >= _waves.size():
        all_waves_completed.emit()
        MyLogger.info("Spawner", "All waves completed")
        return
    
    var wave = _waves[_current_wave_index]
    MyLogger.info("Spawner", "Starting wave %d" % (_current_wave_index + 1))
    wave.start_wave()

func _on_wave_started(wave: System_Wave) -> void:
    # Play wave start sound
    AudioManager.play_sound_2d(Resource_SoundEffect.SoundEffect.WAVE_START)
    wave_started.emit(wave)

func _on_wave_completed(wave: System_Wave) -> void:
    # Play wave complete sound
    AudioManager.play_sound_2d(Resource_SoundEffect.SoundEffect.WAVE_COMPLETE)
    wave_completed.emit(wave)
    _current_wave_index += 1
    
    # Start next wave after a brief delay
    await get_tree().create_timer(initial_spawn_delay, false).timeout
    _start_next_wave()

func _on_enemy_spawned_from_wave(enemy: Node3D, _wave: System_Wave) -> void:
    enemy_spawned.emit(enemy)


func spawn_enemy(enemy_type: Resource_EnemyType) -> Variant:
    var enemy = enemy_type.scene.instantiate()

    assert(enemy.has_method("load_resource"), "Enemy scene must have load_resource method")

    enemy.load_resource(enemy_type)

    var spawn_position = find_random_spawn_position()
    if spawn_position == null:
        return null
    else:
        add_child(enemy)
        enemy.global_position = spawn_position
        current_enemies.append(enemy)
        _spawned_enemies += 1
        enemy_spawned.emit(enemy)
        return enemy


func get_spawned_enemy_count() -> int:
    return _spawned_enemies


func _on_child_exiting_tree(node: Node) -> void:
    if node in current_enemies:
        MyLogger.debug("Spawner", "Enemy exited tree")
        current_enemies.erase(node)
        _spawned_enemies -= 1


func find_random_spawn_position() -> Variant:
    # Handle both old single spawn_area and new spawn_areas array for backward compatibility
    var spawn_area_to_use: MeshInstance3D = null
    
    # Randomly select one of the spawn areas
    spawn_area_to_use = spawn_areas.pick_random() as MeshInstance3D

    if spawn_area_to_use == null:
        return null
    
    # Generate a random position within the selected spawn area
    var bounds := spawn_area_to_use.get_aabb()

    MyLogger.debug("Spawner", "Selected spawn area: %s with bounds: %s" % [spawn_area_to_use.name, bounds])

    var spawn_position = spawn_area_to_use.transform.basis * (Vector3(
        randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
        randf_range(bounds.position.y, bounds.position.y + bounds.size.y),
        randf_range(bounds.position.z, bounds.position.z + bounds.size.z)
    ) + spawn_area_to_use.position)
    MyLogger.debug("Spawner", "Local spawn position: %s" % spawn_position)
    return spawn_position

func get_current_wave_number() -> int:
    return _current_wave_index + 1

func get_total_waves() -> int:
    return _waves.size()
