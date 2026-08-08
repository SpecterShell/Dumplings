# VM-only dynamic validation workflow

Use this workflow only for facts static analysis cannot prove. Never execute an unknown installer on the host. The bundled scripts capture state but deliberately do not launch installers or applications.

## 1. Preserve the Windows environment and prepare Hyper-V

For local Windows validation, configure Codex to inherit the normal process environment while retaining its default filtering of variable names containing `KEY`, `SECRET`, or `TOKEN`:

```toml
[shell_environment_policy]
inherit = "all"
ignore_default_excludes = false
```

Restart Codex or start a new task after changing `config.toml`. Do not use `inherit = "core"` for this workflow: its Windows allowlist omits `WINDIR`, `COMPUTERNAME`, and the inherited `PSModulePath`. Without them, PowerShell Core cannot discover or natively load the inbox Hyper-V module, and `Get-VM` cannot infer the local host.

Verify the environment and explicitly load the inbox Hyper-V module through Windows PowerShell compatibility when running PowerShell Core under Codex:

```powershell
Get-Item Env:WINDIR, Env:COMPUTERNAME, Env:PSModulePath
$env:PSModulePath += ';C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
Import-Module Hyper-V -UseWindowsPowerShell -PassThru
Get-Command Get-VM, Copy-VMFile
```

If an existing task was started with `inherit = "core"`, repair that process before importing the module:

```powershell
$env:WINDIR = $env:SystemRoot
$env:COMPUTERNAME = [Environment]::MachineName
$env:PSModulePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules;$env:PSModulePath"

Import-Module Hyper-V -UseWindowsPowerShell -PassThru
Get-Command Get-VM, Copy-VMFile
```

Keep the repair and Hyper-V operation in the same Codex shell call because each call may start a fresh PowerShell process. Confirm that the VM is running, PowerShell Direct accepts the guest credential, and **Guest Service Interface** is enabled for the controller's small collector-script transfer.

Start from a clean checkpoint. Do not attach host submission directories as writable shared storage.

## 2. Capture the baseline

The host controller stages the Windows PowerShell 5.1-compatible guest collector and retrieves JSON through PowerShell Direct:

```powershell
$Tool = '.\.agents\skills\analyze-winget-installer\scripts\Invoke-WinGetVMInstalledState.ps1'
$Evidence = '.\Sandbox\Evidence\Publisher.Package\20260808T143000Z\vm'

& $Tool -Action Capture -VMName PackageValidation -Phase BeforeInstall `
  -UserName SpecterShell -AllowEmptyPassword -OutputDirectory $Evidence
```

Prefer `-Credential $Credential` for normal password-protected guests. `-AllowEmptyPassword` must always be explicit and never stores a password in the repository.

The snapshot records:

- HKLM 64-bit, HKLM 32-bit, and HKCU ARP entries, including hidden/incomplete entries.
- Direct `Software\Classes` protocols and extensions with ProgID commands and icons.
- `RegisteredApplications` capability mappings.
- Registry value types, hive, view, scope evidence, user SID, elevation, and capture phase.

The collector rejects a snapshot when all three evidence collections are empty. Do not continue from a zero-record JSON file. The script does not inventory Start menu entries, arbitrary AppData files, installed services, or the complete filesystem; collect those separately with focused guest commands when they matter.

## 3. Run the installer explicitly inside the VM

Download the installer from its official URL inside the guest and verify its SHA256 there. This avoids `Copy-VMFile` compatibility and source-path failures for large payloads; the host controller uses Guest Service only for the small collector script. The state scripts never download or execute the installer.

```powershell
$InstallerUrl = 'https://downloads.example.test/Installer.exe'
$InstallerPath = 'C:\DumplingsValidation\Installer.exe'
$ExpectedSha256 = '<SHA256>'
curl.exe --fail --location --retry 3 --retry-delay 2 --output $InstallerPath $InstallerUrl
if ($LASTEXITCODE -ne 0) { throw "curl failed with exit code $LASTEXITCODE" }
$ActualSha256 = (Get-FileHash -LiteralPath $InstallerPath -Algorithm SHA256).Hash
if ($ActualSha256 -cne $ExpectedSha256) { throw "Installer SHA256 mismatch: expected $ExpectedSha256, received $ActualSha256" }
```

If the official source requires headers, cookies, or a transport unavailable inside the guest, transfer a previously hash-verified host file through an explicitly tested channel and verify the hash again in the guest. Never rely on the filename or transfer success alone.

Before launching, inspect the actual file rather than trusting architecture labels on the download page. Use `Get-PEArchitectureInfo` for PE launchers and `Get-MsiInstallerInfo` or the MSI package template for MSI payloads. A page marked x64 can still serve an x86 launcher, and `win32` does not prove x86 installed binaries.

Capture the outer process result:

```powershell
$Process = Start-Process -FilePath C:\DumplingsValidation\Installer.exe `
  -ArgumentList @('<tested switches>') -Wait -PassThru

[pscustomobject]@{
  ExitCode = $Process.ExitCode
  Mode = '<interactive|silent|silentWithProgress|cancelled>'
}
```

Run cancellation, elevated/non-elevated behavior, user/machine scope, and quiet/passive variants as separate checkpoint-restored cases. For wrappers, record whether the outer process propagates nested MSI codes. Exit code `0` alone is not proof of installation.

