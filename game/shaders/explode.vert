#version 440

#ifdef GL_ES
precision mediump int;
precision highp float;
#endif

// User varying needs a location under SPIR-V too

layout(location = 0) in  highp vec2 v_uv;
layout(location = 0) out highp vec4 fragColor;
// Keep UBO at binding=0 in the vert; sampler goes at binding=1
layout(binding = 1) uniform sampler2D source;


void main() {
    fragColor = texture(source, v_uv);
}
