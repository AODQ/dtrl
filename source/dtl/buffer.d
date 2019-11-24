module dtl.buffer;

import dtl.vkutil;
import dtoavkbindings.vk;

static import neobc;
static import dtl;

////////////////////////////////////////////////////////////////////////////////
struct MappedBuffer {

  VkDevice device;
  VkDeviceMemory memory;
  size_t length;
  void* data;

  ~this() { Unmap; }

  // not necessary as this is RAII
  void Unmap() {
    if (!data) { return; }
    vkUnmapMemory(this.device, this.memory);
    data = null;
  }
};

////////////////////////////////////////////////////////////////////////////////
struct Buffer {

  dtl.FrameworkContext* fw;
  VkBuffer handle;
  VkDeviceMemory memory;
  size_t length;

  ~this() { Free; }

  void Free() {
    if (this.handle) { vkDestroyBuffer(this.fw.device, this.handle, null); }
    if (this.memory) { vkFreeMemory(this.fw.device, this.memory, null); }
    this.handle = null;
    this.memory = null;
  }

  static Buffer Construct(
    ref dtl.FrameworkContext fw
  , size_t byteLength
  , VkBufferUsageFlags usage
  , VkMemoryPropertyFlags memoryProperties
  , VkSharingMode sharingMode = VkSharingMode.exclusive
  ) {
    Buffer self;
    self.fw = &fw;
    self.length = byteLength;

    { // -- create buffer
      VkBufferCreateInfo info = {
        sType: VkStructureType.bufferCreateInfo
      , size: self.length
      , usage: usage
      , sharingMode: sharingMode
      };

      vkCreateBuffer(self.fw.device, &info, null, &self.handle).EnforceVk;
    }

    { // -- allocate memory
      VkMemoryRequirements memReq;
      vkGetBufferMemoryRequirements(self.fw.device, self.handle, &memReq);

      VkMemoryAllocateInfo info = {
        sType: VkStructureType.memoryAllocateInfo
      , allocationSize: memReq.size
      , memoryTypeIndex:
          FindMemoryType(
            self.fw.physicalDevice, memReq.memoryTypeBits, memoryProperties
          )
      };

      vkAllocateMemory(self.fw.device, &info, null, &self.memory).EnforceVk;

    }

    vkBindBufferMemory(self.fw.device, self.handle, self.memory, 0);

    return self;
  }

  bool Initialized() { return cast(bool)fw; }

  // -- performs staging copy
  static Buffer Construct(
    ref dtl.FrameworkContext fw
  , ref Buffer srcBuffer
  , VkBufferUsageFlags usage
  , VkMemoryPropertyFlags memoryProperties
  , VkSharingMode sharingMode = VkSharingMode.exclusive
  ) {
    neobc.EnforceAssert(srcBuffer.Initialized, "src buffer uninitialized");
    Buffer self =
      Buffer.Construct(
        fw, srcBuffer.length, usage, memoryProperties, sharingMode
      );

    vkResetCommandBuffer(
      fw.transientCommandBuffer
    , VkCommandBufferResetFlag.releaseResourcesBit
    );

    VkCommandBufferBeginInfo beginInfo = {
      sType: VkStructureType.commandBufferBeginInfo
    , flags: VkCommandBufferUsageFlag.oneTimeSubmitBit
    };

    vkBeginCommandBuffer(fw.transientCommandBuffer, &beginInfo);

    VkBufferCopy copyRegion = {
      srcOffset: 0
    , dstOffset: 0
    , size: self.length
    };
    vkCmdCopyBuffer(
      fw.transientCommandBuffer
    , srcBuffer.handle, self.handle
    , 1, &copyRegion
    );

    vkEndCommandBuffer(fw.transientCommandBuffer);

    VkSubmitInfo submitInfo = {
      sType: VkStructureType.submitInfo
    , commandBufferCount: 1
    , pCommandBuffers: &fw.transientCommandBuffer
    };

    vkQueueSubmit(fw.transferQueue, 1, &submitInfo, null);
    vkQueueWaitIdle(fw.transferQueue);

    return self;
  }

  MappedBuffer MapBufferRange(
    size_t byteOffset = 0
  , size_t byteLength = 0
  , VkMemoryMapFlags flags = 0
  ) {
    neobc.EnforceAssert(this.Initialized, "src buffer uninitialized");
    if (byteLength == 0) { byteLength = this.length; }

    MappedBuffer mappedBuffer = {
      device: this.fw.device
    , memory: this.memory
    , length: byteLength
    };

    vkMapMemory(
      this.fw.device
    , this.memory
    , byteOffset, byteLength
    , flags
    , &mappedBuffer.data
    );

    return mappedBuffer;
  }
};
