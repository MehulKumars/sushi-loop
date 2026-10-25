extends SceneTree
## Synthesises Sushi Loop's placeholder sounds into assets/audio/sfx/ (original work, no samples):
## belt tick, porcelain take and clink, a wooden counter thunk, the lacquer lid clack, the bento
## chime, cascade hops (played a semitone higher each), a low warning, a two-note fall, a small win
## arpeggio and the UI click. Calm and quiet; real foley recorded on a phone should replace them.
## Usage: godot --headless --path . -s tools/audio/synth_sushi_sfx.gd

const RATE: int = 44100
const OUT: String = "res://assets/audio/sfx/%s.wav"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	_save("tick", _wood(900.0, 0.08, 0.22, 1))
	_save("take", _porcelain([2200.0], [55.0], 0.1, 0.28, 2))
	_save("clink", _porcelain([2650.0, 3910.0, 5800.0], [18.0, 24.0, 35.0], 0.5, 0.34, 3))
	_save("counter", _wood(170.0, 0.2, 0.55, 4))
	_save("lid", _mix(_wood(330.0, 0.22, 0.5, 5), _noise(0.006, 0.3, 6)))
	_save("chime", _bell(1046.5, 1.2, 0.42))
	_save("hop", _pluck(523.25, 0.35, 0.36))
	_save("warn", _pluck(220.0, 0.6, 0.4))
	_save("fail", _sequence([[392.0, 0.0], [293.66, 0.18]], 0.65, 0.32, false))
	_save("win", _sequence([[523.25, 0.0], [659.25, 0.12], [783.99, 0.24], [1046.5, 0.36]], 1.5, 0.28, true))
	_save("click", _porcelain([1800.0], [90.0], 0.04, 0.18, 7))
	quit()


## Wood: a 2 ms noise click, then damped partials at a wooden bar's ratios (1 : 2.76 : 5.40).
func _wood(freq: float, seconds: float, gain: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := _empty(seconds)
	for i in out.size():
		var t := float(i) / RATE
		var click := rng.randf_range(-1.0, 1.0) * exp(-t / 0.002) * 0.3
		var body := sin(TAU * freq * t) * exp(-t * 30.0) + 0.5 * sin(TAU * freq * 2.76 * t) * exp(-t * 48.0) \
				+ 0.25 * sin(TAU * freq * 5.4 * t) * exp(-t * 75.0)
		out[i] = (click + body * 0.6) * minf(1.0, t / 0.001) * gain
	return out


## Porcelain: inharmonic partials with their own fast decays and a tiny noise tick at the start.
func _porcelain(freqs: Array[float], decays: Array[float], seconds: float, gain: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := _empty(seconds)
	for i in out.size():
		var t := float(i) / RATE
		var s := rng.randf_range(-1.0, 1.0) * exp(-t / 0.0015) * 0.2
		for k in freqs.size():
			s += sin(TAU * freqs[k] * t) * exp(-t * decays[k]) / float(k + 1)
		out[i] = s * minf(1.0, t / 0.003) * gain
	return out


## A bell: a sine with quiet partials at 2x and 3.01x, a 4 ms attack and an exponential decay.
func _bell(freq: float, seconds: float, gain: float) -> PackedFloat32Array:
	var out := _empty(seconds)
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * exp(-t * 3.4)
		var s := sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t) * exp(-t * 6.0) \
				+ 0.08 * sin(TAU * freq * 3.01 * t) * exp(-t * 9.0)
		out[i] = s * env * gain
	return out


## A soft marimba-like pluck: the fundamental and a quiet fourth harmonic.
func _pluck(freq: float, seconds: float, gain: float) -> PackedFloat32Array:
	var out := _empty(seconds)
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.003) * exp(-t * 9.0)
		out[i] = (sin(TAU * freq * t) + 0.2 * sin(TAU * freq * 4.0 * t) * exp(-t * 20.0)) * env * gain
	return out


## Notes [freq, start] as plucks (or bells), mixed into one sound.
func _sequence(notes: Array, seconds: float, gain: float, bells: bool) -> PackedFloat32Array:
	var out := _empty(seconds)
	for note: Array in notes:
		var start := int(float(note[1]) * RATE)
		var sound := _bell(float(note[0]), seconds - float(note[1]), gain) if bells else _pluck(float(note[0]), seconds - float(note[1]), gain)
		for i in sound.size():
			if start + i < out.size():
				out[start + i] += sound[i]
	return out


func _noise(seconds: float, gain: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := _empty(seconds)
	for i in out.size():
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE / (seconds * 0.4)) * gain
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in mini(a.size(), b.size()):
		out[i] += b[i]
	return out


func _empty(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	return out


## 16-bit mono WAV through AudioStreamWAV, so Godot imports it like any other effect.
func _save(id: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(ProjectSettings.globalize_path(OUT % id))
	print("synth_sushi_sfx: %s %s (%d samples)" % [id, error_string(err), samples.size()])
