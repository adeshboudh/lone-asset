extends Node3D
## First-person M4A1 Custom: the fan-made model split into named parts (see content/LICENSES.md) on the animated
## arm rig of the M4 pack (BarcodeGames, CC-BY; its gloved arms are not drawn). The pack's own rifle is hidden; the gun body, sights, optic
## and suppressor follow the rig's Main bone and the magazine follows its two magazine bones, so the pack's Draw,
## Fire, Reload and Reload_Empty animations still drive the new gun. Exposes the Muzzle node and animation names
## the Weapon node looks for.
const PARTS_SCENE := "res://content/weapons/m4a1_custom/m4a1_custom_parts.glb"
## Muzzle in the pack camera's frame (metres, camera looks along -z).
const MUZZLE := Vector3(0.071, -0.07, -0.74)
## Where the gun model's own frame (forward +x, up +y) sits in the pack camera's frame: turned to look down -z,
## suppressor tip on the old muzzle, lens of the optic on the old red-dot lens height.
const GUN_ORIGIN := Vector3(0.069, -0.1485, -0.174)
const GUN_YAW: float = PI * 0.5
## Parts that ride the rig's Main bone. The vertical foregrip (m4a1_custom_foregrip) is left off: the left hand
## holds the handguard (LEFT_HOLD_*).
const BODY_PARTS: Array[StringName] = [&"m4a1_custom_body", &"m4a1_custom_iron_sights",
		&"m4a1_custom_optic", &"m4a1_custom_optic_lens", &"m4a1_custom_suppressor", &"m4a1_custom_muzzle_brake"]
const MAGAZINE_PART: StringName = &"m4a1_custom_magazine"
const LENS_SHADER := "res://content/weapons/m4a1_custom/scope_lens.gdshader"
## Layer the viewmodel is drawn on, so the scope camera can leave the gun itself out of its picture.
const VIEWMODEL_LAYER: int = 1 << 18
const HIDDEN_LAYER: int = 1 << 19
const PICTURE_SIZE: int = 768
## Lens disc radius in the model's own units (it is about 19 mm across).
const LENS_RADIUS_M: float = 0.0095
## The optic is drawn larger than the model so the scope picture reads on screen, scaled about its feet on the
## rail: the lens centre, in the gun model's frame (forward +x, up +y).
const OPTIC_SCALE: float = 1.25
const OPTIC_PIVOT := Vector3(0.088, 0.105, 0.002)
const OPTIC_PARTS: Array[StringName] = [&"m4a1_custom_optic", &"m4a1_custom_optic_lens"]
## Where the first-person arms' left hand holds the handguard, in the pack camera's frame at the Idle pose: the
## wrist, the direction wrist to middle knuckle and the direction index knuckle to little-finger knuckle (FpsArms
## reads the LeftHandHold node built from these), and how far the fingers open from the pack's foregrip fist
## (0 = as the pack, 1 = the arms model's relaxed rest) to wrap the wider handguard.
const LEFT_HOLD_WRIST := Vector3(0.017, -0.124, -0.337)
const LEFT_HOLD_FORWARD := Vector3(0.55, -0.09, -0.83)
const LEFT_HOLD_SIDEWAYS := Vector3(0.0, 0.0, 1.0)
const LEFT_HOLD_FINGER_OPEN: float = 0.45

var animation_player: AnimationPlayer

var _suppressor: Node3D
var _muzzle_brake: Node3D
var _lens: MeshInstance3D
var _lens_material: ShaderMaterial
var _lens_center_local: Vector3
var _scope_viewport: SubViewport
var _scope_camera: Camera3D
var _zoom: float = 1.0
var _scope_wanted: bool = false


