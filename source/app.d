import core.stdc.stdio;

import imgui;
import dtoavkbindings.glfw : glfwGetTime;
import dtoavkbindings.vk;
import core.stdc.stdlib, core.stdc.string;
static import neobc;
static import signalhandler;
static import dtl;
import dtl.vkutil;

////////////////////////////////////////////////////////////////////////////////
struct RenderPass
{
  VkDevice device;
  VkRenderPass renderPass;

  ~this() {
    if (renderPass)
      { vkDestroyRenderPass(device, renderPass, null); }
  }
};

////////////////////////////////////////////////////////////////////////////////
struct GraphicsPipeline
{
  VkDevice device;
  VkRenderPass renderPass;
  VkPipelineLayout pipelineLayout = null;
  VkPipeline pipeline;

  ~this() {
    if (pipelineLayout)
      { vkDestroyPipelineLayout(device, pipelineLayout, null); }
    if (pipeline)
      { vkDestroyPipeline(device, pipeline, null); }
  }
}

////////////////////////////////////////////////////////////////////////////////
RenderPass CreateRenderPass(
  ref dtl.FrameworkContext frameworkContext
) {
  RenderPass renderPass;
  renderPass.device = frameworkContext.device;

  // -- create renderpass
  VkAttachmentDescription colorAttachment = {
    flags: 0 /* reserved */
  , format: frameworkContext.surfaceFormat.format
  , samples: VkSampleCountFlag.i1Bit
  , loadOp: VkAttachmentLoadOp.clear
  , storeOp: VkAttachmentStoreOp.store
  , stencilLoadOp: VkAttachmentLoadOp.dontCare
  , stencilStoreOp: VkAttachmentStoreOp.dontCare
  , initialLayout: VkImageLayout.undefined
  , finalLayout: VkImageLayout.colorAttachmentOptimal // output for imgui
  };

  VkAttachmentReference colorAttachmentRef = {
    attachment: 0
  , layout: VkImageLayout.colorAttachmentOptimal
  };

  VkSubpassDescription subpass = {
    pipelineBindPoint: VkPipelineBindPoint.graphics
  , inputAttachmentCount: 0
  , pInputAttachments: null
  , colorAttachmentCount: 1
  , pColorAttachments: &colorAttachmentRef
  , pResolveAttachments: null
  , pDepthStencilAttachment: null
  , preserveAttachmentCount: 0
  , pPreserveAttachments: null
  };

  VkSubpassDependency dependency = {
    srcSubpass: VK_SUBPASS_EXTERNAL
  , dstSubpass: 0
  , srcStageMask: VkPipelineStageFlag.colorAttachmentOutputBit
  , srcAccessMask: 0
  , dstStageMask: VkPipelineStageFlag.colorAttachmentOutputBit
  , dstAccessMask:
      VkAccessFlag.colorAttachmentReadBit
    | VkAccessFlag.colorAttachmentWriteBit
  };

  VkRenderPassCreateInfo renderPassInfo = {
    sType: VkStructureType.renderPassCreateInfo
  , attachmentCount: 1
  , pAttachments: &colorAttachment
  , subpassCount: 1
  , pSubpasses: &subpass
  , dependencyCount: 1
  , pDependencies: &dependency
  };

  vkCreateRenderPass(
    frameworkContext.device
  , &renderPassInfo
  , null
  , &renderPass.renderPass
  ).EnforceVk;

  return renderPass;
}

