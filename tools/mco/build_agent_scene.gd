# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
extends SceneTree
## Builds content/characters/agent_mco/agent_mco_test.tscn: the agent skinned onto the MotusMan
## skeleton (clips come with the GLB) with the MCO M4 on the right-hand weapon bone. Run:
## godot --headless --path . --script tools/mco/build_agent_scene.gd

const SCENE_PATH := "res://content/characters/agent_mco/agent_mco_test.tscn"


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "AgentMcoTest"
	var model: Node3D = (load("res://content/characters/agent_mco/agent_mco.glb") as PackedScene).instantiate()
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var att := BoneAttachment3D.new()
	att.name = "RightHandWeapon"
	att.bone_name = "hand_r_wep"
	att.use_external_skeleton = true
	root.add_child(att)
	att.owner = root
	att.external_skeleton = att.get_path_to(skel)
	var gun: Node3D = (load("res://content/weapons/m4_mco/M4_Rifle_01.fbx") as PackedScene).instantiate()
	gun.name = "M4"
	att.add_child(gun)
	gun.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	print("save=", ResourceSaver.save(scene, SCENE_PATH))
	root.free()
	quit()