func _ready() -> void:
	var rig: Node3D = (load("res://content/weapons/m4/source/M4.fbx") as PackedScene).instantiate()
	add_child(rig)
	animation_player = rig.get_node("AnimationPlayer") as AnimationPlayer
	animation_player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	animation_player.play(&"Idle")
	animation_player.seek(0.0, true)
	var skel: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	skel.force_update_all_bone_transforms()
	var cam: Node3D = skel.get_node("FPS_Camera/FPS_Camera") as Node3D
	# camera pose relative to this node, not to the world: the wrapper sits under the player's camera
	var cam_xf: Transform3D = global_transform.affine_inverse() * cam.global_transform
	rig.transform = cam_xf.affine_inverse()
	_hide_pack_hands(rig)
	_hide_old_gun(skel)
	_fit_new_gun(skel)
	_build_lens()
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = VIEWMODEL_LAYER
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = MUZZLE


## Suppressor on (suppressed variant) or the muzzle brake instead.
func show_suppressor(on: bool) -> void:
	if _suppressor != null:
		_suppressor.visible = on
	if _muzzle_brake != null:
		_muzzle_brake.visible = not on


## Called every frame by the Weapon: how far the gun is raised to aim (0-1) and the scope zoom of its definition.
## The scope camera is only created and rendered while the picture can be seen.
func set_aim(aim_blend: float, zoom: float) -> void:
	if _lens_material == null:
		return
	_zoom = zoom
	_scope_wanted = ScopeRules.should_render(aim_blend, zoom)
	_lens_material.set_shader_parameter(&"picture_blend", ScopeRules.picture_blend(aim_blend) if zoom > 1.0 else 0.0)
	if _scope_wanted and _scope_viewport == null:
		_build_scope_camera()
	if _scope_viewport != null:
		_scope_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _scope_wanted else SubViewport.UPDATE_DISABLED


## Runs right before the frame is drawn, after the animation, the sway and the bones have moved the lens, so the
## scope camera and the lens shader use the pose that is actually on screen (set earlier in the frame, the
## picture lags the gun by a frame and tears while moving).
func _sync_scope_camera() -> void:
	if not _scope_wanted or _scope_camera == null or not is_inside_tree():
		return
	var eye: Camera3D = get_viewport().get_camera_3d()
	if eye == null:
		return
	var lens_xf: Transform3D = _lens.global_transform
	var lens_world: Vector3 = lens_xf * _lens_center_local
	var lens_tan: float = ScopeRules.lens_tan(LENS_RADIUS_M * OPTIC_SCALE, eye.global_position.distance_to(lens_world))
	_lens_material.set_shader_parameter(&"lens_tan", lens_tan)
	_scope_camera.fov = ScopeRules.camera_fov_deg(lens_tan, _zoom)
	# The camera sits on the lens and looks where the view camera looks, which is where the bullets are aimed
	# (the shot goes from the muzzle to the point under the crosshair), so the reticle and the hits agree.
	_scope_camera.global_transform = Transform3D(eye.global_transform.basis.orthonormalized(), lens_world)
	_scope_camera.cull_mask = eye.cull_mask & ~(VIEWMODEL_LAYER | HIDDEN_LAYER)


## Replaces the lens' plain material with the scope glass shader.
func _build_lens() -> void:
	_lens = find_child("m4a1_custom_optic_lens", true, false) as MeshInstance3D
	var aabb: AABB = _lens.get_aabb()
	_lens_center_local = aabb.get_center()
	_lens_material = ShaderMaterial.new()
	_lens_material.shader = load(LENS_SHADER) as Shader
	_lens_material.set_shader_parameter(&"lens_center", _lens_center_local)
	_lens_material.set_shader_parameter(&"lens_radius", LENS_RADIUS_M)
	_lens.material_override = _lens_material
	_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_scope_camera() -> void:
	_scope_viewport = SubViewport.new()
	_scope_viewport.name = "ScopeViewport"
	_scope_viewport.size = Vector2i(PICTURE_SIZE, PICTURE_SIZE)
	_scope_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_scope_viewport.msaa_3d = Viewport.MSAA_2X  # the zoomed picture shimmers on thin edges without it
	_scope_viewport.positional_shadow_atlas_size = 0
	add_child(_scope_viewport)
	_scope_camera = Camera3D.new()
	_scope_camera.name = "ScopeCamera"
	_scope_camera.near = 0.05
	_scope_camera.far = 600.0
	_scope_viewport.add_child(_scope_camera)
	_scope_camera.current = true
	_lens_material.set_shader_parameter(&"scope_picture", _scope_viewport.get_texture())
	RenderingServer.frame_pre_draw.connect(_sync_scope_camera)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_scope_camera):
		RenderingServer.frame_pre_draw.disconnect(_sync_scope_camera)


