<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Playtest YYYY-MM-DD

- Build (version string from the title screen):
- Hardware / OS / renderer (Vulkan or OpenGL):
- Quality preset / render scale / FOV / sensitivity:
- Recording file:
- Approach (undetected / combat / mixed):
- Completed mission: yes / no, time:
- Deaths:

## Ratings (1 to 5)

| Area | Rating | Notes |
|---|---|---|
| Movement feel |4 | |
| Aiming and recoil |4 | |
| Weapon audio |1 |the gun sound is suppressed |
| Stealth readability ("I knew why I was seen") |3 | |
| AI believability |3 |we can make the tougher AI based on the light he on |
| Hero-area visuals | 4| good enough for 1st iteration but not up to the par for real game|
| Performance smoothness | 4| the game is smooth in windows|

## Detection log

One line per time a guard reached Combat. Cause must be explainable from HUD and audio alone; if not, it is a bug.

| Time | Guard | Cause | Visible from HUD/audio? |
|---|---|---|---|

## Acceptance spot-checks

- [ ] #3 mouse capture, Esc, focus loss, fullscreen
- [ ] #4 log has no script errors
- [ ] #7 changed a rifle value, behaviour changed
- [ ] #18 quit and relaunch restored the checkpoint

## Bugs and tuning ideas
