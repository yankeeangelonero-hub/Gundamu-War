extends Node
## Synthesizes placeholder SFX as 16-bit PCM at runtime. Deterministic.

const RATE := 44100
var streams: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4242
	var gen_beam := func(i: int, n: int) -> float:
		var t := float(i) / RATE
		var f := 1400.0 - 1100.0 * (float(i) / n)
		return (sin(TAU * f * t) * 0.6 + rng.randf_range(-0.4, 0.4)) * (1.0 - float(i) / n)
	streams["beam"] = _make(0.45, gen_beam)
	var gen_thud := func(i: int, n: int) -> float:
		var t := float(i) / RATE
		return (sin(TAU * 90.0 * t) + rng.randf_range(-0.5, 0.5)) * pow(1.0 - float(i) / n, 2.0)
	streams["thud"] = _make(0.12, gen_thud)
	var gen_boom := func(i: int, n: int) -> float:
		var t := float(i) / RATE
		var env := pow(1.0 - float(i) / n, 1.6)
		return (sin(TAU * 45.0 * t) * 0.7 + rng.randf_range(-1, 1) * 0.5 * env) * env
	streams["boom"] = _make(2.2, gen_boom)
	var gen_sting := func(i: int, n: int) -> float:
		var t := float(i) / RATE
		var env := minf(t * 8.0, 1.0) * (1.0 - float(i) / n)
		var v := 0.0
		for f in [220.0, 261.6, 329.6]:
			v += sin(TAU * f * t) / 3.0
		return v * env
	streams["sting"] = _make(2.5, gen_sting)

func _make(dur: float, gen: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := clampf(gen.call(i, n), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	return s

func play(key: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = streams[key]
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func wire(director: Node3D) -> void:
	var on_event := func(e: Dictionary):
		match e.kind:
			"fire_beam":
				play("beam", -4.0)
			"fire_burst":
				for i in int(e.payload.rounds):
					get_tree().create_timer(float(i) * 0.09).timeout.connect(
						func(): play("thud", -10.0))
			"destroyed":
				play("boom", 2.0)
				get_tree().create_timer(2.5).timeout.connect(func(): play("sting", -6.0))
	director.fight_event.connect(on_event)
