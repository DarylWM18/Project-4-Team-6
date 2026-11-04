class_name TrialRules
extends RefCounted
## All prototype balancing lives here. Times are seconds, distances are meters.


const ROOM_NAMES: Array[String] = ["01 / NEURAL RECOVERY", "02 / CONTAINMENT", "03 / TRANSIT LOCK"]
const ROOM_TARGETS: Array[float] = [60.0, 80.0, 90.0]
const ROOM_ENEMIES: Array[int] = [7, 11, 7]

const FLOW_KILLS: Array[int] = [3, 4, 5, 6, 7]
const FLOW_WINDOWS: Array[float] = [10.0, 8.0, 7.0, 6.0, 5.0]
const FLOW_SPEED: Array[float] = [1.0, 1.1, 1.25, 1.45, 1.7, 2.0]

const REVIVAL_KILLS: Array[int] = [1, 2, 3, 5, 8, 13]

const RANKS: Array[String] = ["SSS", "SS", "S", "A", "B", "C", "D", "F"]
const RANK_RATIOS: Array[float] = [0.5, 2.0 / 3.0, 5.0 / 6.0, 1.0, 1.25, 1.5, 2.0, INF]

const BASE_REVIVAL_SECONDS := 5.0
const REVIVAL_SECONDS: Array[float] = [16.0, 14.0, 12.0, 10.0, 9.0, 8.0, 7.0, 6.0]


static func rank_index(seconds: float, target: float) -> int:
	for i in RANK_RATIOS.size():
		if seconds <= target * RANK_RATIOS[i]:
			return i
	return RANKS.size() - 1

static func rank_name(index: int) -> String:
	return RANKS[clampi(index, 0, RANKS.size() - 1)]

static func reward_for_rank(rank_str: String) -> float:
	var idx := RANKS.find(rank_str)
	if idx >= 0 and idx < REVIVAL_SECONDS.size():
		return REVIVAL_SECONDS[idx]
	return BASE_REVIVAL_SECONDS

static func reward_for_index(idx: int) -> float:
	if idx >= 0 and idx < REVIVAL_SECONDS.size():
		return REVIVAL_SECONDS[idx]
	return BASE_REVIVAL_SECONDS

static func room_target(room_index: int) -> float:
	if room_index >= 0 and room_index < ROOM_TARGETS.size():
		return ROOM_TARGETS[room_index]
	return 60.0

static func rank_threshold_for_room(rank_idx: int, room_index: int) -> float:
	var target := room_target(room_index)
	if rank_idx >= 0 and rank_idx < RANK_RATIOS.size():
		return target * RANK_RATIOS[rank_idx]
	return INF

static func revival_requirement(activation: int) -> int:
	# The supplied sequence caps at 13 until later rooms are designed.
	return REVIVAL_KILLS[clampi(activation - 1, 0, REVIVAL_KILLS.size() - 1)]
