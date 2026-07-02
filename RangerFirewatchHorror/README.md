# Ranger/Firewatch-Horror — Core Game Logic Framework

A Godot 4.7 implementation of the horror game logic framework based on the design document.

## Project Structure

```
RangerFirewatchHorror/
├── autoload/              # Singleton systems (auto-loaded by Godot)
│   ├── game_manager.gd       # Core loop controller (Section 1: The Shift)
│   ├── credibility_manager.gd # Trust economy (Section 5)
│   ├── zone_manager.gd        # Zone system + Zone Bleed (Section 2, 8.4)
│   ├── camera_system.gd       # Camera system + Phantom state (Section 3, 8)
│   ├── hq_report_system.gd    # HQ reporting + Detection logic (Section 4, 5)
│   ├── footage_archive.gd     # Archive/playback + Retroactive Dread (Section 8.2)
│   └── escalation_manager.gd  # Escalation curve + Horror events (Section 7, 8.5)
├── scenes/
│   ├── main.tscn          # Main scene with UI
│   └── main.gd            # Main scene controller
├── resources/             # For future resources (ZoneProfile, etc.)
├── data/                  # For future data files
├── ui/                    # For future UI components
├── project.godot          # Godot 4.7 project configuration
└── icon.svg               # Project icon
```

## Systems Implemented

### 1. Core Loop (The Shift) - `GameManager`
- Shift phases: Check Cameras → Spot Anomalies → Decide Action → Repair → Return
- Shift timer and phase tracking
- Early/Mid/Late game phase detection

### 2. Zone System - `ZoneManager`
- Zone types: Natural Habitat, Settlement, Infrastructure, Transitional, Restricted
- Baseline profiles (wildlife count, NPC presence, sound/lighting patterns)
- Camera coverage levels (Dense, Moderate, Sparse)
- Independent risk tiers per zone

### 3. Camera System - `CameraSystem`
- Status states: Online, Static, Offline, **Phantom**
- Health decay from weather, wildlife, age
- Damage ambiguity (mundane vs non-mundane causes look identical early)
- Player position tracking for self-sighting detection

### 4. Detection Logic - `HQReportSystem`
- Anomaly types: Object Moved, Count Wrong, Unexpected Object, Footage Loop, Phantom Content
- Decision fork: Log Only / Escalate to HQ / Investigate Field
- No pre-flagged markers - player must recognize patterns

### 5. HQ Report System - `CredibilityManager` + `HQReportSystem`
- Credibility meter (0-100) with thresholds
- Report outcomes: False Alarm, Mundane, Genuine
- Response timer that varies by credibility
- HQ reliability degradation (Reliable → Ambiguous → Unreliable)

### 6. Damage/Repair Field Loop - `CameraSystem` + `GameManager`
- Physical travel requirement for repairs
- Real-time cost for repair actions
- Blind spot revelation mechanic

### 7. Escalation Curve - `EscalationManager`
- Early shifts (1-3): Almost entirely mundane
- Mid-game (4-6): Genuinely ambiguous cases
- Late game (7+): Impossible things, unreliable HQ

### 8. Horror Logic Systems

#### 8.1 Census Mismatch - `ZoneManager` + `EscalationManager`
- Per-zone expected count values
- "Over" and "Under" count differentiation
- HQ reacts differently to each type

#### 8.2 Retroactive Dread - `FootageArchive`
- Full footage archive/playback system
- Live-view vs archive diff detection
- Scrub/review interface support
- Sparing use for maximum effect

#### 8.3 Self-Sighting - `CameraSystem` + `EscalationManager`
- Independent player position tracking
- Phantom camera state for impossible content
- Credibility cost for reporting "I saw myself"

#### 8.4 Zone Bleed - `ZoneManager`
- Gradual drift sliders (not toggles)
- Sound drift and lighting drift
- Census drift enabled after sufficient bleed
- Limited to zones player has spent time trusting

#### 8.5 Cross-System Interactions - `EscalationManager`
- Zone Bleed + Census Mismatch pairing
- Retroactive Dread prerequisite for Self-Sighting
- Unified Phantom state flag

## How to Run in Godot 4.7

1. **Install Godot 4.7** from https://godotengine.org/download
2. **Open the project**: Launch Godot and import the `RangerFirewatchHorror` folder
3. **Run the project**: Press F5 or click the Play button

The main scene (`scenes/main.tscn`) will load with:
- Sample zones pre-configured
- Sample cameras registered
- **Enhanced interactive demo** with keyboard support and testing tools
- Live log showing all system events

## Interactive Demo Features (scenes/main.gd)

The demo is now much more powerful for testing the horror systems:

**Keyboard Controls:**
- **L** – Log anomaly
- **E** – Escalate to HQ
- **I** – Investigate field
- **R** – Review footage
- **1-4** – Move simulated player to different zones (North / Tower / Dam / Edge)
- **5** – Test Self-Sighting on a distant camera (only works in Late game)
- **0** – Force a census mismatch on a random zone

**Other improvements:**
- Credibility meter now disables the Escalate button when too low
- Status bar shows current phase + simulated player zone
- Zone panel shows live risk tier / bleed status
- Escalate button now simulates realistic HQ resolution with phase-aware outcomes
- Review footage button demonstrates Retroactive Dread with scrub result
- Horror events now auto-trigger as you advance shifts (especially Mid/Late)

## Key Design Decisions

### GDScript Architecture
- All core systems are **autoload singletons** for global access
- Heavy use of **signals** for decoupled communication
- No direct dependencies between systems except through signals

### Godot 4.7 Compatibility
- Uses GDScript 2.0 syntax
- Typed arrays and dictionaries where appropriate
- Modern signal connection syntax
- Compatible with Godot 4.7's rendering and input systems

### Extensibility Points
- `ZoneProfile` class can be extended with custom properties
- `FootageClip` supports arbitrary anomaly types
- `EscalationManager` event system is open-ended
- UI layer is separate from logic (replace `main.gd` with your game UI)

## Next Steps (Open Systems from Doc)

These systems have the foundation laid but need UI/UX implementation:

1. **Footage Archive Playback UI** - Visual scrubber, frame-by-frame review
2. **Player Position Tracking** - Integrate with actual player movement/camera system
3. **Per-Zone Drift Visualization** - Show baseline erosion to player subtly
4. **Credibility Threshold Consequences** - Implement specific gameplay effects at each threshold

## Testing the Horror Mechanics

The included demo scene lets you test:

```gdscript
# Trigger census mismatch
EscalationManager.trigger_census_mismatch("zone_north")

# Trigger retroactive dread (mid/late game only)
var clip_id = FootageArchive.create_clip(...)
EscalationManager.trigger_retroactive_dread("cam_north_01", clip_id)

# Trigger self-sighting (late game only)
EscalationManager.trigger_self_sighting("cam_tower_01")

# Trigger zone bleed
EscalationManager.trigger_zone_bleed("zone_dam", 0.5)
```

## License

This is a framework implementation based on the provided design document. Use as needed for your project.
