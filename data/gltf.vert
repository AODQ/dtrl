#version 460 core

in layout(location = 0) vec3 originIn;

uniform layout(location = 0) int offset;

out gl_PerVertex {
  vec4 gl_Position;
};

void main(void) {
  gl_Position = vec4(originIn, 1.0f);
}
