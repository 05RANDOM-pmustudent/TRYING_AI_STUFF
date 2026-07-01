extends Node
## FootageArchive - Footage Archive/Playback System (Section 8.2: Retroactive Dread)
## Manages recorded clips, scrub/review interface data, and live-vs-archive differences.

signal footage_review_started(camera_id: String, clip_id: String)
signal footage_review_ended()
signal retroactive_anomaly_detected(clip_id: String, anomaly_type: String, description: String)
signal diff_flag_set(clip_id: String, has_diff: bool)

enum ClipQuality {
	CLEAR,      # Normal recording quality
	DEGRADED,   # Some static/interference
	CORRUPTED   # Heavily corrupted, may hide or reveal anomalies
}

## Recorded clip data structure
class FootageClip:
	var clip_id: String
	var camera_id: String
	var zone_id: String
	var start_time: float
	var end_time: float
	var duration: float
	var quality: ClipQuality = ClipQuality.CLEAR
	
	# Content tracking
	var objects_in_frame: Array[String] = []
	var entity_count: int = 0
	var baseline_snapshot: Dictionary = {}  # What was "normal" when recorded
	
	# Retroactive dread - things that appear only in archive
	var retroactive_anomalies: Array[Dictionary] = []  # Anomalies not seen in live view
	var diff_from_live: bool = false  # Flag: differs from what player saw live
	
	# Playback state
	var is_archived: bool = true
	var can_scrub: bool = true
	
	func _init():
		pass

var clips: Dictionary = {}  # clip_id -> FootageClip
var current_review_clip: String = ""  # Currently being reviewed clip ID
var review_mode_active: bool = false

func _ready() -> void:
	pass

func create_clip(camera_id: String, zone_id: String, duration: float, start_time: float) -> String:
	"""Creates a new footage clip entry."""
	var clip_id = "CLIP_%s_%d" % [camera_id, Time.get_ticks_msec()]
	
	var clip = FootageClip.new()
	clip.clip_id = clip_id
	clip.camera_id = camera_id
	clip.zone_id = zone_id
	clip.start_time = start_time
	clip.end_time = start_time + duration
	clip.duration = duration
	
	clips[clip_id] = clip
	return clip_id

func set_clip_content(clip_id: String, objects: Array[String], entity_count: int) -> void:
	"""Records the content of a clip (what was actually in frame)."""
	if not clips.has(clip_id):
		return
	
	var clip = clips[clip_id]
	clip.objects_in_frame = objects
	clip.entity_count = entity_count

func mark_clip_as_live_viewed(clip_id: String, viewed_objects: Array[String], viewed_count: int) -> void:
	"""
	Marks what the player saw during live viewing. Used later to detect diffs.
	This is critical for Retroactive Dread - comparing memory vs archive.
	"""
	if not clips.has(clip_id):
		return
	
	var clip = clips[clip_id]
	clip.baseline_snapshot = {
		"objects": viewed_objects,
		"count": viewed_count,
		"viewed_at": Time.get_ticks_msec() / 1000.0
	}

func add_retroactive_anomaly(clip_id: String, anomaly_type: String, description: String, frame_position: float) -> void:
	"""
	Adds an anomaly that only appears when reviewing archived footage.
	This is the core of Section 8.2: Retroactive Dread.
	"""
	if not clips.has(clip_id):
		return
	
	var clip = clips[clip_id]
	var anomaly = {
		"type": anomaly_type,
		"description": description,
		"frame_position": frame_position,  # 0.0 to 1.0 through the clip
		"detected_in_archive": true,
		"was_visible_live": false
	}
	
	clip.retroactive_anomalies.append(anomaly)
	clip.diff_from_live = true
	
	diff_flag_set.emit(clip_id, true)
	retroactive_anomaly_detected.emit(clip_id, anomaly_type, description)

func start_review(clip_id: String) -> bool:
	"""Starts reviewing a clip. Returns true if successful."""
	if not clips.has(clip_id):
		return false
	
	current_review_clip = clip_id
	review_mode_active = true
	
	var clip = clips[clip_id]
	footage_review_started.emit(clip.camera_id, clip_id)
	
	return true

func end_review() -> void:
	"""Ends the current review session."""
	current_review_clip = ""
	review_mode_active = false
	footage_review_ended.emit()

func get_clip(clip_id: String) -> FootageClip:
	"""Returns the clip data for the given clip ID."""
	return clips.get(clip_id, null)

func get_clips_for_camera(camera_id: String) -> Array:
	"""Returns all clips from a specific camera."""
	var result = []
	for clip_id in clips:
		if clips[clip_id].camera_id == camera_id:
			result.append(clip_id)
	return result

func get_clips_for_zone(zone_id: String) -> Array:
	"""Returns all clips from a specific zone."""
	var result = []
	for clip_id in clips:
		if clips[clip_id].zone_id == zone_id:
			result.append(clip_id)
	return result

func check_diff_exists(clip_id: String) -> bool:
	"""Checks if a clip has differences between live view and archive."""
	if not clips.has(clip_id):
		return false
	return clips[clip_id].diff_from_live

func get_retroactive_anomalies(clip_id: String) -> Array:
	"""Returns all retroactive anomalies for a clip."""
	if not clips.has(clip_id):
		return []
	return clips[clip_id].retroactive_anomalies.duplicate()

func scrub_to_position(clip_id: String, position: float) -> Dictionary:
	"""
	Returns what's visible at a specific position in the clip (0.0 to 1.0).
	Used for implementing scrub/review UI.
	"""
	if not clips.has(clip_id):
		return {}
	
	var clip = clips[clip_id]
	var visible_anomalies = []
	
	# Check for anomalies at this position
	for anomaly in clip.retroactive_anomalies:
		if abs(anomaly["frame_position"] - position) < 0.05:  # Within 5% tolerance
			visible_anomalies.append(anomaly)
	
	return {
		"clip_id": clip_id,
		"position": position,
		"objects_visible": clip.objects_in_frame,
		"entity_count": clip.entity_count,
		"anomalies_at_position": visible_anomalies,
		"quality": ClipQuality.keys()[clip.quality]
	}

func set_clip_quality(clip_id: String, quality: ClipQuality) -> void:
	"""Sets the quality of a clip (affects visibility of anomalies)."""
	if not clips.has(clip_id):
		return
	clips[clip_id].quality = quality

func purge_old_clips(max_age_seconds: float) -> int:
	"""Removes clips older than the specified age. Returns count of purged clips."""
	var current_time = Time.get_ticks_msec() / 1000.0
	var purged_count = 0
	var to_remove = []
	
	for clip_id in clips:
		var clip = clips[clip_id]
		if current_time - clip.end_time > max_age_seconds:
			to_remove.append(clip_id)
	
	for clip_id in to_remove:
		clips.erase(clip_id)
		purged_count += 1
	
	return purged_count
