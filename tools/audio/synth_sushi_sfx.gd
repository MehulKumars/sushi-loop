extends SceneTree
## Synthesises Sushi Loop's musical cues into assets/audio/sfx/ (original work, no samples): a
## koto-like plucked string in the D "yo" pentatonic scale (D E G A B), so any ladder of cues
## (cascade hops, bento chimes, stars) stays in key. Bento chime, cascade hop, the counter
## warning, a soft fall, the win phrase, a star ping and the new-dish reveal. The physical sounds
## (plates, wood, chips, coins) are Kenney recordings: tools/audio/prepare_foley.sh.
## Usage: godot --headless --path . -s tools/audio/synth_sushi_sfx.gd

const RATE: int = 44100
const OUT: String = "res://assets/audio/sfx/%s.wav"
const D5: float = 587.33


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	_save("hop", _koto(D5, 0.5, 1.0), -8.0)
	_save("chime", _layer([
		[_koto(_note(7), 1.3, 1.0), 0.0],
		[_koto(_note(12), 1.3, 0.8), 0.035],
		[_bell(_note(24), 1.1, 0.18), 0.05],
	], 1.4), -5.0)
	_save("warn", _layer([[_koto(_note(-17), 0.35, 1.0, 2.2), 0.0], [_koto(_note(-17), 0.45, 0.8, 2.2), 0.16]], 0.65), -9.0)
	_save("fail", _layer([
		[_koto(_note(2), 0.8, 0.9, 1.4), 0.0],
		[_koto(_note(0), 0.8, 0.85, 1.4), 0.22],
		[_koto(_note(-5), 1.2, 0.8, 1.4), 0.46],
	], 1.7), -8.0)
	_save("win", _layer([
		[_koto(_note(0), 1.6, 0.9), 0.0],
		[_koto(_note(2), 1.5, 0.9), 0.09],
		[_koto(_note(5), 1.4, 0.9), 0.18],
		[_koto(_note(7), 1.3, 0.95), 0.27],
		[_koto(_note(12), 1.6, 1.0), 0.38],
		[_koto(_note(19), 1.5, 0.6), 0.40],
		[_bell(_note(24), 1.4, 0.2), 0.42],
	], 2.1), -4.0)
	_save("star", _layer([[_koto(_note(12), 0.8, 1.0), 0.0], [_bell(_note(24), 0.8, 0.25), 0.0]], 0.9), -7.0)
	_save("reveal", _layer([
		[_koto(_note(5), 1.0, 0.8), 0.0],
		[_koto(_note(9), 1.0, 0.8), 0.07],
		[_koto(_note(12), 1.2, 0.9), 0.14],
		[_bell(_note(21), 1.0, 0.2), 0.16],
		[_bell(_note(28), 0.9, 0.12), 0.24],
	], 1.4), -6.0)
	quit()


## The frequency `semitones` above D5.
func _note(semitones: int) -> float:
	return D5 * pow(2.0, semitones / 12.0)


## A koto-like pluck: harmonic partials shaped by the pluck point (a fifth of the string), the
## higher ones dying faster, slightly stretched (stiff string), a pitch that settles a hair after
## the attack, and a 3 ms bright noise tick. `damp` > 1 mutes the string (warning, fall).
func _koto(freq: float, seconds: float, gain: float, damp: float = 1.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 10.0)
	var out := _empty(seconds)
	var partials := 10
	var amps := PackedFloat32Array()
	var ratios := PackedFloat32Array()
	var decays := PackedFloat32Array()
	for k in range(1, partials + 1):
		amps.append(absf(sin(PI * float(k) * 0.2)) / pow(float(k), 1.1))
		ratios.append(float(k) * sqrt(1.0 + 0.0004 * float(k * k)))
		decays.append((2.6 + 1.9 * float(k - 1)) * damp)
	var last := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var bend := t + 0.004 * 0.03 * (1.0 - exp(-t / 0.03))
		var s := 0.0
		for k in partials:
			s += amps[k] * sin(TAU * freq * ratios[k] * bend) * exp(-t * decays[k])
		var noise := rng.randf_range(-1.0, 1.0)
		var tick := (noise - last) * exp(-t / 0.003) * 0.35
		last = noise
		out[i] = (s + tick) * minf(1.0, t / 0.002) * gain
	return out


## A small glass bell (partials 1 : 2.76 : 5.4) for the shimmer on top of chords.
func _bell(freq: float, seconds: float, gain: float) -> PackedFloat32Array:
	var out := _empty(seconds)
	for i in out.size():
		var t := float(i) / RATE
		var s := sin(TAU * freq * t) * exp(-t * 4.0) + 0.3 * sin(TAU * freq * 2.76 * t) * exp(-t * 9.0) \
				+ 0.12 * sin(TAU * freq * 5.4 * t) * exp(-t * 16.0)
		out[i] = s * minf(1.0, t / 0.004) * gain
	return out


## Sounds [samples, start seconds] mixed into one of `seconds` length.
func _layer(parts: Array, seconds: float) -> PackedFloat32Array:
	var out := _empty(seconds)
	for part: Array in parts:
		var sound: PackedFloat32Array = part[0]
		var start := int(float(part[1]) * RATE)
		for i in sound.size():
			if start + i < out.size():
				out[start + i] += sound[i]
	return out


func _empty(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	return out


## Normalised to `peak_db`, faded out over the last 40 ms, saved as 16-bit mono WAV.
func _save(id: String, samples: PackedFloat32Array, peak_db: float) -> void:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var scale := db_to_linear(peak_db) / maxf(peak, 0.0001)
	var fade := int(0.04 * RATE)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var tail := clampf(float(samples.size() - i) / float(fade), 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(samples[i] * scale * tail, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(ProjectSettings.globalize_path(OUT % id))
	print("synth_sushi_sfx: %s %s (%d samples)" % [id, error_string(err), samples.size()])
