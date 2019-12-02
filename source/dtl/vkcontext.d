module dtl.vkcontext;

import dtl.vkutil;

import bindbc.glfw;
import dtoavkbindings.vk;
import neobc.assertion;
static import neobc;

import core.stdc.stdio;

mixin(bindGLFW_Vulkan);

//------------------------------------------------------------------------------
// -- static utility

private neobc.Array!(const(char)*) GetRequiredGlfwExtensions() {
  neobc.Array!(const(char)*) extensions;
  uint requiredExtensionLength;
  const(char)** requiredExtensions =
    glfwGetRequiredInstanceExtensions(&requiredExtensionLength);

  foreach ( size_t i; 0 .. requiredExtensionLength ) {
    extensions ~= requiredExtensions[i];
  }
  return extensions;
}

static extern(C) VkBool32 DebugCallback(
  VkDebugUtilsMessageSeverityFlagEXT messageSeverity
, VkDebugUtilsMessageTypeFlagsEXT messageType
, const (VkDebugUtilsMessengerCallbackDataEXT)* callbackData
, void* userData
) {
  switch (messageSeverity)
  {
    default: break;
    case VkDebugUtilsMessageSeverityFlagEXT.errorBitExt:
      printf(
        "%s%s%s%s\n"
      , "\033[0;31m".ptr
      , "vk error: ".ptr
      , "\033[0m".ptr
      , callbackData.pMessage
      );
    break;
    case VkDebugUtilsMessageSeverityFlagEXT.infoBitExt:
    break;
    case VkDebugUtilsMessageSeverityFlagEXT.verboseBitExt:
    break;
    case VkDebugUtilsMessageSeverityFlagEXT.warningBitExt:
      printf(
        "%s%s%s%s\n"
      , "\033[0;33m".ptr
      , "vk warning: ".ptr
      , "\033[0m".ptr
      , callbackData.pMessage
    );
    break;
  }

  return VK_FALSE;
}

//------------------------------------------------------------------------------
// -- module specific
struct ApplicationSettings {
  VkApplicationInfo applicationInfo;
  string name;
  uint windowResolutionX;
  uint windowResolutionY;
  VkFormat surfaceFormat;
  bool enableValidation;
  bool enableVsync;
};

private void InitializeGlfw(ref FrameworkContext self) {
  glfwInit.EnforceAssert;
  glfwVulkanSupported.EnforceAssert;

  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
  glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
  self.window =
    glfwCreateWindow(
      self.settings.windowResolutionX
    , self.settings.windowResolutionY
    , self.settings.name.ptr
    , null
    , null
  );

  self.window.EnforceAssert;
}

private void InitializeInstance(ref FrameworkContext self) {
  neobc.Array!(const(char)*) extensions = GetRequiredGlfwExtensions();
  neobc.Array!(const(char)*) layers;

  // -- validation
  if (self.settings.enableValidation) {
    extensions ~= VK_EXT_DEBUG_REPORT_EXTENSION_NAME;
    extensions ~= VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
    layers     ~= "VK_LAYER_LUNARG_standard_validation";
  }

  // -- print out extensions
  printf("Extensions:\n");
  foreach (ref i; extensions.AsRange)
    printf(" * %s\n", i);
  printf("---\n");
  printf("Layers:\n");
  foreach (ref i; layers.AsRange)
    printf(" * %s\n", i);
  printf("---\n");

  VkInstanceCreateInfo instanceCreateInfo = {
    sType: VkStructureType.instanceCreateInfo
  , pNext: null
  , flags: 0
  , pApplicationInfo: &self.settings.applicationInfo
  , enabledLayerCount: cast(uint)layers.length
  , ppEnabledLayerNames: layers.ptr
  , enabledExtensionCount: cast(uint)extensions.length
  , ppEnabledExtensionNames: extensions.ptr
  };

  // BELOW LEAKS 73,000 bytes of memory?
  vkCreateInstance(&instanceCreateInfo, null, &self.instance).EnforceVk;
}

