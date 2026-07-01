extends Node
## CameraSystem - Camera System (Section 3) + Phantom State (Section 8)
## Manages camera status, health, damage ambiguity, and phantom states.

signal camera_status_changed(camera_id: String, new_status: String, old_status: String)
signal camera_health_changed(camera_id: String, new_health: float)
signal phantom_detected(camera_id: String, phantom_type: String)

enum CameraStatus {
	ONLINE,     # Normal operation
	STATIC,     # Interference, degraded signal
	OFFLINE,    # No signal, complete failure
	PHANTOM     # Horror state - shows impossible content (Section 8)
}

enum DamageType {
	MUNDANE,      # Storm, chewed cable, age - explainable
	NON_MUNDANE,  # No environmental cause - horror
	UNKNOWN       # Not yet determined - early game ambiguity
}

## Camera data profile
class CameraProfile:
	var camera_id: String
	var home_zone: String
	var status: CameraStatus = CameraStatus.ONLINE
	var health: float = 100.0
	var is_pannable: bool = false
	var damage_type: DamageType = DamageType.UNKNOWN
	var last_known_position: Vector2 = Vector2.ZERO
	
	# For phantom state tracking
	var phantom_content_type: String = ""  # "self_sighting", "zone_bleed", etc.
	
	func _init():
		pass

var cameras: Dictionary = {}  # camera_id -> CameraProfile
var player_position: Vector2 = Vector2.ZERO  # Track player independently (Section 8.3)

func _ready() -> void:
	pass

func register_camera(camera_data: Dictionary) -> void:
	"""Registers a new camera with its profile."""
	var profile = CameraProfile.new()
	profile.camera_id = camera_data.get("camera_id", "unknown")
	profile.home_zone = camera_data.get("home_zone", "")
	profile.health = camera_data.get("health", 100.0)
	profile.is_pannable = camera_data.get("pannable", false)
	profile.last_known_position = camera_data.get("position", Vector2.ZERO)
	
	cameras[profile.camera_id] = profile

func get_camera(camera_id: String) -> CameraProfile:
	"""Returns the camera profile for the given camera ID."""
	return cameras.get(camera_id, null)

func get_all_cameras() -> Array:
	"""Returns an array of all registered camera IDs."""
	return cameras.keys()

func get_cameras_in_zone(zone_id: String) -> Array:
	"""Returns all cameras in a specific zone."""
	var result = []
	for cam_id in cameras:
		if cameras[cam_id].home_zone == zone_id:
			result.append(cam_id)
	return result

func update_camera_status(camera_id: String, new_status: CameraStatus) -> void:
	"""Updates a camera's status and emits change signal."""
	if not cameras.has(camera_id):
		return
	
	var profile = cameras[camera_id]
	var old_status_name = CameraStatus.keys()[profile.status]
	profile.status = new_status
	var new_status_name = CameraStatus.keys()[new_status]
	
	camera_status_changed.emit(camera_id, new_status_name, old_status_name)

func damage_camera(camera_id: String, amount: float, cause: DamageType) -> void:
	"""
	Applies damage to a camera. Early game, mundane and non-mundane causes
	should look identical (Section 3: Damage Ambiguity).
	"""
	if not cameras.has(camera_id):
		return
	
	var profile = cameras[camera_id]
	profile.damage_type = cause  # Store internally, but don't reveal to player yet
	profile.health = max(0.0, profile.health - amount)
	
	camera_health_changed.emit(camera_id, profile.health)
	
	# Update status based on health thresholds
	if profile.health <= 0:
		update_camera_status(camera_id, CameraStatus.OFFLINE)
	elif profile.health < 50:
		update_camera_status(camera_id, CameraStatus.STATIC)

func set_phantom_state(camera_id: String, phantom_type: String) -> void:
	"""
	Sets a camera to PHANTOM state with specific impossible content.
	Used for Self-Sighting (8.3) and late Zone-Bleed events (8.4).
	"""
	if not cameras.has(camera_id):
		return
	
	var profile = cameras[camera_id]
	profile.status = CameraStatus.PHANTOM
	profile.phantom_content_type = phantom_type
	
	camera_status_changed.emit(camera_id, "PHANTOM", CameraStatus.keys()[profile.status])
	phantom_detected.emit(camera_id, phantom_type)

func clear_phantom_state(camera_id: String) -> void:
	"""Clears phantom state from a camera (returns to normal or damaged state)."""
	if not cameras.has(camera_id):
		return
	
	var profile = cameras[camera_id]
	profile.phantom_content_type = ""
	
	# Return to appropriate status based on health
	if profile.health <= 0:
		profile.status = CameraStatus.OFFLINE
	elif profile.health < 50:
		profile.status = CameraStatus.STATIC
	else:
		profile.status = CameraStatus.ONLINE
	
	camera_status_changed.emit(camera_id, CameraStatus.keys()[profile.status], "PHANTOM")

func update_player_position(new_position: Vector2) -> void:
	"""
	Updates the player's position independently of camera positions.
	Required for Self-Sighting detection (Section 8.3).
	"""
	player_position = new_position

func get_player_position() -> Vector2:
	"""Returns the current player position."""
	return player_position

func is_player_near_camera(camera_id: String, threshold: float = 10.0) -> bool:
	"""Checks if the player is near a specific camera."""
	if not cameras.has(camera_id):
		return false
	
	var camera_pos = cameras[camera_id].last_known_position
	return player_position.distance_to(camera_pos) < threshold

func repair_camera(camera_id: String, repair_amount: float) -> bool:
	"""
	Attempts to repair a camera. Returns true if successful.
	Repairing can occasionally reveal something the feed never showed (Section 6).
	"""
	if not cameras.has(camera_id):
		return false
	
	var profile = cameras[camera_id]
	profile.health = min(100.0, profile.health + repair_amount)
	
	camera_health_changed.emit(camera_id, profile.health)
	
	# Clear offline/static status if health is restored
	if profile.health > 50 and profile.status != CameraStatus.PHANTOM:
		update_camera_status(camera_id, CameraStatus.ONLINE)
	
	return true

func get_damage_ambiguity_report(camera_id: String) -> Dictionary:
	"""
	Returns a damage report that deliberately obscures the true cause.
	Early game, mundane and non-mundane damage should look identical.
	"""
	if not cameras.has(camera_id):
		return {}
	
	var profile = cameras[camera_id]
	var report = {
		"camera_id": camera_id,
		"health": profile.health,
		"status": CameraStatus.keys()[profile.status],
		"visible_damage": _get_visible_damage_description(profile),
		# Note: damage_type is NOT included - player can't tell the difference yet
	}
	
	return report

func _get_visible_damage_description(profile: CameraProfile) -> String:
	"""Returns a generic damage description that works for both mundane and non-mundane causes."""
	if profile.health > 75:
		return "Minor interference detected"
	elif profile.health > 50:
		return "Signal degradation visible"
	elif profile.health > 25:
		return "Significant damage to equipment"
	else:
		return "Critical failure - equipment non-functional"
