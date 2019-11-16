module rendernode;

// import bindbc.opengl;
// import dtoavkbindings.cgltf;
// import dtrl.commandbuffer;
// import gl.cgltfenum;
// static import neobc;

// import core.stdc.stdio;
// import core.stdc.stdlib;

// enum RenderPassType {
//   Full
// , Depth
// };

// struct RenderNode {
//   cgltf_data* data;
//   neobc.Array!(GlBuffer) glBuffers;

//   static RenderNode Construct(string filename) {
//     RenderNode self;
//     ConstructRenderNode(self, filename);
//     return self;
//   }
// };

// private void ConstructRenderNode(ref RenderNode self , string filename)
// {
//   { // -- load node
//     cgltf_options options;
//     cgltf_result result = cgltf_parse_file(&options, filename.ptr, &self.data);

//     if (result != cgltf_result.success) {
//       "Error loading '%s': '%s'\n"
//         .printf(filename.ptr , neobc.ToString(result).ptr);
//       return;
//     }

//     result = cgltf_load_buffers(&options, self.data, filename.ptr);
//     if (result != cgltf_result.success) {
//       "Error loading buffers for '%s': '%s'\n"
//         .printf(
//           filename.ptr
//         , neobc.ToString(result).ptr
//         );
//       return;
//     }
//   }

//   // -- construct buffers
//   self.glBuffers.Resize(self.data.buffers_count);
//   foreach (i; 0 .. self.glBuffers.length) {
//     GlBuffer* buffer = self.glBuffers.ptr + i;
//     cgltf_buffer* cgltfBuffer = self.data.buffers + i;

//     import core.stdc.string;

//     *buffer =
//       GlBuffer.Construct(
//         cgltfBuffer.uri,
//         strlen(cgltfBuffer.uri),
//         neobc.ArrayView.Construct(cgltfBuffer.size, cgltfBuffer.data),
//         0
//       );
//   }
// }


// private GlBuffer* GetGlBuffer(ref RenderNode node, cgltf_buffer* buffer) {
//   foreach (i; 0 .. node.data.buffers_count) {
//     if (node.data.buffers + i == buffer) {
//       return node.glBuffers.ptr + i;
//     }
//   }
//   return null;
// }

// void ConstructRenderPass(
//   ref RenderNode self
// , RenderPassType renderPassType
// , GLuint framebuffer
// , out CommandBuffer commandBuffer
// , out neobc.Array!GlState glStates
// ) {

//   import gl.nvidia;
//   import gl.program;

//   commandBuffer = CommandBuffer.Construct;

//   GLuint commandProgram =
//     CreateProgram(neobc.Array!string("data/gltf.vert", "data/gltf.frag"));

//   foreach (meshIdx; 0 .. self.data.meshes_count) {
//     cgltf_mesh* mesh = self.data.meshes + meshIdx;
//     foreach (primitiveIdx; 0 .. mesh.primitives_count) {
//       cgltf_primitive* primitive = mesh.primitives + primitiveIdx;

//       { // -- element buffer handle
//         auto elementCommand = commandBuffer.Enqueue!ElementAddressCommandNV;

//         cgltf_accessor* accessor = primitive.indices;
//         GlBuffer* buffer = self.GetGlBuffer(accessor.buffer_view.buffer);
//         elementCommand.typeSizeInByte = accessor.component_type.ByteSize;
//         (*buffer).GetAddressHiLo(
//           elementCommand.addressLo,
//           elementCommand.addressHi
//         );
//       }

//       foreach (attributeIdx; 0 .. primitive.attributes_count) {
//         auto attributeCommand = commandBuffer.Enqueue!AttributeAddressCommandNV;

//         cgltf_attribute* attribute = primitive.attributes + attributeIdx;
//         GlBuffer* buffer = self.GetGlBuffer(attribute.data.buffer_view.buffer);
//         attributeCommand.index = attribute.index;
//         (*buffer).GetAddressHiLo(
//           attributeCommand.addressLo,
//           attributeCommand.addressHi
//         );
//       }

//       { // -- draw
//         auto drawCommand = commandBuffer.Enqueue!DrawElementsCommandNV;
//         drawCommand.count = cast(GLuint)primitive.indices.count;
//         drawCommand.firstIndex = cast(GLuint)primitive.indices.offset;
//         drawCommand.baseVertex = 0;
//       }

//       GlState* state = glStates.ConstructAppend;

//       { // -- capture generic state
//         foreach (attributeIdx; 0 .. primitive.attributes_count) {
//           cgltf_attribute* attribute = primitive.attributes + attributeIdx;
//           glEnableVertexAttribArray(attribute.index);
//           glBindVertexBuffer(
//             attribute.index                    /* bindingindex */
//           , 0                                  /* buffer */
//           , attribute.data.offset              /* offset */
//           , cast(GLsizei)attribute.data.stride /* stride */
//           );
//           glVertexAttribFormat(
//             attribute.index                            /* attribindex */
//           , attribute.data.type.Length                 /* size */
//           , attribute.data.component_type.ToGlEnumType /* type */
//           , attribute.data.normalized.ToGlEnum         /* normalized */
//           , 0                                          /* relativeoffset */
//           );
//         }

//         glStateCaptureNV(state.handle, primitive.type.ToGlEnum);

//         // -- clear state
//         foreach (attributeIdx; 0 .. primitive.attributes_count) {
//           glDisableVertexAttribArray(0);
//         }
//       }

//       commandBuffer.FinishTokenStream(framebuffer, state.handle);
//     }
//   }
// }

// bool Valid(ref inout(RenderNode) node) {
//   return node.data != null;
// }