void InitializeDebugMessenger(ref FrameworkContext self) {
  if (!self.settings.enableValidation) return;

  VkDebugUtilsMessengerCreateInfoEXT createInfo = {
    sType: VkStructureType.debugUtilsMessengerCreateInfoExt
  , messageSeverity:
      VkDebugUtilsMessageSeverityFlagEXT.verboseBitExt
    | VkDebugUtilsMessageSeverityFlagEXT.infoBitExt
    | VkDebugUtilsMessageSeverityFlagEXT.warningBitExt
    | VkDebugUtilsMessageSeverityFlagEXT.errorBitExt
  , messageType:
      VkDebugUtilsMessageTypeFlagEXT.generalBitExt
    | VkDebugUtilsMessageTypeFlagEXT.performanceBitExt
    | VkDebugUtilsMessageTypeFlagEXT.validationBitExt
  , pfnUserCallback: &DebugCallback
  , pUserData: null
  };

  auto vkCreateDebugUtilsMessengerEXT =
    cast(PFN_vkCreateDebugUtilsMessengerEXT)(
      vkGetInstanceProcAddr(self.instance, "vkCreateDebugUtilsMessengerEXT".ptr)
    );

  if (vkCreateDebugUtilsMessengerEXT == null) {
    printf("Could not create vkCreateDebugUtilsMessengerEXT\n");
  }
  vkCreateDebugUtilsMessengerEXT(
    self.instance
  , &createInfo
  , null
  , &self.debugMessenger
  ).EnforceVk;
}

