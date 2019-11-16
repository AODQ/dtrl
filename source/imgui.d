module imgui;

import core.stdc.stdint;

public import
  dtoavkbindings.cimgui,
  dtoavkbindings.cimgui_glfw,
  dtoavkbindings.cimgui_vk;

import dtl.vkcontext;
import dtl.vkutil;
import dtoavkbindings.glfw;
import dtoavkbindings.vk;

import neobc.array;

struct CimguiInfo {
  GLFWwindow* window;
  ImGuiContext* context;
};

CimguiInfo cInfo;

nothrow static void ImguiCheckVkResult(VkResult err) {
  import core.stdc.stdio;

  if (err == 0)
    { return; }
}

VkCommandPool InitializeImGuiCommandPool(ref FrameworkContext fw)
{
  VkCommandPoolCreateInfo info = {
    sType: VkStructureType.commandPoolCreateInfo
  , flags: VkCommandPoolCreateFlag.resetCommandBufferBit
  , queueFamilyIndex: fw.graphicsQueueFamilyIndex
  };

  VkCommandPool commandPool;
  vkCreateCommandPool(
    fw.device
  , &info
  , null
  , &commandPool
  ).EnforceVk;

  return commandPool;
}

void InitializeImGuiCommandBuffers(
  ref FrameworkContext fw
, ref VkCommandPool commandPool
, ref neobc.Array!VkCommandBuffer commandBuffers
) {
  VkCommandBufferAllocateInfo info = {
    sType: VkStructureType.commandBufferAllocateInfo
  , commandPool: commandPool
  , level: VkCommandBufferLevel.primary
  , commandBufferCount: cast(uint)commandBuffers.length
  };

  vkAllocateCommandBuffers(fw.device , &info , commandBuffers.ptr);
}


VkRenderPass CreateImGuiRenderPass(ref FrameworkContext fw)
{
  VkAttachmentDescription attachment = {
    flags: 0 /* reserved */
  , format: fw.surfaceFormat.format
  , samples: VkSampleCountFlag.i1Bit
  , loadOp: VkAttachmentLoadOp.load // draw on top of framebuffer
  , storeOp: VkAttachmentStoreOp.store
  , stencilLoadOp: VkAttachmentLoadOp.dontCare
  , stencilStoreOp: VkAttachmentStoreOp.dontCare
  , initialLayout: VkImageLayout.colorAttachmentOptimal
  , finalLayout: VkImageLayout.presentSrcKhr
  };

  VkAttachmentReference colorAttachment = {
    attachment: 0
  , layout: VkImageLayout.colorAttachmentOptimal
  };

  VkSubpassDescription subpass = {
    pipelineBindPoint: VkPipelineBindPoint.graphics
  , colorAttachmentCount: 1
  , pColorAttachments: &colorAttachment
  };

  VkSubpassDependency dependency = {
    srcSubpass: VK_SUBPASS_EXTERNAL
  , dstSubpass: 0
  , srcStageMask: VkPipelineStageFlag.colorAttachmentOutputBit
  , dstStageMask: VkPipelineStageFlag.colorAttachmentOutputBit
  , srcAccessMask: 0
  , dstAccessMask: VkAccessFlag.colorAttachmentWriteBit
  };

  VkRenderPassCreateInfo info = {
    sType: VkStructureType.renderPassCreateInfo
  , attachmentCount: 1
  , pAttachments: &attachment
  , subpassCount: 1
  , pSubpasses: &subpass
  , dependencyCount: 1
  , pDependencies: &dependency
  };

  VkRenderPass renderpass;
  vkCreateRenderPass(fw.device, &info, null, &renderpass).EnforceVk;

  return renderpass;
}

void InitializeGlfwVulkanImgui(
  ref FrameworkContext fw
, ref VkRenderPass imguiRenderpass
, ref VkCommandPool commandPool
, ref VkCommandBuffer commandBuffer
, ref VkDescriptorPool descriptorPool
) {
  cInfo.context = igCreateContext(null);

  // -- most code here adapted from imgui's example_glfw_vulkan

  // -- initialize imgui
  ImGui_ImplGlfw_InitForVulkan(fw.window, true);
  ImGui_ImplVulkan_InitInfo initInfo = {
    Instance: fw.instance
  , PhysicalDevice: fw.physicalDevice
  , Device: fw.device
  , QueueFamily: fw.graphicsQueueFamilyIndex
  , Queue: fw.graphicsQueue
  , PipelineCache: fw.pipelineCache
  , DescriptorPool: descriptorPool
  , MinImageCount: 2
  , ImageCount: 2
  , MSAASamples: VkSampleCountFlag.i1Bit
  , Allocator: null
  , CheckVkResultFn: &ImguiCheckVkResult
  };
  ImGui_ImplVulkan_Init(&initInfo, imguiRenderpass);

  igStyleColorsDark(null);

  // upload fonts

  {
    vkResetCommandPool(fw.device, commandPool, 0).EnforceVk;
    VkCommandBufferBeginInfo beginInfo = {
      sType: VkStructureType.commandBufferBeginInfo
    , flags: VkCommandBufferUsageFlag.oneTimeSubmitBit
    };
    vkBeginCommandBuffer(commandBuffer, &beginInfo).EnforceVk;

    ImGui_ImplVulkan_CreateFontsTexture(commandBuffer);

    VkSubmitInfo endInfo = {
      sType: VkStructureType.submitInfo
    , commandBufferCount: 1
    , pCommandBuffers: &commandBuffer
    };
    vkEndCommandBuffer(commandBuffer).EnforceVk;
    vkQueueSubmit(fw.graphicsQueue, 1, &endInfo, null);

    vkDeviceWaitIdle(fw.device).EnforceVk;

    // TODO FIX ME
    // ImGui_ImplVulkan_DestroyFontUploadObjects();
  }
}
