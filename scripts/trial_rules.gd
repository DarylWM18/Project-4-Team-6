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
const REVIVAL_SECONDS := [16.0, 14.0, 12.0, 10.0, 9.0, 8.0, 7.0, 6.0]

static func rank_index(seconds: float, target: float) -> int:
	for i in RANK_RATIOS.size():
		if seconds <= target * RANK_RATIOS[i]:
			return i
	return RANKS.size() - 1

static func revival_requirement(activation: int) -> int:
	# The supplied sequence caps at 13 until later rooms are designed.
	return REVIVAL_KILLS[clampi(activation - 1, 0, REVIVAL_KILLS.size() - 1)]
