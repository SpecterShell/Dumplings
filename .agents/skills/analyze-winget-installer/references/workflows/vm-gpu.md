# Validate GPU-dependent applications

Some installers or applications reject a VM that lacks a compatible GPU, as observed with `DIAL.DIALux-evo`. When logs or the visible interface identify this blocker, consider an approved GPU-enabled validation VM before abandoning the test. Follow [VM validation](vm-validation.md) for isolation, silent-install checks, and checkpoint restoration. Never retry the executable on the host.

## Check the host and guest requirements

GPU partitioning shares a host GPU with a guest through a GPU-P adapter. Check the host OS, GPU, driver, guest OS, and application's required graphics API before changing the VM. Microsoft's [GPU partitioning guide](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/partition-assign-vm-gpu) describes the supported Windows Server 2025 setup, including host and guest drivers. Treat Windows 10/11 client GPU-PV recipes as platform-specific community setups rather than assuming that the server support matrix applies to them.

[Easy-GPU-PV](https://github.com/jamesstringer90/Easy-GPU-PV) provides Windows client setup and driver-copying examples. Review its prerequisites and scripts before using any part of them. Its full provisioning script creates a VM and disables checkpoints, so do not run it wholesale against the validation environment. A partition adapter alone does not install guest drivers or prove that OpenGL, DirectX, or Vulkan works for the target application.

Make hardware changes only with the user's approval. Run configuration commands in an elevated PowerShell 7.4+ shell on the Hyper-V host. Shut down the validation guest normally and verify that it is `Off`. Preserve the clean checkpoint and record the original GPU adapters, cache/MMIO settings, and host/guest driver versions through the [evidence workflow](evidence.md).

## Select a GPU explicitly

Enumerate partitionable GPUs and inspect the display devices. If no partitionable GPU appears, investigate host support and drivers rather than adding an arbitrary adapter:

```powershell
Import-Module Hyper-V -ErrorAction Stop
$PartitionableGPUs = @(Get-VMHostPartitionableGpu -ErrorAction Stop)
$PartitionableGPUs | Select-Object Name, ValidPartitionCounts
Get-PnpDevice -Class Display -PresentOnly | Select-Object FriendlyName, InstanceId, Status
```

Set `$VMName` to the selected validation VM and `$GpuInstancePath` to the chosen GPU's complete `Name` value. Correlate it with the host device and driver. Do not select the first match for a hardcoded vendor substring. The [Add-VMGpuPartitionAdapter reference](https://learn.microsoft.com/en-us/powershell/module/hyper-v/add-vmgpupartitionadapter) defines `InstancePath` as the `Name` returned by `Get-VMHostPartitionableGpu`.

This example adds one adapter to a powered-off VM that has none. If an adapter already exists, inspect and reuse the approved assignment instead of adding a duplicate:

```powershell
$VM = Get-VM -Name $VMName -ErrorAction Stop
if ($VM.State -ne 'Off') { throw 'Shut down the validation VM before changing its GPU configuration.' }
$SelectedGPU = @($PartitionableGPUs | Where-Object { $_.Name -eq $GpuInstancePath })
if ($SelectedGPU.Count -ne 1) { throw 'Select exactly one partitionable GPU by its complete instance path.' }
if (Get-VMGpuPartitionAdapter -VMName $VM.Name -ErrorAction Stop) { throw 'Inspect the existing GPU assignment before adding another adapter.' }
Add-VMGpuPartitionAdapter -VMName $VM.Name -InstancePath $SelectedGPU[0].Name -ErrorAction Stop
Get-VMGpuPartitionAdapter -VMName $VM.Name | Select-Object InstancePath, PartitionId
```

## Understand cache and MMIO settings

`GuestControlledCacheTypes` permits guest-controlled cache types. Microsoft's [graphics-device preparation guide](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/deploy/deploying-graphics-devices-using-dda#vm-preparation-for-graphics-devices) uses it to enable write-combining. `LowMemoryMappedIoSpace` reserves the 32-bit MMIO aperture, and `HighMemoryMappedIoSpace` reserves the aperture above 32 bits. These values describe address space in bytes, not assigned VRAM or guest RAM.

The linked Microsoft preparation recipe is for Discrete Device Assignment (DDA). Windows client GPU-PV recipes also use these settings, but their necessity and sizes depend on the hardware and driver. Choose values from the verified setup rather than copying fixed sizes from another machine. Set `$LowMmioBytes` and `$HighMmioBytes` explicitly before using this optional configuration:

```powershell
$VM = Get-VM -Name $VMName -ErrorAction Stop
if ($VM.State -ne 'Off') { throw 'Shut down the validation VM before changing cache or MMIO settings.' }
if ($LowMmioBytes -le 0 -or $HighMmioBytes -le 0) { throw 'Set the verified MMIO sizes in bytes before applying this configuration.' }
Set-VM -Name $VM.Name -GuestControlledCacheTypes $true -LowMemoryMappedIoSpace $LowMmioBytes -HighMemoryMappedIoSpace $HighMmioBytes -ErrorAction Stop
```

`LowMemoryMappedIoSpace` accepts a `UInt32`, and `HighMemoryMappedIoSpace` accepts a `UInt64`, as documented by [Set-VM](https://learn.microsoft.com/en-us/powershell/module/hyper-v/set-vm). Review the original values before applying the change. Do not use DDA commands to disable or dismount the host's GPU as a fallback for failed GPU-P configuration.

## Verify graphics inside the guest

Prepare compatible guest drivers using the GPU vendor's supported procedure or a reviewed client GPU-PV procedure. Client recipes may copy selected driver files from the host into the guest. Keep those files consistent with the host driver version after updates. Preserve a reusable clean GPU-enabled baseline once driver setup works, provided its restore procedure has been tested.

After starting the guest, inspect Device Manager and collect a focused report **inside the VM**:

```powershell
Get-CimInstance Win32_VideoController | Select-Object Name, PNPDeviceID, DriverVersion, Status
dxdiag.exe /t $GuestGpuReportPath
```

Set `$GuestGpuReportPath` to a guest evidence path. Verify the API and feature level required by the application, not just the presence of an adapter. DirectX diagnostics do not establish OpenGL or Vulkan support. Record the console, enhanced-session, or RDP context because remote sessions can expose different rendering behavior. Retry the application in the intended visible guest desktop and preserve its logs or GPU-error screenshot.

Separate an installer failure from a first-run graphics failure. Complete the usual silent-install, exit-code, installed-state, and first-run checks once graphics works. GPU preparation belongs in validation evidence and must not be invented as a WinGet package dependency. If the required API remains unavailable or the application rejects virtualization, stop that validation route and report the limitation.

## Preserve checkpoint recovery

Follow [Checkpoints with GPU partitions](vm-validation.md#checkpoints-with-gpu-partitions). Verify restoration before relying on the prepared VM. If recovery requires removing and reattaching the adapter, record its exact instance path and settings, shut down the guest, and restore only through the tested procedure. A failed restore stops validation. Use a separate GPU-enabled test VM when the normal validation VM cannot be restored reliably.
