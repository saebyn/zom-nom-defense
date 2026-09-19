extends AudioListener3D

## Audio listener that follows the camera's ground focus point
## In an orthographic/isometric view, this approximates where the viewer's attention is

@export var camera_rig: Node3D

# Track the last known focus point to avoid unnecessary updates
var _last_focus_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	if not camera_rig:
		MyLogger.warn("AudioListener", "No camera rig assigned to audio listener")
		return
	
	# Enable this as the active listener
	make_current()
	MyLogger.info("AudioListener", "Audio listener initialized and activated")


func _process(_delta: float) -> void:
	if not camera_rig:
		return

	var focus_position := camera_rig.global_position

	# Only update position if the focus point has changed to improve performance
	if focus_position != _last_focus_position:
		_last_focus_position = focus_position
		# Position the audio listener at the ground focus point
		# This makes spatial audio sound relative to where the player is looking
		global_position = focus_position