For a GUI application that must run in the logged-on desktop after installation, create an interactive scheduled task with a start time in the future, invoke it immediately, and poll for the expected process. A past `/st` value can leave the task eligible but never started.

```powershell
$TaskName = 'Dumplings-FirstRun'
$ApplicationPath = 'C:\Program Files\Vendor\Application.exe'
$StartTime = (Get-Date).AddMinutes(2).ToString('HH:mm')
schtasks.exe /create /tn $TaskName /tr ('"{0}"' -f $ApplicationPath) /sc once /st $StartTime /ru $env:USERNAME /it /f
if ($LASTEXITCODE -ne 0) { throw "Failed to create scheduled task '$TaskName'." }
schtasks.exe /run /tn $TaskName
if ($LASTEXITCODE -ne 0) { throw "Failed to start scheduled task '$TaskName'." }
$Process = $null
for ($Attempt = 0; $Attempt -lt 30 -and -not $Process; $Attempt++) { $Process = Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($ApplicationPath)) -ErrorAction SilentlyContinue; if (-not $Process) { Start-Sleep -Seconds 1 } }
if (-not $Process) { throw 'The application process did not appear after scheduled-task launch.' }
```

Delete the task after collecting evidence. Add `/rl highest` only when the specific validation route requires an elevated first run; do not use it for ordinary user-context initialization.

### Reject blocking driver trust prompts

Stop the test when the installer stalls and Windows Security displays **Would you like to install this device software?** with **Install** and **Don't install** choices. The publisher trust checkbox shown by this dialog is additional driver-publisher consent, not an ordinary UAC elevation prompt. An installer that requires this choice cannot complete unattended on an ordinary WinGet target and is not currently acceptable for winget-pkgs.

Capture the dialog, displayed driver name and publisher, tested command line, launch elevation, elapsed time, and still-running process state. Then mark the validation as failed, skip manifest creation or submission for that installer, and restore the checkpoint. Do not click **Install**, select **Always trust software from ...**, import the publisher certificate into Trusted Publishers or Trusted Root Certification Authorities, pre-stage the driver with `pnputil`, or weaken driver-signing policy to make the test pass. Those actions add machine preparation that WinGet cannot express or reproduce during normal package installation.

This rejection applies only when driver trust consent blocks the tested unattended route. A signed driver that installs silently without this dialog can continue through validation. A normal UAC prompt is evaluated separately as elevation behavior. The [manual certificate-trust workaround discussion](https://www.reddit.com/r/Intune/comments/19378nd/hide_windows_security_for_unknown_driver_install/) is useful for identifying the cause, but it does not make the installer acceptable for winget-pkgs.

## 4. Capture after installation

```powershell
& $Tool -Action Capture -VMName PackageValidation -Phase AfterInstall `
  -UserName SpecterShell -AllowEmptyPassword -OutputDirectory $Evidence

& $Tool -Action Compare `
  -BeforePath "$Evidence\BeforeInstall.json" `
  -AfterPath "$Evidence\AfterInstall.json" `
  -OutputDirectory $Evidence
```

Review `VisibleARPChanges` first. Keep `HiddenARPChanges` to explain embedded MSI/custom EXE behavior. Confirm installed paths, executable architecture, services, drivers, and package scope independently; `WOW6432Node` does not determine installed architecture.

## 5. Capture first-run associations

Some applications register protocols and extensions only on first launch. Launch the application explicitly inside the VM, complete only unavoidable initialization, close it, then capture:

```powershell
& $Tool -Action Capture -VMName PackageValidation -Phase AfterFirstRun `
  -UserName SpecterShell -AllowEmptyPassword -OutputDirectory $Evidence

& $Tool -Action Compare `
  -BeforePath "$Evidence\AfterInstall.json" `
  -AfterPath "$Evidence\AfterFirstRun.json" `
  -OutputDirectory $Evidence
```

Accept only literal protocol/extension changes whose ProgID or capability command resolves to the installed application. Exclude `UserChoice`, recent-file, Explorer cache, and unrelated dependency registrations.

## 6. Decide manifest evidence

Read [Installed state](installed-state.md) before converting deltas into `AppsAndFeaturesEntries`, `Protocols`, or `FileExtensions`. Record detailed results through the [transient evidence workflow](evidence.md).

Also verify:

- Claimed `InstallModes` and complete switch replacements.
- Success, cancellation, failure, and reboot exit codes.
- `ElevationRequirement` using both launch contexts when relevant.
- Network endpoints, stable metadata, and payload hashes for download bootstrappers.
- Upgrade behavior by installing the prior version before the new version when required.

Restore the checkpoint after every independent route.

## Family-specific notes

Focused installer pages link here and list only additional checks. Typical examples are Burn chain exit-code forwarding, Advanced Installer hidden MSI entries, NSIS/Inno wrapper ownership, Qt IFW CLI behavior, and SFX command quoting.

## Stop conditions

Stop when the installer requires a response file, unavoidable user interaction, a blocking Windows Security driver-trust prompt, hardware, private credentials, account activation, email-delivered links, unofficial payloads, or session-bound URLs that cannot be reproduced. Do not weaken the VM boundary to continue.
