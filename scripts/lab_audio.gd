class_name LabAudio
extends Node
## Small synthesized ambience and cues. No external audio assets required.

var hum: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0
var enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(10):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	hum = AudioStreamPlayer.new()
	add_child(hum)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050 * 2
	var samples := PackedByteArray()
	samples.resize(22050 * 4)
	for i in range(22050 * 2):
		var t := float(i) / 22050.0
		var sample := (sin(TAU * 55 * t) * 0.45 + sin(TAU * 82 * t) * 0.2 + sin(TAU * 110 * t) * 0.1) * 0.1
		samples.encode_s16(i * 2, int(sample * 32767))
	stream.data = samples
	hum.stream = stream
	hum.volume_db = -21
	hum.play()

func tone(frequency: float, duration: float, volume: float = 0.2, noise: bool = false) -> void:
	if not enabled or voices.is_empty():
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(22050 * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in count:
		var t := float(i) / 22050.0
		var envelope := sin(PI * float(i) / count) * exp(-t * 10)
		var sample := sin(TAU * frequency * t) * 0.8
		if noise:
			sample = sample * 0.5 + randf_range(-0.5, 0.5)
		samples.encode_s16(i * 2, int(clampf(sample * envelope * volume, -1, 1) * 32767))
	stream.data = samples
	var voice := voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = stream
	voice.play()

func set_enabled(value: bool) -> void:
	enabled = value
	hum.volume_db = -21 if value else -80
	if not value:
		for voice in voices:
			voice.stop()

func _exit_tree() -> void:
	# Release active playbacks when a run is restarted or the game closes.
	for voice in voices:
		voice.stop()
		voice.stream = null
	voices.clear()
	if is_instance_valid(hum):
		hum.stop()
		hum.stream = null
