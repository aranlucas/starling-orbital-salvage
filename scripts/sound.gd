extends Node
## Tiny synthesized effects keep the sample self-contained and asset-free.

var muted := false
var voices: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var next_voice := 0


func _ready() -> void:
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -16.0
		add_child(voice)
		voices.append(voice)
	cues["core"] = _tone(660, 990, 0.16)
	cues["dash"] = _tone(180, 480, 0.12)
	cues["hit"] = _tone(160, 45, 0.25)
	cues["win"] = _tone(440, 1320, 0.6)
	cues["lose"] = _tone(220, 60, 0.5)
	cues["pulse"] = _tone(80, 520, 0.45)
	cues["dock"] = _tone(480, 960, 0.32)
	cues["upgrade"] = _tone(420, 1280, 0.38)
	cues["shatter"] = _tone(180, 65, 0.14)
	cues["warning"] = _tone(440, 330, 0.18)


func play(cue: String, pitch: float = 1.0) -> void:
	if muted or not cues.has(cue):
		return
	var voice := voices[next_voice]
	voice.stream = cues[cue]
	voice.pitch_scale = pitch
	voice.play()
	next_voice = (next_voice + 1) % voices.size()


func _tone(start: float, finish: float, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration * stream.mix_rate)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var phase := 0.0
	for i in count:
		var progress := float(i) / count
		phase += TAU * lerpf(start, finish, progress) / stream.mix_rate
		var envelope := minf(progress * 25.0, 1.0) * pow(1.0 - progress, 2)
		samples.encode_s16(i * 2, int(sin(phase) * envelope * 16000))
	stream.data = samples
	return stream
