// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Original author: Naptie (https://github.com/Naptie/godot-phigros)
// Adapted for TurnBasedOpenWorld phigros Pokemon rehost, 2026-05-13.
shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    vec3 darkened_color = texture_color.rgb * (1.0 - darkness);
    COLOR = vec4(darkened_color, texture_color.a);
}