void InitializePhysicalDevice(ref FrameworkContext self) {
  uint deviceLength;
  self.physicalDevice = GetPhysicalDevices(self.instance)[0];

  immutable VkQueueFlag[3] requestedQueueFlags = [
    VkQueueFlag.graphicsBit
  , VkQueueFlag.computeBit
  , VkQueueFlag.transferBit
  ];

  // Can't do [ ~0u, ~0u, ~0u ] as elements are adjacent..:
  // https://issues.dlang.org/show_bug.cgi?id=17778
  uint[3] queueIndices;
  queueIndices[0] = ~0u;
  queueIndices[1] = ~0u;
  queueIndices[2] = ~0u;

  neobc.Array!(VkQueueFamilyProperties) queueFamilyProperties =
    GetPhysicalDeviceQueueFamilyProperties(self.physicalDevice);

  // -- get queue family indices
  foreach (iter, const requestedQueueFlag; requestedQueueFlags) {
    uint* queueIdx = &queueIndices[iter];
    foreach (j; 0 .. queueFamilyProperties.length) {
      VkQueueFlags queueFlags = queueFamilyProperties[j].queueFlags;

      if (
           (requestedQueueFlag == VkQueueFlag.computeBit
        &&  queueFlags & VkQueueFlag.computeBit
        && !(queueFlags & VkQueueFlag.graphicsBit)
        ) || (
            requestedQueueFlag == VkQueueFlag.transferBit
        &&  queueFlags & VkQueueFlag.transferBit
        && !(queueFlags & VkQueueFlag.graphicsBit)
        && !(queueFlags & VkQueueFlag.computeBit)
        ) || (
          queueFlags & requestedQueueFlag
        )
      ) {
        *queueIdx = cast(uint)j;
        break;
      }
    }
  }

  self.graphicsQueueFamilyIndex = queueIndices[0];
  self.computeQueueFamilyIndex  = queueIndices[1];
  self.transferQueueFamilyIndex = queueIndices[2];

  // -- setup an array of device queue create information
  const float priority = 0.0f;

  VkDeviceQueueCreateInfo deviceQueueCreateInfo = {
    sType:            VkStructureType.deviceQueueCreateInfo
  , pNext:            null
  , flags:            0
  , queueFamilyIndex: self.graphicsQueueFamilyIndex
  , queueCount:       1
  , pQueuePriorities: &priority
  };

  auto deviceQueueCreateInfos = neobc.Array!(VkDeviceQueueCreateInfo)(1);
  deviceQueueCreateInfos[0] = deviceQueueCreateInfo;

  // -- device queue for compute if necessary
  if (self.computeQueueFamilyIndex != self.graphicsQueueFamilyIndex) {
    deviceQueueCreateInfo.queueFamilyIndex = self.computeQueueFamilyIndex;
    deviceQueueCreateInfos ~= deviceQueueCreateInfo;
  }

  // -- device queue for transfer if necessary
  if (self.transferQueueFamilyIndex != self.graphicsQueueFamilyIndex
   && self.transferQueueFamilyIndex != self.computeQueueFamilyIndex
  ) {
    deviceQueueCreateInfo.queueFamilyIndex = self.transferQueueFamilyIndex;
    deviceQueueCreateInfos ~= deviceQueueCreateInfo;
  }

  // -- get extensions
  auto deviceExtensions = neobc.Array!(const(char)*)(1);
  deviceExtensions[0] = VK_KHR_SWAPCHAIN_EXTENSION_NAME;

  // -- get physical device descriptor indexing features & enable all features
  //    gpu supports
  VkPhysicalDeviceDescriptorIndexingFeaturesEXT descriptorIndexing = {
    sType: VkStructureType.physicalDeviceDescriptorIndexingFeaturesExt
  , pNext: null
  };

  VkPhysicalDeviceFeatures2 features2 = {
    sType: VkStructureType.physicalDeviceFeatures2
  , pNext: &descriptorIndexing
  };

  self.physicalDevice.vkGetPhysicalDeviceFeatures2(&features2);

  // -- print out device extensions
  printf("DeviceExtensions:\n");
  foreach ( ref i; deviceExtensions.AsRange )
    printf(" * %s\n", i);
  printf("---\n");

  // -- create device
  VkDeviceCreateInfo deviceCreateInfo = {
    sType:                   VkStructureType.deviceCreateInfo
  , pNext:                   &features2
  , flags:                   0
  , queueCreateInfoCount:    cast(uint)(deviceQueueCreateInfos.length)
  , pQueueCreateInfos:       deviceQueueCreateInfos.ptr
  , enabledLayerCount:       0
  , ppEnabledLayerNames:     null
  , enabledExtensionCount:   cast(uint)(deviceExtensions.length)
  , ppEnabledExtensionNames: deviceExtensions.ptr
  , pEnabledFeatures:        null
  };

  vkCreateDevice(self.physicalDevice, &deviceCreateInfo, null, &self.device);

  vkGetDeviceQueue(
    self.device,
    self.graphicsQueueFamilyIndex,
    0, &self.graphicsQueue
  );

  vkGetDeviceQueue(
    self.device,
    self.computeQueueFamilyIndex,
    0, &self.computeQueue
  );

  vkGetDeviceQueue(
    self.device,
    self.transferQueueFamilyIndex,
    0, &self.transferQueue
  );
}

void InitializeSurface(ref FrameworkContext self) {
  // -- create surface
  glfwCreateWindowSurface(
    self.instance
  , self.window
  , null
  , &self.surface
  ).EnforceVk;

  // -- select best format for surface
  VkBool32 supportPresent = VK_FALSE;
  vkGetPhysicalDeviceSurfaceSupportKHR(
    self.physicalDevice
  , self.graphicsQueueFamilyIndex
  , self.surface
  , &supportPresent
  ).EnforceVk;
  supportPresent.EnforceAssert;

  neobc.Array!(VkSurfaceFormatKHR) surfaceFormats =
    GetSurfaceFormats(self.physicalDevice, self.surface);

  // Can support requested surface format
  if (surfaceFormats.length == 1
   && surfaceFormats[0].format == VkFormat.undefined
  ) {
    self.surfaceFormat.format = self.settings.surfaceFormat;
    self.surfaceFormat.colorSpace = surfaceFormats[0].colorSpace;
    return;
  }

  // find next best option
  foreach ( ref surfaceFormat; surfaceFormats.AsRange ) {
    if ( surfaceFormat.format == self.settings.surfaceFormat ) {
      self.surfaceFormat = surfaceFormat;
      return;
    }
  }

  // out of luck
  self.surfaceFormat = surfaceFormats[0];
}