////////////////////////////////////////////////////////////////////////////////
GraphicsPipeline CreateGraphicsPipeline(
  ref dtl.FrameworkContext frameworkContext
, ref RenderPass renderPass
) {
  GraphicsPipeline graphicsPipeline;
  graphicsPipeline.device = frameworkContext.device;

  import neobc.file;
  auto shaderInfos = neobc.Array!(dtl.ShaderInfo)(
    dtl.ShaderInfo("data/triangle.vert.spv", VkShaderStageFlag.vertexBit)
  , dtl.ShaderInfo("data/triangle.frag.spv", VkShaderStageFlag.fragmentBit)
  );

  // -- create shader modules
  neobc.Array!VkShaderModule shaderModules;

  foreach (ref info; shaderInfos.AsRange) {
    shaderModules ~=
      frameworkContext.CreateShaderModule(neobc.ReadFile(info.filename));
  }

  scope (exit) {
    foreach (ref shaderModule; shaderModules.AsRange) {
      vkDestroyShaderModule(frameworkContext.device, shaderModule, null);
    }
    shaderModules.Clear();
  }

  // -- create shader pipelines
  neobc.Array!VkPipelineShaderStageCreateInfo shaderStageInfos;

  foreach (i; 0 .. shaderInfos.length) {
    VkPipelineShaderStageCreateInfo shaderStageInfo = {
      sType: VkStructureType.pipelineShaderStageCreateInfo
    , stage: shaderInfos[i].stage
    , module_: shaderModules[i]
    , pName: "main"
    };

    shaderStageInfos ~= shaderStageInfo;
  }

  // -- create pipeline vertex input state
  VkPipelineVertexInputStateCreateInfo vertexInputState = {
    sType: VkStructureType.pipelineVertexInputStateCreateInfo
  , vertexBindingDescriptionCount: 0
  , pVertexBindingDescriptions: null
  , vertexAttributeDescriptionCount: 0
  , pVertexAttributeDescriptions: null
  };

  VkPipelineInputAssemblyStateCreateInfo inputAssemblyState = {
    sType: VkStructureType.pipelineInputAssemblyStateCreateInfo
  , topology: VkPrimitiveTopology.triangleList
  , primitiveRestartEnable: VK_FALSE
  };

  // -- viewport / scissors
  VkViewport viewport = {
    x: 0.0f, y: 0.0f
  , width:  800.0f
  , height: 600.0f
  , minDepth: 0.0f, maxDepth: 1.0f
  };

  VkRect2D scissor = {
    offset: VkOffset2D(0, 0)
  , extent: VkExtent2D(800, 600)
  };

  VkPipelineViewportStateCreateInfo viewportState = {
    sType: VkStructureType.pipelineViewportStateCreateInfo
  , viewportCount: 1
  , pViewports: &viewport
  , scissorCount: 1
  , pScissors: &scissor
  };

  VkPipelineRasterizationStateCreateInfo rasterizer = {
    sType: VkStructureType.pipelineRasterizationStateCreateInfo
  , depthClampEnable: VK_FALSE
  , rasterizerDiscardEnable: VK_FALSE
  , polygonMode: VkPolygonMode.fill
  , cullMode: VkCullModeFlag.none
  , frontFace: VkFrontFace.clockwise
  , depthBiasEnable: VK_FALSE
  , depthBiasConstantFactor: 0.0f
  , depthBiasClamp: 0.0f
  , depthBiasSlopeFactor: 0.0f
  , lineWidth: 1.0f
  };

  VkPipelineMultisampleStateCreateInfo multisampleState = {
    sType: VkStructureType.pipelineMultisampleStateCreateInfo
  , flags: 0 /* reserved */
  , rasterizationSamples: VkSampleCountFlag.i1Bit
  , minSampleShading: 1.0f
  , pSampleMask: null
  , alphaToCoverageEnable: VK_FALSE
  , alphaToOneEnable: VK_FALSE
  };

  VkPipelineColorBlendAttachmentState colorBlendAttachment = {
    blendEnable: VK_FALSE
  , srcColorBlendFactor: VkBlendFactor.one
  , dstColorBlendFactor: VkBlendFactor.zero
  , colorBlendOp: VkBlendOp.add
  , srcAlphaBlendFactor: VkBlendFactor.one
  , dstAlphaBlendFactor: VkBlendFactor.zero
  , alphaBlendOp: VkBlendOp.add
  , colorWriteMask:
      VkColorComponentFlag.rBit
    | VkColorComponentFlag.gBit
    | VkColorComponentFlag.bBit
    | VkColorComponentFlag.aBit
  };

  VkPipelineColorBlendStateCreateInfo colorBlendState = {
    sType: VkStructureType.pipelineColorBlendStateCreateInfo
  , logicOpEnable: VK_FALSE
  , logicOp: VkLogicOp.copy
  , attachmentCount: 1
  , pAttachments: &colorBlendAttachment
  // , blendConstants // 0.0f
  };

  VkPipelineLayoutCreateInfo pipelineLayoutInfo = {
    sType: VkStructureType.pipelineLayoutCreateInfo
  , flags: 0 /* reserved */
  , setLayoutCount: 0
  , pSetLayouts: null
  , pushConstantRangeCount: 0
  , pPushConstantRanges: null
  };

  vkCreatePipelineLayout(
    frameworkContext.device
  , &pipelineLayoutInfo
  , null
  , &graphicsPipeline.pipelineLayout
  ).EnforceVk;

  VkGraphicsPipelineCreateInfo pipelineInfo = {
    sType: VkStructureType.graphicsPipelineCreateInfo
   , stageCount: 2
   , pStages: shaderStageInfos.ptr
   , pVertexInputState: &vertexInputState
   , pInputAssemblyState: &inputAssemblyState
   , pTessellationState: null
   , pViewportState: &viewportState
   , pRasterizationState: &rasterizer
   , pMultisampleState: &multisampleState
   , pDepthStencilState: null
   , pColorBlendState: &colorBlendState
   , pDynamicState: null
   , layout: graphicsPipeline.pipelineLayout
   , renderPass: renderPass.renderPass
  };

  vkCreateGraphicsPipelines(
    frameworkContext.device
  , null
  , 1
  , &pipelineInfo
  , null
  , &graphicsPipeline.pipeline
  ).EnforceVk;

  return graphicsPipeline;
}

