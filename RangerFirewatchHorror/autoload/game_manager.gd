extends Node
## GameManager - Core Loop Controller (Section 1: The Shift)
## Manages the repeating rhythm of each in-game day/night shift.

signal shift_started(shift_number: int)
signal shift_ended(success: bool)
signal phase_changed(old_phase: String, new_phase: String)

enum ShiftPhase {
	IDLE,           # Between shifts
	CHECK_CAMERAS,  # Phase 1: Check camera board
	SPOT_ANOMALIES, # Phase 2: Spot anomalies or confirm all-clear
	DECIDE_ACTION,  # Phase 3: Decide action (log/escalate/investigate)
	REPAIR,         # Phase 4: Optionally travel to repair
	RETURN          # Phase 5: Return before shift ends
}

var current_shift: int = 0
var current_phase: ShiftPhase = ShiftPhase.IDLE
var shift_duration_seconds: float = 300.0  # 5 minutes per shift (configurable)
var time_remaining_in_shift: float = 0.0
var is_shift_active: bool = false

# Configuration for difficulty scaling
var early_game_shifts: int = 3      # Shifts 1-3: mostly mundane
var mid_game_shifts: int = 6        # Shifts 4-6: ambiguous cases appear
# Shifts 7+: late game horror elements

func _ready() -> void:
	pass

func start_new_shift() -> void:
	current_shift += 1
	is_shift_active = true
	time_remaining_in_shift = shift_duration_seconds
	current_phase = ShiftPhase.CHECK_CAMERAS
	
	shift_started.emit(current_shift)
	phase_changed.emit("", "CHECK_CAMERAS")

func end_shift(was_successful: bool) -> void:
	is_shift_active = false
	current_phase = ShiftPhase.IDLE
	shift_ended.emit(was_successful)
	phase_changed.emit("RETURN", "IDLE")

func advance_phase(new_phase: ShiftPhase) -> void:
	var old_phase_name = ShiftPhase.keys()[current_phase]
	current_phase = new_phase
	var new_phase_name = ShiftPhase.keys()[current_phase]
	phase_changed.emit(old_phase_name, new_phase_name)

func get_shift_category() -> String:
	"""Returns the game phase category based on current shift number."""
	if current_shift <= early_game_shifts:
		return "early"
	elif current_shift <= mid_game_shifts:
		return "mid"
	else:
		return "late"

func _process(delta: float) -> void:
	if is_shift_active:
		time_remaining_in_shift -= delta
		if time_remaining_in_shift <= 0:
			end_shift(true)

func get_time_remaining_formatted() -> String:
	var minutes = int(time_remaining_in_shift / 60)
	var seconds = int(time_remaining_in_shift) % 60
	return "%d:%02d" % [minutes, seconds]
