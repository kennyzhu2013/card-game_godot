# phigros_lane port notice

This directory contains code ported from [godot-phigros](https://github.com/Naptie/godot-phigros)
under the **Mozilla Public License 2.0** (MPL-2.0).

## What was ported

- `globals.gd` → `lane_globals.gd` (subset: time/geometry helpers only)
- `note_part.gd` → `note_part.gd` (adapted for 4-lane DFJK input)
- `note_part.tscn` → `note_part.tscn`
- `judgeline.gd` → `judgeline.gd` (added `direction` parameter)
- `hit_effects.gd` → `hit_effects.gd`
- `hit_effects.tscn` → `hit_effects.tscn`
- `square.gd` → `square.gd`
- `square.tscn` → `square.tscn`
- `shaders/{darkening,h_blur,v_blur}.gdshader`

## License header

Every ported `.gd` file MUST start with:

```gdscript
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Original author: Naptie (https://github.com/Naptie/godot-phigros)
# Adapted for the Greycrown rhythm-combat module, 2026-05-13.
```

The full MPL-2.0 text is bundled at
[licenses/MPL-2.0.txt](../../../../../licenses/MPL-2.0.txt) and is also
available at https://www.mozilla.org/MPL/2.0/.

The list above identifies the adapted files. Local changes remain visible in
the corresponding source files and their retained MPL headers.
