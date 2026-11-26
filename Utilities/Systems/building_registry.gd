## Building Registry
## Manages loading and availability of building types based on tech tree unlocks.
## This script should be set as an Autoload in the project settings.
extends Node

signal building_types_updated(added_types: Array[Resource_BuildingType], removed_types: Array[Resource_BuildingType])

var _building_types: Array[Resource_BuildingType] = []
var available_building_types: Array[Resource_BuildingType] = []

@export var building_types_directory: String = "res://Config/Buildings/"
@export var building_type_resource_extension: String = ".tres"


func _ready() -> void:
  MyLogger.info("BuildingRegistry", "Initializing BuildingRegistry...")
  _load_building_types()
  
  # Connect to TechTreeManager (autoload singleton)
  TechTreeManager.tech_unlocked.connect(_on_tech_unlocked)
  MyLogger.info("BuildingRegistry", "Connected to TechTreeManager")
  
  # Refresh after loading a slot or rolling back an unsuccessful attempt.
  TechTreeManager.progression_loaded.connect(_update_available_buildings)
  
  # Do initial update of available buildings
  # This will be updated again when save data loads
  _update_available_buildings()
  MyLogger.info("BuildingRegistry", "BuildingRegistry initialized with %d total buildings, %d available" % [_building_types.size(), available_building_types.size()])


## Load all building type resources from the buildings directory
func _load_building_types() -> void:
  _building_types.clear()
  var dir = DirAccess.open(building_types_directory)
  if not dir:
    MyLogger.error("BuildingRegistry", "Could not open buildings directory: %s" % building_types_directory)
    return
  
  dir.list_dir_begin()
  var file_name = dir.get_next()
  while file_name != "":
    if file_name.ends_with(building_type_resource_extension):
      var file_path = building_types_directory + file_name
      var resource = ResourceLoader.load(file_path)
      if resource and resource is Resource_BuildingType:
        _building_types.append(resource)
        MyLogger.debug("BuildingRegistry", "Loaded building type: %s (%s)" % [resource.id, resource.name])
      else:
        MyLogger.warn("BuildingRegistry", "Failed to load building type from: %s" % file_path)
    file_name = dir.get_next()


## Update the list of available buildings based on tech tree state
func _update_available_buildings() -> void:
  var added_types: Array[Resource_BuildingType] = []
  var removed_types: Array[Resource_BuildingType] = []
  var updated_available: Array[Resource_BuildingType] = []
  
  for building_type in _building_types:
    var is_unlocked = _is_building_unlocked(building_type)
    var was_available = building_type in available_building_types
    
    if is_unlocked:
      updated_available.append(building_type)
      if not was_available:
        added_types.append(building_type)
        MyLogger.info("BuildingRegistry", "Building unlocked: %s (%s)" % [building_type.id, building_type.name])
    elif was_available:
      removed_types.append(building_type)
      MyLogger.info("BuildingRegistry", "Building locked: %s (%s)" % [building_type.id, building_type.name])
  
  available_building_types = updated_available
  
  if added_types.size() > 0 or removed_types.size() > 0:
    building_types_updated.emit(added_types, removed_types)


## Check if a building is unlocked based on tech tree
func _is_building_unlocked(building_type: Resource_BuildingType) -> bool:
  # If no tech requirements, building is always unlocked
  if building_type.required_tech_ids.is_empty():
    return true
  
  # All required techs must be unlocked
  for tech_id in building_type.required_tech_ids:
    if not TechTreeManager.is_tech_unlocked(tech_id):
      return false
  
  return true


## Called when a tech is unlocked
func _on_tech_unlocked(tech_id: String) -> void:
  MyLogger.debug("BuildingRegistry", "Tech unlocked: %s - checking for new buildings" % tech_id)
  _update_available_buildings()


## Get a building type by ID
func get_building_type(building_id: String) -> Resource_BuildingType:
  for building_type in _building_types:
    if building_type.id == building_id:
      return building_type
  return null


## Check if a building is available
func is_building_available(building_id: String) -> bool:
  for building_type in available_building_types:
    if building_type.id == building_id:
      return true
  return false
