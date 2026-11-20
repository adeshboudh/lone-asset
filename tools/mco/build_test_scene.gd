# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
extends SceneTree
## Builds content/animations/mco/mco_test.tscn (MotusMan, M4 on the right-hand weapon bone,
## every MCO clip in one AnimationLibrary). Run:
## godot --headless --path . --script tools/mco/build_test_scene.gd

const ROOT := "res://content/animations/mco/"
const LIB_PATH := ROOT + "mco_clips.res"
const SCENE_PATH := ROOT + "mco_test.tscn"
const WEAPON_BONE := "hand_r_wep"


func _find_fbx(dir_path: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".fbx") and f != "MotusMan_v55.fbx":
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		_find_fbx(dir_path.path_join(d), out)


func _init() -> void:
	var lib := AnimationLibrary.new()
	var files: Array[String] = []
	_find_fbx(ROOT, files)
	files.sort()
	for p in files:
		var inst: Node = (load(p) as PackedScene).instantiate()
		for ap: AnimationPlayer in inst.find_children("*", "AnimationPlayer", true, false):
			for a in ap.get_animation_list():
				var anim: Animation = ap.get_animation(a).duplicate()
				var id := StringName(p.get_file().get_basename().replace(" ", "_"))
				lib.add_animation(id, anim)
		inst.free()
	ResourceSaver.save(lib, LIB_PATH)
	lib = load(LIB_PATH) as AnimationLibrary  # reference the saved file, not an inline copy

	var root := Node3D.new()
	root.name = "McoTest"
	var model: Node3D = (load(ROOT + "MotusMan_v55.fbx") as PackedScene).instantiate()
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var att := BoneAttachment3D.new()
	att.name = "RightHandWeapon"
	att.bone_name = WEAPON_BONE
	att.use_external_skeleton = true  # nodes added inside an instanced model are not saved
	root.add_child(att)
	att.owner = root
	att.external_skeleton = att.get_path_to(skel)
	var gun: Node3D = (load("res://content/weapons/m4_mco/M4_Rifle_01.fbx") as PackedScene).instantiate()
	gun.name = "M4"
	att.add_child(gun)
	gun.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	player.root_node = player.get_path_to(model)
	player.add_animation_library("", lib)
	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, SCENE_PATH)
	print("clips=", lib.get_animation_list().size(), " skeleton=", model.get_path_to(skel), " save=", err)
	root.free()
	quit()
