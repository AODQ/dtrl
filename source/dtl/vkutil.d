module dtl.vkutil;

import dtl.vkcontext;
import dtoavkbindings.vk;

static import neobc;

void EnforceVk(
  string PF = __PRETTY_FUNCTION__
, string FP = __FILE_FULL_PATH__
, int    LC = __LINE__
)(VkResult status) {
  if (status != VkResult.success) {
    import core.stdc.stdlib;
    import core.stdc.signal;
    import core.stdc.stdio;
    "assert failed: %s: %s ; %d\n".printf(FP.ptr, PF.ptr, LC);
    raise(SIGABRT);
    exit(-1);
  }
}

neobc.Array!(ArrayType) GetVkArray(
  string fnName
, bool hasEnforce
, ArrayType
, FnParams...
)(ref FnParams params) {
  uint arrayLength;
  mixin(
    (hasEnforce?`EnforceVk(`:`(`)
  ~ fnName
  ~ `(params, &arrayLength, null));`
  );
  auto array = neobc.Array!(ArrayType)(arrayLength);
  mixin(
    (hasEnforce?`EnforceVk(`:`(`)
  ~ fnName
  ~ `(params, &arrayLength, array.ptr));`
  );

  return array;
}

alias GetPhysicalDevices =
  GetVkArray!("vkEnumeratePhysicalDevices", true, VkPhysicalDevice, VkInstance);

alias GetPhysicalDeviceQueueFamilyProperties =
  GetVkArray!(
    "vkGetPhysicalDeviceQueueFamilyProperties"
  , false
  , VkQueueFamilyProperties
  , VkPhysicalDevice
  );

alias GetSwapchainImagesKHR =
  GetVkArray!(
    "vkGetSwapchainImagesKHR"
  , false
  , VkImage
  , VkDevice
  , VkSwapchainKHR
  );

alias GetSurfaceFormats =
  GetVkArray!(
    "vkGetPhysicalDeviceSurfaceFormatsKHR"
  , false
  , VkSurfaceFormatKHR
  , VkPhysicalDevice
  , VkSurfaceKHR
  );

VkShaderModule CreateShaderModule(ByteArray)(
  ref FrameworkContext self
, ByteArray byteCode
) {
  VkShaderModuleCreateInfo createInfo = {
    sType: VkStructureType.shaderModuleCreateInfo
  , codeSize: byteCode.length
  , pCode: cast(const(uint)*)byteCode.ptr
  };

  VkShaderModule shaderModule;
  vkCreateShaderModule(self.device, &createInfo, null,  &shaderModule)
    .EnforceVk;
  return shaderModule;
}

struct ShaderInfo {
  string filename;
  VkShaderStageFlag stage;
}
