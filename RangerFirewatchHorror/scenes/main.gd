extends Node
## Main scene controller - connects UI to game systems

@onready var status_label: Label = $CameraBoard/StatusLabel
@onready var shift_timer: Label = $CameraBoard/ShiftTimer
@onready var credibility_meter: ProgressBar = $CameraBoard/CredibilityMeter
@onready var zone_panel: Panel = $CameraBoard/ZonePanel
@onready var hq_message_log: RichTextLabel = $HQMessageLog
@onready var log_button: Button = $ActionButtons/LogButton
@onready var escalate_button: Button = $ActionButtons/EscalateButton
@onready var investigate_button: Button = $ActionButtons/InvestigateButton
@onready var review_button: Button = $ActionButtons/ReviewButton

var current_zone_data: Dictionary = {}
var sample_zones_initialized: bool = false

func _ready() -> void:
	# Initialize sample zones for testing
	_initialize_sample_zones()
	_initialize_sample_cameras()
	
	# Connect to system signals
	GameManager.shift_started.connect(_on_shift_started)
	GameManager.shift_ended.connect(_on_shift_ended)
	GameManager.phase_changed.connect(_on_phase_changed)
	
	CredibilityManager.credibility_changed.connect(_on_credibility_changed)
	CredibilityManager.hq_response_type_changed.connect(_on_hq_response_changed)
	
	HQReportSystem.hq_message_received.connect(_on_hq_message_received)
	HQReportSystem.report_submitted.connect(_on_report_submitted)
	
	CameraSystem.camera_status_changed.connect(_on_camera_status_changed)
	CameraSystem.phantom_detected.connect(_on_phantom_detected)
	
	ZoneManager.zone_baseline_changed.connect(_on_zone_bleed)
	ZoneManager.census_mismatch_detected.connect(_on_census_mismatch)
	
	EscalationManager.escalation_phase_changed.connect(_on_escalation_phase_changed)
	EscalationManager.horror_event_triggered.connect(_on_horror_event)
	
	FootageArchive.retroactive_anomaly_detected.connect(_on_retroactive_anomaly)
	
	# Connect button actions
	log_button.pressed.connect(_on_log_pressed)
	escalate_button.pressed.connect(_on_escalate_pressed)
	investigate_button.pressed.connect(_on_investigate_pressed)
	review_button.pressed.connect(_on_review_pressed)
	
	# Start first shift
	GameManager.start_new_shift()
	_update_ui()

func _initialize_sample_zones() -> void:
	if sample_zones_initialized:
		return
	
	# Register sample zones with different types
	var zones_data = [
		{
			"zone_id": "zone_north",
			"zone_name": "North Ridge",
			"zone_type": ZoneManager.ZoneType.NATURAL_HABITAT,
			"camera_coverage": ZoneManager.CameraCoverage.MODERATE,
			"wildlife_min": 2,
			"wildlife_max": 5,
			"npc_count": 0,
			"sound_pattern": "wind_trees",
			"lighting_pattern": "natural_daylight",
			"risk_tier": 0
		},
		{
			"zone_id": "zone_tower",
			"zone_name": "Fire Watch Tower",
			"zone_type": ZoneManager.ZoneType.INFRASTRUCTURE,
			"camera_coverage": ZoneManager.CameraCoverage.DENSE,
			"wildlife_min": 0,
			"wildlife_max": 1,
			"npc_count": 1,
			"sound_pattern": "radio_static",
			"lighting_pattern": "artificial_light",
			"risk_tier": 0
		},
		{
			"zone_id": "zone_dam",
			"zone_name": "Old Dam Facility",
			"zone_type": ZoneManager.ZoneType.INFRASTRUCTURE,
			"camera_coverage": ZoneManager.CameraCoverage.SPARSE,
			"wildlife_min": 1,
			"wildlife_max": 3,
			"npc_count": 0,
			"sound_pattern": "water_flow",
			"lighting_pattern": "dim_industrial",
			"risk_tier": 0
		},
		{
			"zone_id": "zone_edge",
			"zone_name": "Wilderness Edge",
			"zone_type": ZoneManager.ZoneType.TRANSITIONAL_EDGE,
			"camera_coverage": ZoneManager.CameraCoverage.SPARSE,
			"wildlife_min": 3,
			"wildlife_max": 8,
			"npc_count": 0,
			"sound_pattern": "mixed_wildlife",
			"lighting_pattern": "dappled_sunlight",
			"risk_tier": 0
		}
	]
	
	for zone_data in zones_data:
		ZoneManager.register_zone(zone_data)
	
	sample_zones_initialized = true

func _initialize_sample_cameras() -> void:
	# Register sample cameras
	var cameras_data = [
		{"camera_id": "cam_north_01", "home_zone": "zone_north", "health": 100.0, "pannable": false},
		{"camera_id": "cam_north_02", "home_zone": "zone_north", "health": 85.0, "pannable": true},
		{"camera_id": "cam_tower_01", "home_zone": "zone_tower", "health": 100.0, "pannable": true},
		{"camera_id": "cam_dam_01", "home_zone": "zone_dam", "health": 60.0, "pannable": false},
		{"camera_id": "cam_edge_01", "home_zone": "zone_edge", "health": 95.0, "pannable": false}
	]
	
	for cam_data in cameras_data:
		CameraSystem.register_camera(cam_data)

func _update_ui() -> void:
	status_label.text = "Shift %d - %s" % [GameManager.current_shift, GameManager.ShiftPhase.keys()[GameManager.current_phase]]
	shift_timer.text = "Time: " + GameManager.get_time_remaining_formatted()
	credibility_meter.value = CredibilityManager.current_credibility

