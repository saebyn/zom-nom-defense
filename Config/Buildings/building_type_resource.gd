extends Resource
class_name Resource_BuildingType

enum BuildingCategory {
  BASIC
}

@export_category("Basic Properties")
@export var id: String = "" ## Unique identifier for the building type
@export var name: String = "New Building Type" ## Name of the building type
@export var description: String = "Description of the building type." ## Description of the building type
@export var icon: Texture2D ## Icon representing the building type
@export var color: Color = Color(1, 1, 1) ## Color associated with the building type
@export var category: BuildingCategory = BuildingCategory.BASIC ## Category of the building type

@export_category("Gameplay Properties")
@export var is_offensive: bool = false ## Whether the building type is offensive
@export var cost: int = 0 ## Cost associated with the building type
@export var scene: PackedScene ## Scene representing the building type. Should be a PlaceableBuilding.
@export var preview: PackedScene ## Scene used for previewing the building in the world.

@export_category("Tech Tree Integration")
@export var required_tech_ids: Array[String] = [] ## Technology IDs that must be unlocked to use this building. If empty, building is available from the start.

func is_valid() -> bool:
  return not id.is_empty() and scene != null
