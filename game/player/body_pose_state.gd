class_name BodyPoseState
extends RefCounted
## What the player body needs to know each frame to pose itself (design §4).

var eye_height: float = 1.65
## Speed along the floor in m/s and the footstep stride of the current gait in metres.
var ground_speed: float = 0.0
var stride_m: float = 1.0
var grounded: bool = true
## Vertical speed in m/s, up positive.
var vertical_speed: float = 0.0
var sprinting: bool = false
## -1 full left, 1 full right (the player's own left and right).
var lean: float = 0.0
## 0 hip, 1 aimed.
var aim_blend: float = 0.0
## 0 lowered, 1 binoculars at the eyes.
var binoculars_blend: float = 0.0
