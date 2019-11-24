#version 460 core
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec4 inOrigin;
layout(location = 1) in vec3 inUvCoord;

layout(location = 0) out vec3 outUvCoord;

out gl_PerVertex {
  vec4 gl_Position;
};

void main() {
  gl_Position = inOrigin;
  outUvCoord = inUvCoord;
}
