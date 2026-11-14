extends Node
## Plays sound effects (design §22): pooled players (at most 24 positional voices), buses from
## game/audio/default_bus_layout.tres, and wall occlusion for positional sounds.
##
## Occlusion swaps in a pre-muffled copy of
## the sound and lowers its volume instead of low-pass filtering. Gameplay noise (what AI hears) is
## separate: see NoiseSystem.

## A sound started. Used by tests and the debug overlay.
signal sound_played(id: StringName, bus: StringName)

const MAX_VOICES_3D: int = 24
const VOICES_2D: int = 8
const MAX_AUDIBLE_DISTANCE_M: float = 120.0
const UNIT_SIZE_M: float = 8.0
## Left / right footstep recordings.
const SIDED_FOOTSTEP_PATH: String = "res://content/audio/sfx/footstep_%s_%s.wav"

var bank: SoundBank = preload("res://data/audio/sound_bank.tres")

var _voices_3d: Array[AudioStreamPlayer3D] = []
var _voices_2d: Array[AudioStreamPlayer] = []
var _ui_voice: AudioStreamPlayer
var _next_3d: int = 0
var _next_2d: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_sided_footsteps()
	for i: int in MAX_VOICES_3D:
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		voice.unit_size = UNIT_SIZE_M
		voice.max_distance = MAX_AUDIBLE_DISTANCE_M
		add_child(voice)
		_voices_3d.append(voice)
	for i: int in VOICES_2D:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		_voices_2d.append(voice)
	# Menu sounds must play while the game is paused.
	_ui_voice = AudioStreamPlayer.new()
	_ui_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_voice.bus = &"UI"
	add_child(_ui_voice)


## Adds the left / right footstep recordings to the bank.
func _load_sided_footsteps() -> void:
	for surface: StringName in AudioRules.FOOTSTEP_SURFACES:
		for side: String in ["left", "right"]:
			var path: String = SIDED_FOOTSTEP_PATH % [surface, side]
			bank.sounds[StringName("footstep_%s_%s" % [surface, side])] = [load(path)]


## Positional sound. Walls between it and the camera muffle it. Returns the voice, or null if unknown.
func play_3d(id: StringName, position: Vector3, bus: StringName = &"SFX", volume_db: float = 0.0,
		source: Node = null) -> AudioStreamPlayer3D:
	var walls: int = _walls_to_listener(position, source)
	var played_id: StringName = AudioRules.variant_id(id, walls, bank.has_sound(StringName(String(id) + AudioRules.MUFFLED_SUFFIX)))
	var stream: AudioStream = bank.pick(played_id, _rng)
	if stream == null:
		Log.warn(&"audio", "Unknown sound '%s'" % id)
		return null
	var voice: AudioStreamPlayer3D = _voices_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _voices_3d.size()
	voice.stream = stream
	voice.bus = bus
	voice.global_position = position
	voice.volume_db = volume_db + AudioRules.occlusion_volume_db(walls)
	voice.play()
	sound_played.emit(played_id, bus)
	return voice


## Non-positional sound: the player's own weapon, footsteps and landings.
func play_2d(id: StringName, bus: StringName = &"SFX", volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStream = bank.pick(id, _rng)
	if stream == null:
		Log.warn(&"audio", "Unknown sound '%s'" % id)
		return null
	var voice: AudioStreamPlayer = _voices_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _voices_2d.size()
	voice.stream = stream
	voice.bus = bus
	voice.volume_db = volume_db
	voice.pitch_scale = pitch_scale
	voice.play()
	sound_played.emit(id, bus)
	return voice


## Menu sound; plays while the game is paused.
func play_ui(id: StringName) -> void:
	var stream: AudioStream = bank.pick(id, _rng)
	if stream == null:
		return
	_ui_voice.stream = stream
	_ui_voice.play()
	sound_played.emit(id, &"UI")


## A looping sound owned by the caller (add it to the level, so it ends with the level).
func make_loop(id: StringName, bus: StringName = &"Ambience", volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream: AudioStream = bank.pick(id, _rng)
	if stream == null:
		return null
	var loop: AudioStream = stream.duplicate()
	var wav: AudioStreamWAV = loop as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = loop
	player.bus = bus
	player.volume_db = volume_db
	player.autoplay = true
	return player


func _walls_to_listener(position: Vector3, source: Node) -> int:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_to(position) < AudioRules.MIN_OCCLUSION_DISTANCE_M:
		return 0
	var exclude: Array[RID] = []
	var body: CollisionObject3D = source as CollisionObject3D
	if body != null:
		exclude.append(body.get_rid())
	return NoiseSystem.walls_between(position, camera.global_position, exclude)
