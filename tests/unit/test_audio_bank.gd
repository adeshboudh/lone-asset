extends GdUnitTestSuite
## AudioRules, the sound bank and the bus layout.

const BANK: SoundBank = preload("res://data/audio/sound_bank.tres")
const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")


func test_occlusion_volume_per_wall() -> void:
	assert_float(AudioRules.occlusion_volume_db(0)).is_equal(0.0)
	assert_float(AudioRules.occlusion_volume_db(1)).is_equal(-6.0)
	assert_float(AudioRules.occlusion_volume_db(2)).is_equal(-12.0)


func test_occlusion_stops_at_max_walls() -> void:
	assert_float(AudioRules.occlusion_volume_db(9)).is_equal(AudioRules.DB_PER_WALL * NoiseRules.MAX_WALLS)


func test_muffled_variant_only_behind_walls_and_when_available() -> void:
	assert_str(AudioRules.variant_id(&"landing", 0, true)).is_equal("landing")
	assert_str(AudioRules.variant_id(&"landing", 1, true)).is_equal("landing_muffled")
	assert_str(AudioRules.variant_id(&"ui_click", 1, false)).is_equal("ui_click")


func test_every_sound_in_the_bank_loads_and_has_length() -> void:
	for id: StringName in BANK.sounds:
		var variants: Array = BANK.sounds[id]
		assert_array(variants).override_failure_message("'%s' has no variants" % id).is_not_empty()
		for stream: AudioStream in variants:
			assert_object(stream).override_failure_message("'%s' variant did not load" % id).is_not_null()
			assert_float(stream.get_length()).override_failure_message("'%s' is empty" % id).is_greater(0.02)


func test_weapon_sound_ids_exist() -> void:
	for id: StringName in [RIFLE.fire_sound, RIFLE.dry_fire_sound, RIFLE.reload_sound, RIFLE.reload_empty_sound]:
		assert_bool(BANK.has_sound(id)).override_failure_message("missing '%s'" % id).is_true()


func test_gameplay_sounds_exist_with_muffled_copies() -> void:
	for id: StringName in [&"footstep_concrete", &"footstep_metal", &"footstep_grass", &"landing", &"impact_world", &"impact_body", &"rifle_shot_suppressed"]:
		assert_bool(BANK.has_sound(id)).override_failure_message("missing '%s'" % id).is_true()
		assert_bool(BANK.has_sound(StringName(String(id) + "_muffled"))).override_failure_message("missing muffled '%s'" % id).is_true()
	for id: StringName in [&"hit_marker", &"ui_click", &"wind_loop"]:
		assert_bool(BANK.has_sound(id)).override_failure_message("missing '%s'" % id).is_true()


func test_reload_sounds_fit_the_reload_times() -> void:
	# The sound should finish at about the time the reload does.
	var normal: float = (BANK.sounds[RIFLE.reload_sound] as Array)[0].get_length()
	var empty: float = (BANK.sounds[RIFLE.reload_empty_sound] as Array)[0].get_length()
	assert_float(normal).is_between(RIFLE.reload_time - 0.3, RIFLE.reload_time + 0.1)
	assert_float(empty).is_between(RIFLE.reload_time_empty - 0.3, RIFLE.reload_time_empty + 0.1)


func test_bus_layout_has_all_buses_routed_correctly() -> void:
	for bus: StringName in [&"Music", &"SFX", &"Weapons", &"Footsteps", &"Ambience", &"UI", &"Voice"]:
		assert_int(AudioServer.get_bus_index(bus)).override_failure_message("missing bus '%s'" % bus).is_greater_equal(0)
	for bus: StringName in [&"Weapons", &"Footsteps", &"Ambience"]:
		assert_str(AudioServer.get_bus_send(AudioServer.get_bus_index(bus))).is_equal("SFX")
	assert_str(AudioServer.get_bus_send(AudioServer.get_bus_index(&"SFX"))).is_equal("Master")


func test_sounds_are_imported_uncompressed() -> void:
	# Web builds play samples; uncompressed PCM is the safe format for sample playback.
	var dir: DirAccess = DirAccess.open("res://content/audio/sfx")
	var checked: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".wav.import"):
			continue
		var config: ConfigFile = ConfigFile.new()
		assert_int(config.load("res://content/audio/sfx/" + file)).is_equal(OK)
		assert_int(config.get_value("params", "compress/mode", -1)).override_failure_message("%s is compressed" % file).is_equal(0)
		checked += 1
	assert_int(checked).is_greater(30)
