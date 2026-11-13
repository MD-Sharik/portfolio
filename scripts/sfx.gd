extends Node
## Autoload "Sfx": tiny procedural sound effects (no audio files needed).

const RATE := 22050

var _players := {}
var _streams := {}


func _ready() -> void:
	_streams["slide"] = _tone([[520.0, 980.0, 0.16, 0.35]])
	_streams["wrong"] = _tone([[190.0, 120.0, 0.26, 0.45]])
	_streams["win"] = _tone([[523.0, 523.0, 0.11, 0.4], [659.0, 659.0, 0.11, 0.4], [784.0, 784.0, 0.11, 0.4], [1047.0, 1047.0, 0.3, 0.4]])
	_streams["lose"] = _tone([[330.0, 330.0, 0.14, 0.4], [262.0, 262.0, 0.14, 0.4], [196.0, 196.0, 0.34, 0.4]])
	_streams["tap"] = _tone([[700.0, 640.0, 0.05, 0.25]])
	_streams["hint"] = _tone([[880.0, 880.0, 0.07, 0.3], [1175.0, 1175.0, 0.12, 0.3]])
	for k in _streams:
		var p := AudioStreamPlayer.new()
		p.stream = _streams[k]
		add_child(p)
		_players[k] = p


## Haptic feedback (Android / iOS). kind: light | medium | heavy | win | lose
func haptic(kind: String) -> void:
	if not Save.vibrate:
		return
	match kind:
		"light":
			Input.vibrate_handheld(14, 0.35)
		"medium":
			Input.vibrate_handheld(30, 0.65)
		"heavy":
			Input.vibrate_handheld(60, 1.0)
		"win":
			Input.vibrate_handheld(35, 0.8)
			for i in [1, 2, 3]:
				get_tree().create_timer(0.11 * i).timeout.connect(func(): Input.vibrate_handheld(25 + 10 * i, 0.9))
		"lose":
			Input.vibrate_handheld(90, 1.0)
			get_tree().create_timer(0.16).timeout.connect(func(): Input.vibrate_handheld(150, 1.0))


func play(name: String) -> void:
	if Save.sound and _players.has(name):
		_players[name].play()


## notes: [[freq_start, freq_end, seconds, volume], ...]
func _tone(notes: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for note in notes:
		var n := int(RATE * float(note[2]))
		var start_i := data.size()
		data.resize(start_i + n * 2)
		var phase := 0.0
		for i in n:
			var t := float(i) / float(n)
			phase += TAU * lerpf(float(note[0]), float(note[1]), t) / RATE
			var env := pow(1.0 - t, 1.4) * minf(1.0, float(i) / 160.0)
			var v := (sin(phase) + 0.35 * sin(phase * 2.0)) * env * float(note[3])
			data.encode_s16(start_i + i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