void InitializeSwapchain(ref FrameworkContext self) {
  VkSwapchainKHR oldSwapchain = self.swapchain;

  VkSurfaceCapabilitiesKHR capabilities;
  vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
    self.physicalDevice
  , self.surface
  , &capabilities
  ).EnforceVk;

  VkSwapchainCreateInfoKHR info = {
    sType:                 VkStructureType.swapchainCreateInfoKhr
  , pNext:                 null
  , flags:                 0
  , surface:               self.surface
  , minImageCount:         capabilities.minImageCount
  , imageFormat:           self.surfaceFormat.format
  , imageColorSpace:       self.surfaceFormat.colorSpace
  , imageExtent:           VkExtent2D (800, 600)
  , imageArrayLayers:      1
  , imageUsage:            VkImageUsageFlag.colorAttachmentBit
                        // | VkImageUsageFlag.transferDstBit
  , imageSharingMode:      VkSharingMode.exclusive
  , queueFamilyIndexCount: 0
  , pQueueFamilyIndices:   null
  , preTransform:          VkSurfaceTransformFlagKHR.identityBitKhr
  , compositeAlpha:        VkCompositeAlphaFlagKHR.opaqueBitKhr
  , presentMode:           VkPresentModeKHR.immediateKhr
  , clipped:               VK_TRUE
  , oldSwapchain:          self.swapchain
  };

  // -- create swapchain
  vkCreateSwapchainKHR(self.device, &info, null, &self.swapchain).EnforceVk;

  if (oldSwapchain) {
    foreach (ref imageView; self.backbufferViews.AsRange) {
      vkDestroyImageView(self.device, imageView, null);
      imageView = null;
    }
    vkDestroySwapchainKHR(self.device, oldSwapchain, null);
  }

  // -- create image for each backbuffer
  self.backbuffers = GetSwapchainImagesKHR(self.device, self.swapchain);
}

void InitializeSwapchainImageViews(ref FrameworkContext self) {
  VkImageSubresourceRange subresourceRange = {
    aspectMask:     VkImageAspectFlag.colorBit
  , baseMipLevel:   0
  , levelCount:     1
  , baseArrayLayer: 0
  , layerCount:     1
  };

  VkImageViewCreateInfo info = {
    sType: VkStructureType.imageViewCreateInfo
  , pNext: null
  , flags: 0
  , image: null // set in iter
  , viewType: VkImageViewType.i2D
  , format: self.surfaceFormat.format
  , components:
      VkComponentMapping(
        VkComponentSwizzle.r
      , VkComponentSwizzle.g
      , VkComponentSwizzle.b
      , VkComponentSwizzle.a
      )
  , subresourceRange: subresourceRange
  };

  // resize
  self.backbufferViews = neobc.Array!(VkImageView)(self.backbuffers.length);

  // create image views, assign info.image for each image view
  foreach (it; 0 .. self.backbufferViews.length) {
    info.image = self.backbuffers[it];
    vkCreateImageView(self.device, &info, null, &self.backbufferViews[it])
      .EnforceVk;
  }
}

// void InitializeFramebuffers(ref FrameworkContext self) {
//   self.framebuffers.resize(self.backbuffers.size());

//   foreach (ref view; self.backbufferViews) {
//     VkFramebufferCreateInfo framebufferCreateInfo = {
//       sType: VkStructureType.framebufferCreateInfo
//     , flags: 0
//     , 
//     };
//   }
//   for (size_t i = 0; i < 
//   VkFramebufferCreate
// }

void InitializeSemaphores(ref FrameworkContext self) {
  VkSemaphoreCreateInfo info = {
    sType: VkStructureType.semaphoreCreateInfo
  , pNext: null
  , flags: 0
  };

  vkCreateSemaphore(self.device, &info, null, &self.semaphoreImageAcquired);
  vkCreateSemaphore(self.device, &info, null, &self.semaphoreRendersFinished);
}


