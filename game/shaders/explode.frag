#version 440

#ifdef QSHADER_SPIRV
layout(location = 0) in  highp vec2 v_uv;
layout(location = 0) out highp vec4 fragColor;
// keep UBO at binding 0 in the vert; use binding 1 for the sampler
layout(binding = 1) uniform sampler2D source;
#endif

#ifndef QSHADER_SPIRV
layout(location = 0) in highp vec2 v_uv;
layout(location = 0) out highp vec4 fragColor;
layout(binding = 1) uniform sampler2D source;
#endif

#ifdef GL_ES
precision mediump int;
precision highp float;
#endif

void main() {
    fragColor = texture(source, v_uv);
}
