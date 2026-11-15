# Procedural first-person gun feel: design

Date: 2026-11-16. Status: approved by the developer ("yes") for the first three parts.

## Intent

Make the first-person rifle feel like a current shooter. The reference is a screen recording and a still the
developer supplied (studied frame by frame, not shipped): rifle canted in toward the centre at the hip, left hand far
forward on the handguard, and a kick on each shot that throws the gun back toward the eye, tips the muzzle up with a
little random roll, and springs back with a slight overshoot in about 0.3 s.

## Parts (built)

1. **Spring kick** (`ViewmodelRecoilRules`, `Weapon.kick_viewmodel`): each shot pushes a damped spring for position
   and rotation; the push is sized so the swing peaks at the weapon's `recoil_kick_*` values; shots pile up; aiming
   keeps `recoil_kick_ads_mult` of it. It rides on top of the weapon's animation, turning about `viewmodel_pivot`
   (the right-hand grip). Numbers per weapon in `data/weapons/*.tres`.
2. **Hip turn** (`viewmodel_hip_rotation_deg`, about the same pivot, faded out while aiming so the sight alignment
   is untouched).
3. **Left hand forward**: the rifle's left-hand hold moved 6 cm toward the muzzle (`LEFT_HOLD_WRIST`).

## Later

Fire-selector thumb flick, trigger-finger pull, sway and bob checked against the reference, auto-fire climb.

## Approaches considered

Spring per shot (chosen: piles up for auto fire, overshoot for free, two numbers for the feel) versus a fixed
kick curve per shot (does not stack naturally) versus animation clips (none to use beyond the pack's Fire).