////////////////////////////////////////////////////////////////////////////////
void main(string[] args) {
  VkApplicationInfo applicationInfo = {
    sType: VkStructureType.applicationInfo
  , pNext: null
  , pApplicationName: "dtrl".ptr
  , applicationVersion: VK_MAKE_VERSION(0, 0, 1)
  , pEngineName: "dtrl".ptr
  , engineVersion: VK_MAKE_VERSION(0, 0, 1)
  , apiVersion: VK_API_VERSION_1_1
  };

  dtl.ApplicationSettings settings = {
    applicationInfo: applicationInfo
  , name: "dtrl"
  , windowResolutionX: 800
  , windowResolutionY: 600
  , surfaceFormat: VkFormat.r8g8b8Unorm
  , enableValidation: true
  , enableVsync: true
  };

  // framework context ---------------------------------------------------------
  auto frameworkContext = dtl.FrameworkContext.Construct(settings);

  // renderpass / pipeline -----------------------------------------------------
  auto renderPass = CreateRenderPass(frameworkContext);
  auto pipeline = CreateGraphicsPipeline(frameworkContext, renderPass);


  // command pool --------------------------------------------------------------
  VkCommandPool commandPool;
  {
    VkCommandPoolCreateInfo commandPoolCreateInfo = {
      sType: VkStructureType.commandPoolCreateInfo
    , flags: 0
    , queueFamilyIndex: frameworkContext.graphicsQueueFamilyIndex
    };

    vkCreateCommandPool(
      frameworkContext.device
    , &commandPoolCreateInfo
    , null
    , &commandPool
    ).EnforceVk;
  }
  scope (exit)
    { vkDestroyCommandPool(frameworkContext.device, commandPool, null); }

  // framebuffer ---------------------------------------------------------------
  neobc.Array!VkFramebuffer framebuffers;
  framebuffers.Resize(frameworkContext.backbufferViews.length());
  {
    foreach (i; 0 .. frameworkContext.backbufferViews.length()) {
      auto attachments = neobc.Array!VkImageView(1);
      attachments[0] = frameworkContext.backbufferViews[i];

      VkFramebufferCreateInfo framebufferCreateInfo = {
        sType: VkStructureType.framebufferCreateInfo
      , flags: 0
      , renderPass: renderPass.renderPass
      , attachmentCount: cast(uint)attachments.length
      , pAttachments: attachments.ptr
      , width: 800
      , height: 600
      , layers: 1
      };

      vkCreateFramebuffer(
        frameworkContext.device
      , &framebufferCreateInfo
      , null
      , framebuffers.ptr + i
      ).EnforceVk;
    }
  }
  scope (exit) {
    foreach (ref framebuffer; framebuffers.AsRange)
      { vkDestroyFramebuffer(frameworkContext.device, framebuffer, null); }
  }

  // command buffers -----------------------------------------------------------
  neobc.Array!VkCommandBuffer commandBuffers;
  commandBuffers.Resize(framebuffers.length);
  {
    VkCommandBufferAllocateInfo commandBufferAllocateInfo = {
      sType: VkStructureType.commandBufferAllocateInfo
    , commandPool: commandPool
    , level: VkCommandBufferLevel.primary
    , commandBufferCount: cast(uint)commandBuffers.length
    };

    vkAllocateCommandBuffers(
      frameworkContext.device
    , &commandBufferAllocateInfo
    , commandBuffers.ptr
    );
  }
  scope(exit) {
    printf("freeing command buffers\n");
    vkFreeCommandBuffers(
      frameworkContext.device
    , commandPool
    , cast(uint)commandBuffers.length
    , commandBuffers.ptr
    );
  }


  // renderpass start ----------------------------------------------------------
  printf("Creating %lu command buffers\n", commandBuffers.length);
  foreach (it; 0 .. commandBuffers.length) {

    VkCommandBufferBeginInfo beginInfo = {
      sType: VkStructureType.commandBufferBeginInfo
    , flags: 0
    , pInheritanceInfo: null
    };

    vkBeginCommandBuffer(commandBuffers[it], &beginInfo).EnforceVk;

    VkClearColorValue clearColorValue = {
      float32: [0.0f, 0.0f, 0.0f, 0.0f]
    };
    VkClearValue clearColor = {
      color: VkClearColorValue([0.0f, 0.0f, 0.0f, 0.0f])
    };
    VkRenderPassBeginInfo renderPassBeginInfo = {
      sType: VkStructureType.renderPassBeginInfo
    , renderPass: renderPass.renderPass
    , framebuffer: framebuffers[it]
    , renderArea: VkRect2D(VkOffset2D(0, 0), VkExtent2D(800, 600))
    , clearValueCount: 1
    , pClearValues: &clearColor
    };

    vkCmdBeginRenderPass(
      commandBuffers[it]
    , &renderPassBeginInfo
    , VkSubpassContents.inline
    );

    vkCmdBindPipeline(
      commandBuffers[it]
    , VkPipelineBindPoint.graphics
    , pipeline.pipeline
    );

    vkCmdDraw(commandBuffers[it], 3, 1, 0, 0);

    vkCmdEndRenderPass(commandBuffers[it]);

    vkEndCommandBuffer(commandBuffers[it]).EnforceVk;
  }

  // imgui initialization ------------------------------------------------------

  VkCommandPool imguiCommandPool;
  neobc.Array!VkCommandBuffer imguiCommandBuffers;
  VkRenderPass imguiRenderpass;
  neobc.Array!VkFramebuffer imguiFramebuffers;

  imguiRenderpass = CreateImGuiRenderPass(frameworkContext);
  imguiCommandPool = InitializeImGuiCommandPool(frameworkContext);
  imguiCommandBuffers.Resize(frameworkContext.backbufferViews.length());
  InitializeImGuiCommandBuffers(
    frameworkContext
  , imguiCommandPool
  , imguiCommandBuffers
  );

  scope(exit) {
    printf("freeing imgui command buffers\n");
    vkFreeCommandBuffers(
      frameworkContext.device
    , imguiCommandPool
    , cast(uint)imguiCommandBuffers.length
    , imguiCommandBuffers.ptr
    );
    printf("freeing imgui command pool\n");
    vkDestroyCommandPool(
      frameworkContext.device
    , imguiCommandPool
    , null
    );

    vkDestroyRenderPass(frameworkContext.device, imguiRenderpass, null);
  }


  imguiFramebuffers.Resize(frameworkContext.backbufferViews.length());
  foreach (i; 0 .. frameworkContext.backbufferViews.length()) {
    auto attachments = neobc.Array!VkImageView(1);
    attachments[0] = frameworkContext.backbufferViews[i];

    VkFramebufferCreateInfo info = {
      sType: VkStructureType.framebufferCreateInfo
    , flags: 0
    , renderPass: imguiRenderpass
    , attachmentCount: cast(uint)attachments.length
    , pAttachments: attachments.ptr
    , width: 800
    , height: 600
    , layers: 1
    };

    vkCreateFramebuffer(
      frameworkContext.device
    , &info
    , null
    , imguiFramebuffers.ptr + i
    ).EnforceVk;
  }

  scope (exit) {
    foreach (ref fb; imguiFramebuffers.AsRange)
      vkDestroyFramebuffer(frameworkContext.device, fb, null);
  }

  VkDescriptorPool descriptorPool;
  { // -- create descriptor pool
    auto poolSizes = neobc.Array!VkDescriptorPoolSize(
      VkDescriptorPoolSize(VkDescriptorType.sampler, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.combinedImageSampler, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.sampledImage, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.storageImage, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.uniformTexelBuffer, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.storageTexelBuffer, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.uniformBufferDynamic, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.storageBufferDynamic, 1000)
    , VkDescriptorPoolSize(VkDescriptorType.inputAttachment, 1000)
    );

    VkDescriptorPoolCreateInfo poolInfo = {
      sType: VkStructureType.descriptorPoolCreateInfo
    , flags: VkDescriptorPoolCreateFlag.freeDescriptorSetBit
    , maxSets: cast(uint)(1000 * poolSizes.length)
    , poolSizeCount: cast(uint)poolSizes.length
    , pPoolSizes: poolSizes.ptr
    };

    vkCreateDescriptorPool(
      frameworkContext.device
    , &poolInfo
    , null
    , &descriptorPool
    ).EnforceVk;
  }

  scope (exit) {
    vkDestroyDescriptorPool(frameworkContext.device, descriptorPool, null);
  }

  InitializeGlfwVulkanImgui(
    frameworkContext
  , imguiRenderpass
  , imguiCommandPool
  , imguiCommandBuffers[0]
  , descriptorPool
  );

////////////////////////////////////////////////////////////////////////////////


  // VkImage resolvedImage;
  // VkDeviceMemory resolvedImageMemory;
  // {
  //   VkImageCreateInfo imageInfo = {
  //     sType: VkStructureType.imageCreateInfo
  //   , format: VkFormat.r8g8b8a8Unorm
  //   , tiling: VkImageTiling.optimal
  //   , imageType: VkImageType.i2D
  //   , extent: { 800, 600, 1 }
  //   , mipLevels: 1
  //   , arrayLayers: 1
  //   , initialLayout: VkImageLayout.undefined
  //   , usage: VkImageUsageFlag.transferDstBit | VkImageUsageFlag.sampledBit
  //   , sharingMode: VkSharingMode.exclusive
  //   , samples: VkSampleCountFlag.i1Bit
  //   , flags: 0
  //   };

  //   vkCreateImage(
  //     frameworkContext.device
  //   , &imageInfo
  //   , null
  //   , &resolvedImage
  //   ).EnforceVk;
  //   scope (exit) vkDestroyImage(frameworkContext.device, resolvedImage, null);

  //   VkMemoryRequirements memoryRequirements;
  //   vkGetImageMemoryRequirements(
  //     frameworkContext.device
  //   , resolvedImage
  //   , &memoryRequirements
  //   );

  //   VkMemoryAllocateInfo memoryAllocateInfo = {
  //     sType: VkStructureType.memoryAllocateInfo
  //   , allocationSize: memoryRequirements.size
  //   , memoryTypeIndex:
  //       frameworkContext.FindMemoryType(
  //         memoryRequirements.memoryTypeBits
  //       , VkMemoryPropertyFlag.deviceLocalBit
  //       )
  //   };

  //   vkAllocateMemory(
  //     frameworkContext.device
  //   , &memoryAllocateInfo
  //   , null
  //   , &resolvedImageMemory
  //   );
  // }

  VkSemaphore semaphoreMainRenderFinished;
  {
    VkSemaphoreCreateInfo info = {
      sType: VkStructureType.semaphoreCreateInfo
    , pNext: null
    , flags: 0
    };
    vkCreateSemaphore(
      frameworkContext.device
    , &info
    , null
    , &semaphoreMainRenderFinished
    );
  }

  scope(exit) {
    vkDestroySemaphore(
      frameworkContext.device
    , semaphoreMainRenderFinished
    , null
    );
  }

  float lastFrameTime = glfwGetTime(), currentFrameTime = glfwGetTime();
  while (!frameworkContext.ShouldWindowClose()) {
    frameworkContext.PollEvents;
    auto imageIndex = frameworkContext.SwapFrame;

    auto waitStages = neobc.Array!VkPipelineStageFlags(1);
    waitStages[0] = VkPipelineStageFlag.colorAttachmentOutputBit;

    VkSubmitInfo submitInfo = {
      sType: VkStructureType.submitInfo
    , waitSemaphoreCount: 1
    , pWaitSemaphores: &frameworkContext.semaphoreImageAcquired
    , pWaitDstStageMask: waitStages.ptr
    , commandBufferCount: 1
    , pCommandBuffers: &commandBuffers[imageIndex]
    , signalSemaphoreCount: 1
    , pSignalSemaphores: &semaphoreMainRenderFinished
    };

    vkQueueSubmit(
      frameworkContext.graphicsQueue
    , 1, &submitInfo
    , null
    ).EnforceVk;

    { // -- imgui
      ImGui_ImplVulkan_NewFrame;
      ImGui_ImplGlfw_NewFrame;

      igNewFrame;

      bool open = true;
      igShowDemoWindow(&open);

      //   igText(
      //     "Framerate: %.3f ms/frame (%d FPS)",
      //     (currentFrameTime - lastFrameTime)*1000.0f,
      //     cast(int)(1.0f/(currentFrameTime - lastFrameTime))
      //   );

      igRender;

      { // -- setup command buffer
        vkResetCommandPool(frameworkContext.device, imguiCommandPool, 0)
          .EnforceVk;

        {
          VkCommandBufferBeginInfo info = {
            sType: VkStructureType.commandBufferBeginInfo
          , flags: VkCommandBufferUsageFlag.oneTimeSubmitBit
          };

          vkBeginCommandBuffer(imguiCommandBuffers[imageIndex], &info)
            .EnforceVk;
        }

        {
          VkClearValue clearColor = {
            color: VkClearColorValue([0.0f, 0.0f, 0.0f, 0.0f])
          };
          VkRenderPassBeginInfo info = {
            sType: VkStructureType.renderPassBeginInfo
          , renderPass: imguiRenderpass
          , framebuffer: imguiFramebuffers[imageIndex]
          , renderArea: VkRect2D(VkOffset2D(0, 0), VkExtent2D(800, 600))
          , clearValueCount: 1
          , pClearValues: &clearColor
          };
          vkCmdBeginRenderPass(
            imguiCommandBuffers[imageIndex]
          , &info
          , VkSubpassContents.inline
          );

          ImGui_ImplVulkan_RenderDrawData(
            igGetDrawData()
          , imguiCommandBuffers[imageIndex]
          );

          vkCmdEndRenderPass(imguiCommandBuffers[imageIndex]);
          vkEndCommandBuffer(imguiCommandBuffers[imageIndex]).EnforceVk;
        }
      }

      auto imguiWaitStages = neobc.Array!VkPipelineStageFlags(1);
      imguiWaitStages[0] = VkPipelineStageFlag.colorAttachmentOutputBit;

      VkSubmitInfo imguiSubmitInfo = {
        sType: VkStructureType.submitInfo
      , waitSemaphoreCount: 1
      , pWaitSemaphores: &semaphoreMainRenderFinished
      , pWaitDstStageMask: waitStages.ptr
      , commandBufferCount: 1
      , pCommandBuffers: &imguiCommandBuffers[imageIndex]
      , signalSemaphoreCount: 1
      , pSignalSemaphores: &frameworkContext.semaphoreRendersFinished
      };

      vkQueueSubmit(
        frameworkContext.graphicsQueue
        , 1, &imguiSubmitInfo, null
      ).EnforceVk;
    }

    VkPresentInfoKHR presentInfo = {
      sType: VkStructureType.presentInfoKhr
    , waitSemaphoreCount: 1
    , pWaitSemaphores: &frameworkContext.semaphoreRendersFinished
    , swapchainCount: 1
    , pSwapchains: &frameworkContext.swapchain
    , pImageIndices: &imageIndex
    , pResults: null
    };
    vkQueuePresentKHR(frameworkContext.graphicsQueue, &presentInfo);

    vkQueueWaitIdle(frameworkContext.graphicsQueue);
  }

  vkDeviceWaitIdle(frameworkContext.device);


  printf("Shutting imgui vulkan down\n");
  ImGui_ImplVulkan_Shutdown();
  printf("Shutting imgui glfw down\n");
  ImGui_ImplGlfw_Shutdown();
  printf("destroying imgui context\n");
  igDestroyContext(igGetCurrentContext());
  // vkFreeMemory(frameworkContext.device, resolvedImageMemory, null);

  printf("-- Closing --\n");
}
