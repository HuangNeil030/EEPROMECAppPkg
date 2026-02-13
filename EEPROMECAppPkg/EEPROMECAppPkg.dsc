## @file
#  EEPROMECAppPkg platform DSC
##

[Defines]
  PLATFORM_NAME                  = EEPROMECAppPkg
  PLATFORM_GUID                  = 0a33a6bd-0c7e-4e23-a4b5-ef3b3c7b5d2a
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION              = 0x0001001A
  OUTPUT_DIRECTORY               = Build/EEPROMECAppPkg
  SUPPORTED_ARCHITECTURES        = X64
  BUILD_TARGETS                  = DEBUG|RELEASE
  SKUID_IDENTIFIER               = DEFAULT

[BuildOptions]
  MSFT:DEBUG_VS2019_X64_CC_FLAGS = /GS- /sdl-
  MSFT:*_*_*_CC_FLAGS = /wd4819
  MSFT:*_*_*_CC_FLAGS = /utf-8
  
[Packages]
  MdePkg/MdePkg.dec
  MdeModulePkg/MdeModulePkg.dec
  EmulatorPkg/EmulatorPkg.dec
  ShellPkg/ShellPkg.dec
  EEPROMECAppPkg/EEPROMECAppPkg.dec
  
[Packages]
  MdePkg/MdePkg.dec
  MdeModulePkg/MdeModulePkg.dec
  EEPROMECAppPkg/EEPROMECAppPkg.dec

[LibraryClasses]
  DebugLib                      | MdePkg/Library/BaseDebugLibNull/BaseDebugLibNull.inf
  DebugPrintErrorLevelLib       | MdePkg/Library/BaseDebugPrintErrorLevelLib/BaseDebugPrintErrorLevelLib.inf
  RegisterFilterLib             | MdePkg/Library/RegisterFilterLibNull/RegisterFilterLibNull.inf
  PcdLib                        | MdePkg/Library/BasePcdLibNull/BasePcdLibNull.inf

  UefiLib                       | MdePkg/Library/UefiLib/UefiLib.inf
  UefiApplicationEntryPoint     | MdePkg/Library/UefiApplicationEntryPoint/UefiApplicationEntryPoint.inf
  UefiBootServicesTableLib      | MdePkg/Library/UefiBootServicesTableLib/UefiBootServicesTableLib.inf
  BaseLib                       | MdePkg/Library/BaseLib/BaseLib.inf
  BaseMemoryLib                 | MdePkg/Library/BaseMemoryLib/BaseMemoryLib.inf
  PrintLib                      | MdePkg/Library/BasePrintLib/BasePrintLib.inf
  IoLib                         | MdePkg/Library/BaseIoLibIntrinsic/BaseIoLibIntrinsic.inf
  StackCheckLib | MdePkg/Library/StackCheckLibNull/StackCheckLibNull.inf
  MemoryAllocationLib | MdePkg/Library/UefiMemoryAllocationLib/UefiMemoryAllocationLib.inf
  DevicePathLib | MdePkg/Library/UefiDevicePathLib/UefiDevicePathLib.inf
  UefiRuntimeServicesTableLib | MdePkg/Library/UefiRuntimeServicesTableLib/UefiRuntimeServicesTableLib.inf





[Components]
  EEPROMECAppPkg/Applications/EEPROMECApp/EEPROMECApp.inf