## The pack's gloved arms are not drawn: the first-person arms (FpsArms, added by Weapon) follow the pack's bones,
## which the animations still move.
func _hide_pack_hands(rig: Node3D) -> void:
	(rig.find_child("Hand_Mesh", true, false) as MeshInstance3D).visible = false


## The pack's own rifle, magazines, bolt and loose rounds are not drawn; the bones still animate.
func _hide_old_gun(skel: Skeleton3D) -> void:
	for child: Node in skel.get_children():
		if child is BoneAttachment3D:
			(child as Node3D).visible = false


## Hangs the model's parts on the rig's bones, in the pose the Idle animation starts from.
func _fit_new_gun(skel: Skeleton3D) -> void:
	var parts: Node3D = (load(PARTS_SCENE) as PackedScene).instantiate() as Node3D
	var gun_in_view: Transform3D = Transform3D(Basis(Vector3.UP, GUN_YAW), GUN_ORIGIN)
	var main: int = skel.find_bone("Main_j")
	var main_in_view: Transform3D = _bone_in_view(skel, main)
	var holder := BoneAttachment3D.new()
	holder.name = "M4A1CustomBody"
	skel.add_child(holder)
	holder.set_use_external_skeleton(false)
	holder.bone_name = "Main_j"
	for part_name: StringName in BODY_PARTS:
		var part: MeshInstance3D = parts.get_node(NodePath(part_name)) as MeshInstance3D
		part.owner = null
		parts.remove_child(part)
		holder.add_child(part)
		part.transform = main_in_view.affine_inverse() * gun_in_view
		if part_name in OPTIC_PARTS:
			part.transform *= Transform3D(Basis.from_scale(Vector3.ONE * OPTIC_SCALE), OPTIC_PIVOT * (1.0 - OPTIC_SCALE))
	_suppressor = holder.get_node("m4a1_custom_suppressor") as Node3D
	_muzzle_brake = holder.get_node("m4a1_custom_muzzle_brake") as Node3D
	show_suppressor(true)
	var mag_source: MeshInstance3D = parts.get_node(NodePath(MAGAZINE_PART)) as MeshInstance3D
	mag_source.owner = null
	parts.remove_child(mag_source)
	for bone_name: String in ["Mag1_j", "Mag2_j"]:
		var bone: int = skel.find_bone(bone_name)
		var mag_holder := BoneAttachment3D.new()
		mag_holder.name = "M4A1Custom" + bone_name.trim_suffix("_j")
		skel.add_child(mag_holder)
		mag_holder.bone_name = bone_name
		var mag: MeshInstance3D = mag_source if bone_name == "Mag1_j" else mag_source.duplicate() as MeshInstance3D
		mag_holder.add_child(mag)
		mag.transform = _bone_in_view(skel, bone).affine_inverse() * gun_in_view
	parts.queue_free()
	var hold := Node3D.new()
	hold.name = "LeftHandHold"
	holder.add_child(hold)
	hold.transform = main_in_view.affine_inverse() * Transform3D(FpsArmsRules.bone_frame(LEFT_HOLD_FORWARD, LEFT_HOLD_SIDEWAYS), LEFT_HOLD_WRIST)
	hold.set_meta(&"finger_open", LEFT_HOLD_FINGER_OPEN)


func _bone_in_view(skel: Skeleton3D, bone: int) -> Transform3D:
	return global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(bone)
