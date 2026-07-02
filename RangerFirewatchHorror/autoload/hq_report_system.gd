extends Node
## HQReportSystem - HQ Report System (Section 5) + Detection Logic (Section 4)
## Manages the feedback loop, trust economy, and decision forks for anomalies.

signal report_submitted(report_id: String, report_data: Dictionary)
signal report_resolved(report_id: String, outcome: int, credibility_change: float)
signal hq_message_received(message: String, sender_reliability: String)

enum AnomalyAction {
	LOG_ONLY,       # No action, just record
	ESCALATE_HQ,    # Report to HQ (costs time/credibility if wrong)
	INVESTIGATE     # Personal field investigation (risk exposure)
}

enum AnomalyType {
	OBJECT_MOVED,
	COUNT_WRONG,          # Census mismatch
	UNEXPECTED_OBJECT,    # Something with no reason to be there
	FOOTAGE_LOOP,         # Perfect loop repeating
	PHANTOM_CONTENT,      # Self-sighting or impossible content
	ZONE_DRIFT,           # Baseline erosion
	MUNDANE_EVENT         # Weather, wildlife, staff - not anomalous
}

## Report data structure
class ReportData:
	var report_id: String
	var camera_id: String
	var zone_id: String
	var anomaly_type: AnomalyType
	var description: String
	var timestamp: float
	var action_taken: AnomalyAction
	var resolved: bool = false
	var outcome: int = -1  # -1 = unresolved, otherwise CredibilityManager.ReportOutcome
	
	func _init():
		pass

var active_reports: Dictionary = {}  # report_id -> ReportData
var report_history: Array = []
var current_report_counter: int = 0

func _ready() -> void:
	pass

func create_anomaly_report(camera_id: String, zone_id: String, anomaly_type: AnomalyType, description: String) -> String:
	"""Creates a new anomaly report and returns its ID."""
	current_report_counter += 1
	var report_id = "RPT_%d_%d" % [GameManager.current_shift, current_report_counter]
	
	var report = ReportData.new()
	report.report_id = report_id
	report.camera_id = camera_id
	report.zone_id = zone_id
	report.anomaly_type = anomaly_type
	report.description = description
	report.timestamp = Time.get_ticks_msec() / 1000.0
	
	active_reports[report_id] = report
	report_submitted.emit(report_id, _serialize_report(report))
	
	return report_id

func submit_action(report_id: String, action: AnomalyAction) -> void:
	"""Records the player's chosen action for a report."""
	if not active_reports.has(report_id):
		return
	
	var report = active_reports[report_id]
	report.action_taken = action
	
	# If escalating to HQ, notify CredibilityManager
	if action == AnomalyAction.ESCALATE_HQ:
		CredibilityManager.submit_report(report_id, AnomalyType.keys()[report.anomaly_type])
		
		# Generate HQ response based on credibility and reliability
		_generate_hq_response(report)
	elif action == AnomalyAction.LOG_ONLY:
		# Logging only has no immediate consequence but no reward either
		pass
	elif action == AnomalyAction.INVESTIGATE:
		# Investigation triggers field loop (handled by GameManager/ZoneManager)
		GameManager.advance_phase(GameManager.ShiftPhase.REPAIR)

func resolve_report(report_id: String, outcome: int) -> void:
	"""
	Resolves a report with the given outcome.
	outcome should be CredibilityManager.ReportOutcome values.
	"""
	if not active_reports.has(report_id):
		return
	
	var report = active_reports[report_id]
	report.resolved = true
	report.outcome = outcome
	
	# Update credibility
	var old_credibility = CredibilityManager.current_credibility
	CredibilityManager.resolve_report(outcome)
	var credibility_change = CredibilityManager.current_credibility - old_credibility
	
	# Move to history
	report_history.append(report)
	active_reports.erase(report_id)
	
	report_resolved.emit(report_id, outcome, credibility_change)

func _generate_hq_response(report: ReportData) -> void:
	"""Generates an HQ response message based on current state."""
	var reliability = CredibilityManager.hq_reliability
	var response_type = _get_hq_response_type_name()
	var message: String
	
	match reliability:
		CredibilityManager.HQReliability.RELIABLE:
			message = _generate_reliable_response(report)
		CredibilityManager.HQReliability.AMBIGUOUS:
			message = _generate_ambiguous_response(report)
		CredibilityManager.HQReliability.UNRELIABLE:
			message = _generate_unreliable_response(report)
	
	hq_message_received.emit(message, CredibilityManager.HQReliability.keys()[reliability])

func _generate_reliable_response(report: ReportData) -> String:
	"""Generates clear, accurate HQ responses (early game)."""
	match report.anomaly_type:
		AnomalyType.MUNDANE_EVENT:
			return "Acknowledged. Standard environmental activity. No action required."
		AnomalyType.OBJECT_MOVED:
			return "Noted. Possible wildlife interference. Monitor for patterns."
		AnomalyType.COUNT_WRONG:
			return "Discrepancy recorded. Verify count if possible before escalation."
		_:
			return "Report received. Continuing to monitor."

func _generate_ambiguous_response(report: ReportData) -> String:
	"""Generates less clear HQ responses (mid game)."""
	match report.anomaly_type:
		AnomalyType.MUNDANE_EVENT:
			return "Possibly routine. Could be something else. Stand by."
		AnomalyType.OBJECT_MOVED:
			return "Unclear. Equipment malfunction possible. Or not."
		AnomalyType.COUNT_WRONG:
			return "Count discrepancy... checking records. Inconclusive."
		_:
			return "Received. Assessment pending."

func _generate_unreliable_response(report: ReportData) -> String:
	"""Generates contradictory or premature HQ responses (late game)."""
	var responses = [
		"We already knew about that. Why are you reporting it now?",
		"That's not possible. Your equipment must be malfunctioning.",
		"Acknowledged. But our records show something different.",
		"Don't worry about that one. Focus elsewhere.",
		"Interesting. Very interesting. Continue monitoring."
	]
	return responses[randi_range(0, responses.size() - 1)]

func _get_hq_response_type_name() -> String:
	"""Returns the current HQ response type name from CredibilityManager."""
	if CredibilityManager.current_credibility >= 90:
		return "trusting"
	elif CredibilityManager.current_credibility >= 75:
		return "professional"
	elif CredibilityManager.current_credibility >= 40:
		return "skeptical"
	else:
		return "dismissive"

func _serialize_report(report: ReportData) -> Dictionary:
	"""Converts a report to a dictionary for signal transmission."""
	return {
		"report_id": report.report_id,
		"camera_id": report.camera_id,
		"zone_id": report.zone_id,
		"anomaly_type": AnomalyType.keys()[report.anomaly_type],
		"description": report.description,
		"timestamp": report.timestamp,
		"action_taken": AnomalyAction.keys()[report.action_taken] if report.action_taken != null else "NONE",
		"resolved": report.resolved,
		"outcome": report.outcome
	}

func get_active_report_count() -> int:
	"""Returns the number of currently active (unresolved) reports."""
	return active_reports.size()

func can_escalate_report(report_id: String) -> bool:
	"""Checks if a report can be escalated to HQ."""
	if not active_reports.has(report_id):
		return false
	return CredibilityManager.can_escalate_to_hq()