func _on_shift_started(shift_number: int) -> void:
	hq_message_log.append_text("\n[b]=== Shift %d Started ===[/b]\n" % shift_number)
	_update_ui()

func _on_shift_ended(success: bool) -> void:
	var result_text = "successful" if success else "failed"
	hq_message_log.append_text("\n[b]=== Shift Ended: %s ===[/b]\n" % result_text)
	_update_ui()

func _on_phase_changed(old_phase: String, new_phase: String) -> void:
	hq_message_log.append_text("\n[i]Phase changed: %s → %s[/i]" % [old_phase, new_phase])
	_update_ui()

func _on_credibility_changed(new_value: float, old_value: float) -> void:
	credibility_meter.value = new_value
	var delta = new_value - old_value
	var sign = "+" if delta > 0 else ""
	hq_message_log.append_text("\nCredibility: %.0f (%s%.0f)" % [new_value, sign, delta])

func _on_hq_response_changed(new_response_type: String) -> void:
	hq_message_log.append_text("\n[b]HQ Response Type:[/b] %s" % [new_response_type.capitalize()])

func _on_hq_message_received(message: String, sender_reliability: String) -> void:
	hq_message_log.append_text("\n[b]HQ (%s):[/b] %s" % [sender_reliability.capitalize(), message])

func _on_report_submitted(report_id: String, report_data: Dictionary) -> void:
	hq_message_log.append_text("\nReport submitted: %s - %s" % [report_id, report_data.anomaly_type])

func _on_camera_status_changed(camera_id: String, new_status: String, old_status: String) -> void:
	hq_message_log.append_text("\n[color=yellow]Camera %s: %s → %s[/color]" % [camera_id, old_status, new_status])

func _on_phantom_detected(camera_id: String, phantom_type: String) -> void:
	hq_message_log.append_text("\n[color=red][b]PHANTOM DETECTED on %s: %s[/b][/color]" % [camera_id, phantom_type])

func _on_zone_bleed(zone_id: String, drift_value: float) -> void:
	hq_message_log.append_text("\n[color=purple]Zone Bleed detected in %s (intensity: %.2f)[/color]" % [zone_id, drift_value])

func _on_census_mismatch(zone_id: String, expected: int, actual: int) -> void:
	var direction = "extra" if actual > expected else "missing"
	hq_message_log.append_text("\n[color=orange]Census Mismatch in %s: %d %s entity (expected %d, got %d)[/color]" % [
		zone_id, abs(actual - expected), direction, expected, actual
	])

func _on_escalation_phase_changed(old_phase: String, new_phase: String) -> void:
	hq_message_log.append_text("\n[color=red][b]ESCALATION PHASE: %s → %s[/b][/color]" % [old_phase, new_phase])

func _on_horror_event_triggered(event_type: String, severity: int) -> void:
	hq_message_log.append_text("\n[color=red]Horror Event: %s (severity: %d)[/color]" % [event_type, severity])

func _on_retroactive_anomaly(clip_id: String, anomaly_type: String, description: String) -> void:
	hq_message_log.append_text("\n[color=magenta]Retroactive Anomaly in %s: %s[/color]" % [clip_id, description])

func _on_log_pressed() -> void:
	# Demo: Log a mundane event
	var report_id = HQReportSystem.create_anomaly_report(
		"cam_north_01",
		"zone_north",
		HQReportSystem.AnomalyType.MUNDANE_EVENT,
		"Deer activity observed near camera perimeter"
	)
	HQReportSystem.submit_action(report_id, HQReportSystem.AnomalyAction.LOG_ONLY)
	hq_message_log.append_text("\nLogged mundane event")

func _on_escalate_pressed() -> void:
	# Demo: Escalate a potential anomaly
	var report_id = HQReportSystem.create_anomaly_report(
		"cam_dam_01",
		"zone_dam",
		HQReportSystem.AnomalyType.OBJECT_MOVED,
		"Equipment appears to have moved between camera cycles"
	)
	HQReportSystem.submit_action(report_id, HQReportSystem.AnomalyAction.ESCALATE_HQ)

func _on_investigate_pressed() -> void:
	# Demo: Field investigation
	var report_id = HQReportSystem.create_anomaly_report(
		"cam_edge_01",
		"zone_edge",
		HQReportSystem.AnomalyType.UNEXPECTED_OBJECT,
		"Unknown object detected in restricted area"
	)
	HQReportSystem.submit_action(report_id, HQReportSystem.AnomalyAction.INVESTIGATE)
	hq_message_log.append_text("\nDispatching to field...")

func _on_review_pressed() -> void:
	# Demo: Review archived footage
	var clip_id = FootageArchive.create_clip("cam_north_01", "zone_north", 30.0, Time.get_ticks_msec() / 1000.0)
	FootageArchive.set_clip_content(clip_id, ["tree", "rock", "deer"], 1)
	FootageArchive.mark_clip_as_live_viewed(clip_id, ["tree", "rock", "deer"], 1)
	
	# Add retroactive anomaly for demo
	if EscalationManager.current_phase != EscalationManager.GamePhase.EARLY:
		FootageArchive.add_retroactive_anomaly(
			clip_id,
			"shadow_figure",
			"Shadow figure visible in archive but not live feed",
			0.5
		)
	
	FootageArchive.start_review(clip_id)
	hq_message_log.append_text("\nReviewing archived footage: %s" % clip_id)

func _process(_delta: float) -> void:
	_update_ui()