void InitializeTransientCommandPool(ref FrameworkContext self) {

  { // -- create command pool
    VkCommandPoolCreateInfo info = {
      sType: VkStructureType.commandPoolCreateInfo
    , flags:
        VkCommandPoolCreateFlag.transientBit
      | VkCommandPoolCreateFlag.resetCommandBufferBit
    , queueFamilyIndex: self.graphicsQueueFamilyIndex
    };

    vkCreateCommandPool(self.device , &info, null, &self.transientCommandPool)
      .EnforceVk;
  }

  { // -- create command buffers
    VkCommandBufferAllocateInfo info = {
      sType: VkStructureType.commandBufferAllocateInfo
    , commandPool: self.transientCommandPool
    , level: VkCommandBufferLevel.primary
    , commandBufferCount: 1
    };

    vkAllocateCommandBuffers(self.device, &info, &self.transientCommandBuffer);
  }
}

struct FrameworkContext {
  GLFWwindow* window;
  VkInstance instance;
  ApplicationSettings settings;
  VkDebugUtilsMessengerEXT debugMessenger;

  VkPhysicalDevice physicalDevice;
  VkDevice device;

  uint computeQueueFamilyIndex;
  uint graphicsQueueFamilyIndex;
  uint transferQueueFamilyIndex;

  VkQueue computeQueue;
  VkQueue graphicsQueue;
  VkQueue transferQueue;
  VkQueue presentQueue;

  VkCommandPool transientCommandPool;
  VkCommandBuffer transientCommandBuffer;

  VkSwapchainKHR     swapchain;
  VkSurfaceFormatKHR surfaceFormat;
  VkSurfaceKHR       surface;

  VkPipelineCache pipelineCache;

  VkSemaphore semaphoreImageAcquired;
  VkSemaphore semaphoreRendersFinished;

  // neobc.Array!VkFramebuffer framebuffers;
  neobc.Array!VkImage       backbuffers;
  neobc.Array!VkImageView   backbufferViews;

  VkImage finalResolvedImage;

  static FrameworkContext Construct(ApplicationSettings settings) {
    FrameworkContext self;
    self.settings = settings;

    self.InitializeGlfw;
    self.InitializeInstance;
    self.InitializeDebugMessenger;
    self.InitializePhysicalDevice;
    self.InitializeSurface;
    self.InitializeSwapchain;
    self.InitializeSwapchainImageViews;
    self.InitializeSemaphores;
    self.InitializeTransientCommandPool;

    return self;
  }

  ~this() {
    if (settings.enableValidation) {
      auto func =
        cast(PFN_vkDestroyDebugUtilsMessengerEXT)
          vkGetInstanceProcAddr(
            this.instance,
            "vkDestroyDebugUtilsMessengerEXT"
          );

      if (func != null)
        func(this.instance, this.debugMessenger, null);
    }
    foreach (ref imageView; this.backbufferViews.AsRange) {
      vkDestroyImageView(this.device, imageView, null);
      imageView = null;
    }

    vkFreeCommandBuffers(
      this.device
    , this.transientCommandPool
    , 1, &this.transientCommandBuffer
    );
    vkDestroyCommandPool(this.device, this.transientCommandPool, null);
    vkDestroySemaphore(this.device, this.semaphoreImageAcquired, null);
    vkDestroySemaphore(this.device, this.semaphoreRendersFinished, null);
    vkDestroySwapchainKHR(this.device, this.swapchain, null);
    vkDestroyDevice(this.device, null);
    vkDestroyInstance(this.instance, null);
    glfwDestroyWindow(window);
    glfwTerminate();
  }

  bool ShouldWindowClose() {
    if (glfwWindowShouldClose(window)) return true;
    if (glfwGetKey(this.window, GLFW_KEY_Q) == GLFW_PRESS) return true;
    return false;
  }

  void PollEvents() {
    glfwPollEvents();
  }

  uint SwapFrame() {
    uint imageIndex;
    vkAcquireNextImageKHR(
      this.device
    , this.swapchain
    , ulong.max
    , this.semaphoreImageAcquired
    , null
    , &imageIndex
    );
    return imageIndex;
  }
};
