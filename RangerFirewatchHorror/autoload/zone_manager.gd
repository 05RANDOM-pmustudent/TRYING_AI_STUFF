extends Node
## ZoneManager - Zone System (Section 2) + Zone Bleed (Section 8.4)
## Manages zone data profiles, baseline drift, and risk tiers.

signal zone_baseline_changed(zone_id: String, drift_value: float)
signal zone_risk_tier_changed(zone_id: String, new_tier: int)
signal census_mismatch_detected(zone_id: String, expected: int, actual: int)

enum ZoneType {
	NATURAL_HABITAT,
	SETTLEMENT_OUTPOST,
	INFRASTRUCTURE,      # Dam, tower, ranger cabin
	TRANSITIONAL_EDGE,   # Wilderness edge
	RESTRICTED_UNLISTED  # Not on official map
}

enum CameraCoverage {
	DENSE,      # Many cameras, few blind spots
	MODERATE,   # Balanced coverage
	SPARSE      # Few cameras, many blind spots = more field exposure
}

## Zone data profile resource
class ZoneProfile:
	var zone_id: String
	var zone_name: String
	var zone_type: ZoneType
	var camera_coverage: CameraCoverage
	
	# Baseline profile - what counts as "normal" here
	var expected_wildlife_min: int = 0
	var expected_wildlife_max: int = 5
	var expected_npc_count: int = 0
	var ambient_sound_pattern: String = ""
	var lighting_pattern: String = ""
	
	# Risk tier - escalates independently per zone
	var risk_tier: int = 0  # 0-5 scale
	
	# Zone bleed - gradual drift values (Section 8.4)
	var sound_drift: float = 0.0  # -1.0 to 1.0
	var lighting_drift: float = 0.0  # -1.0 to 1.0
	var census_drift_enabled: bool = false
	
	# Blind spot tracking
	var known_blind_spots: Array[String] = []
	
	func _init():
		pass

var zones: Dictionary = {}  # zone_id -> ZoneProfile
var player_current_zone: String = ""

func _ready() -> void:
	pass

func register_zone(zone_data: Dictionary) -> void:
	"""Registers a new zone with its baseline profile."""
	var profile = ZoneProfile.new()
	profile.zone_id = zone_data.get("zone_id", "unknown")
	profile.zone_name = zone_data.get("zone_name", "Unknown Zone")
	profile.zone_type = zone_data.get("zone_type", ZoneType.NATURAL_HABITAT)
	profile.camera_coverage = zone_data.get("camera_coverage", CameraCoverage.MODERATE)
	profile.expected_wildlife_min = zone_data.get("wildlife_min", 0)
	profile.expected_wildlife_max = zone_data.get("wildlife_max", 5)
	profile.expected_npc_count = zone_data.get("npc_count", 0)
	profile.ambient_sound_pattern = zone_data.get("sound_pattern", "default")
	profile.lighting_pattern = zone_data.get("lighting_pattern", "default")
	profile.risk_tier = zone_data.get("risk_tier", 0)
	profile.known_blind_spots = zone_data.get("blind_spots", [])
	
	zones[profile.zone_id] = profile

func get_zone(zone_id: String) -> ZoneProfile:
	"""Returns the zone profile for the given zone ID."""
	return zones.get(zone_id, null)

func get_all_zones() -> Array:
	"""Returns an array of all registered zone IDs."""
	return zones.keys()

func update_zone_risk_tier(zone_id: String, new_tier: int) -> void:
	"""Updates the risk tier for a specific zone."""
	if zones.has(zone_id):
		var old_tier = zones[zone_id].risk_tier
		zones[zone_id].risk_tier = clamp(new_tier, 0, 5)
		if old_tier != new_tier:
			zone_risk_tier_changed.emit(zone_id, new_tier)

func apply_zone_bleed(zone_id: String, sound_delta: float, lighting_delta: float) -> void:
	"""
	Applies gradual drift to a zone's baseline (Section 8.4: Zone Bleed).
	This is the slow-burn dread system - erosion, not jump scares.
	"""
	if not zones.has(zone_id):
		return
	
	var profile = zones[zone_id]
	profile.sound_drift = clamp(profile.sound_drift + sound_delta, -1.0, 1.0)
	profile.lighting_drift = clamp(profile.lighting_drift + lighting_delta, -1.0, 1.0)
	
	# Enable census drift if bleed has progressed enough
	if abs(profile.sound_drift) > 0.3 or abs(profile.lighting_drift) > 0.3:
		profile.census_drift_enabled = true
	
	zone_baseline_changed.emit(zone_id, max(abs(profile.sound_drift), abs(profile.lighting_drift)))

func check_census_mismatch(zone_id: String, actual_count: int) -> bool:
	"""
	Checks for census mismatch (Section 8.1) in the given zone.
	Returns true if a mismatch is detected.
	"""
	if not zones.has(zone_id):
		return false
	
	var profile = zones[zone_id]
	var expected_count = profile.expected_npc_count
	
	# Apply drift-based variance if census drift is enabled
	if profile.census_drift_enabled:
		var drift_variance = int(abs(profile.sound_drift) * 2)  # 0-2 variance based on drift
		if randi_range(0, 100) < 30:  # 30% chance of mismatch when drift is active
			expected_count += randi_range(-drift_variance, drift_variance)
	
	if actual_count != expected_count:
		census_mismatch_detected.emit(zone_id, expected_count, actual_count)
		return true
	
	return false

func get_expected_count_for_zone(zone_id: String) -> int:
	"""Returns the expected creature/person count for a zone."""
	if not zones.has(zone_id):
		return 0
	return zones[zone_id].expected_npc_count

func set_player_zone(zone_id: String) -> void:
	"""Updates the player's current zone location."""
	player_current_zone = zone_id

func get_player_zone() -> String:
	"""Returns the player's current zone."""
	return player_current_zone

func is_zone_bleeding(zone_id: String) -> bool:
	"""Returns true if the zone has significant bleed effects active."""
	if not zones.has(zone_id):
		return false
	var profile = zones[zone_id]
	return abs(profile.sound_drift) > 0.2 or abs(profile.lighting_drift) > 0.2

func reset_zone_bleed(zone_id: String) -> void:
	"""Resets bleed effects for a zone (rare - perhaps after major story event)."""
	if zones.has(zone_id):
		zones[zone_id].sound_drift = 0.0
		zones[zone_id].lighting_drift = 0.0
		zones[zone_id].census_drift_enabled = false
		zone_baseline_changed.emit(zone_id, 0.0)
