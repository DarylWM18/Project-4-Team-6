class_name TrialRules
extends RefCounted
## All prototype balancing lives here. Times are seconds, distances are meters.

const ROOM_NAMES := ["01 / NEURAL RECOVERY", "02 / CONTAINMENT", "03 / TRANSIT LOCK"]
const ROOM_TARGETS := [60.0, 80.0, 90.0]
const ROOM_ENEMIES := [3, 5, 6]
const FLOW_KILLS := [2, 3, 4]
const FLOW_WINDOWS := [12.0, 10.0, 9.0]
const FLOW_SPEED := [1.0, 1.12, 1.25, 1.4]
const REVIVAL_KILLS := [1, 2, 3, 5, 8, 13]
const RANKS := ["SSS", "SS", "S", "A", "B", "C", "D", "E"]
const RANK_RATIOS := [0.5, 2.0 / 3.0, 5.0 / 6.0, 1.0, 1.25, 1.5, 2.0, INF]
const REVIVAL_BASE_SECONDS := 10.0
const REVIVAL_RANK_BONUS := [3.0, 2.5, 2.0, 1.5, 1.0, 0.5, 0.0, 0.0]
const REVIVAL_INTRO_SECONDS := 0.24
const PERFECT_BLOCK_WINDOW := 0.22
const REVIVAL_PERFECT_BLOCK_BONUS := 0.5
const REVIVAL_KILL_BONUS := 1.5
const REVIVAL_HIT_PENALTY := 1.5
const REVIVAL_HEALTH := 55.0
const REVIVAL_PROTECTION := 1.2
const REVIVAL_PULSE_RADIUS := 4.5
const REVIVAL_PULSE_STAGGER := 0.9
const REVIVAL_PULSE_FORCE := 8.0

static func rank_index(seconds: float, target: float) -> int:
	for i in RANK_RATIOS.size():
		if seconds <= target * RANK_RATIOS[i]:
			return i
	return RANKS.size() - 1

static func revival_requirement(activation: int) -> int:
	# The supplied sequence caps at 13 until later rooms are designed.
	return REVIVAL_KILLS[clampi(activation - 1, 0, REVIVAL_KILLS.size() - 1)]

static func revival_seconds(rank: int) -> float:
	return REVIVAL_BASE_SECONDS + REVIVAL_RANK_BONUS[clampi(rank, 0, RANKS.size() - 1)]
