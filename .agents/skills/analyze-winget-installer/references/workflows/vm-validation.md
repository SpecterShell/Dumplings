# VM-only dynamic validation workflow

Complete this workflow before treating any new or modified installer entry as submission-ready. Validate every behaviorally distinct artifact, switch set, scope, architecture, locale, elevation route, or nested-payload route represented by the manifest. Static analysis determines what to test but cannot prove that unattended installation completes without a blocker. Never execute an unknown installer on the host. The bundled scripts capture state but do not launch installers or applications.

Stop validation immediately and warn the user if host or guest security software flags an executable as a virus or malware. Follow [Stop on malware alerts](installer-analysis.md#stop-on-malware-alerts). Do not bypass or disable protection to complete the test.

Run the host controller and Hyper-V commands in PowerShell 7.4 or later (`pwsh`). `Invoke-WinGetVMInstalledState.ps1` enforces this requirement and imports the inbox Hyper-V module natively. Only the staged guest collector, `Get-WinGetVMInstalledState.ps1`, is designed for Windows PowerShell 5.1.

## 1. Preserve the Windows environment and prepare Hyper-V

Load the inbox Hyper-V module directly in PowerShell Core. Do not use the Windows PowerShell compatibility session or modify `PSModulePath` when the module is already discoverable:

```powershell
Import-Module Hyper-V -PassThru
Get-Command Get-VM, Copy-VMFile
```

If the direct import fails, verify that the Hyper-V PowerShell feature is installed and that the process inherited the normal Windows environment before changing module paths. Confirm that the VM is running, PowerShell Direct accepts the guest credential, and **Guest Service Interface** is enabled for the controller's small collector-script transfer.

PowerShell Direct runs commands in a non-interactive guest session that is separate from the signed-in user's visible desktop. A GUI process started through `Invoke-Command -VMName` can run without appearing in the VM console. Use PowerShell Direct for staging, state capture, and non-interactive commands. Launch installers or applications that require visible observation from the VM's interactive desktop, for example through an interactive scheduled task or a console session.

Start from a clean checkpoint. Do not attach host submission directories as writable shared storage.

### Operate the guest through VMConnect

For computer use, reuse an existing Virtual Machine Connection window for the target VM or open one with `vmconnect.exe`. Verify the host and VM shown in the window, then operate the signed-in guest's visible desktop. Launch GUI programs from that desktop when visual observation is required. Windows created in a non-interactive PowerShell Direct session remain separate.

Set `$ServerName`, `$VMName`, and `$InstanceCount` for the selected host, VM, and connection instance. Obtain the VM GUID from Hyper-V rather than copying a machine-specific command:

```powershell
$VM = Get-VM -ComputerName $ServerName -Name $VMName -ErrorAction Stop
& "$env:WINDIR\System32\vmconnect.exe" $ServerName $VM.Name -G "$($VM.Id)" -C $InstanceCount
```

`-G` selects the VM by GUID. `-C` is the VMConnect instance count used when opening multiple connections, normally `0` for a single connection. Run `vmconnect.exe -?` for the local help. Use the connection UI or a saved credential when authentication is needed, and keep passwords out of command arguments and evidence files.

### GPU-dependent installers and applications

If the installer or application rejects the guest because it lacks a compatible GPU, follow [GPU-dependent validation](vm-gpu.md). Select a partitionable device explicitly, prepare compatible guest drivers, and verify the required graphics API before retrying. Keep GPU selection and MMIO sizes specific to the approved environment.

### Checkpoints with GPU partitions

Hyper-V can reject `Restore-VMSnapshot` while a VM with a GPU partition adapter is running. Shut down the guest before restoring the checkpoint, wait for the VM state to become `Off`, restore the checkpoint, and then start it. If restore still fails, use a validation VM without GPU-P or remove and recreate the GPU partition around the checkpoint lifecycle. Do not continue validation after a failed restore.

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
- User and machine PATH entries, expanded directory identities, existence, and top-level command candidates.
- Registry value types, hive, view, scope evidence, user SID, elevation, and capture phase.

The collector rejects a snapshot when all three evidence collections are empty. Do not continue from a zero-record JSON file. The script does not inventory Start menu entries, arbitrary AppData files, installed services, or the complete filesystem. Collect those separately with focused guest commands when they matter.

## 3. Run the installer explicitly inside the VM

Download the installer from its official URL inside the guest and verify its SHA256 there. This avoids `Copy-VMFile` compatibility and source-path failures for large payloads. The host controller uses Guest Service only for the small collector script. The state scripts never download or execute the installer.

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

Before launching, verify the file's architecture. Use `Get-PEArchitectureInfo` for PE launchers and `Get-MsiInstallerInfo` or the MSI package template for MSI payloads. A page marked x64 can still serve an x86 launcher, and `win32` does not prove x86 installed binaries.

When runtime downloads or update sources need investigation, follow [Capture VM network traffic](vm-network-capture.md). It covers host capture proxies, guest-only routing, Proxifier/TUN configurations, and guest CA stores. Keep the final unattended-install validation free of capture-specific preparation.

### Preserve quotes in installer switches

PowerShell can interpret or remove quotes around and within installer switches before the native process receives them. Prefer running quote-sensitive installer commands from CMD inside the VM, or stage the exact command in a guest `.cmd` file. Host-side PowerShell should transfer or dispatch that command rather than execute an unknown installer locally. CMD also has its own escaping and variable-expansion rules. Save the literal command in evidence and check the installer's logs for the arguments it received.

### Check silent exits without elevation

Some installers require an elevated caller to start installation but exit silently without requesting UAC when launched unelevated. When this behavior is suspected, use Computer Use through [VMConnect](#operate-the-guest-through-vmconnect) to launch the exact artifact from an unelevated shell on the signed-in guest's visible desktop. Do not select **Run as administrator**, use `-Verb RunAs`, or launch from an elevated terminal for this case. Verify the launch shell's token elevation rather than inferring it from administrator-group membership. A non-interactive PowerShell Direct launch alone cannot establish the absence of a visible prompt.

Observe whether setup starts, a UAC prompt appears, or the process exits without installing. Record the launch context, command line, screenshots, logs, exit code, and installed-state comparison. A quick exit, even with code `0`, does not prove success or an elevation requirement. Check for a continuing child installer before concluding that nothing happened. If Computer Use cannot operate the guest desktop, ask the user to perform the observed launch and leave the result unverified until evidence is available.

Restore the checkpoint and repeat with the same artifact, requested scope, and silent switches from an explicitly elevated shell. When the unelevated case cannot start installation and the elevated case completes unattended, add `ElevationRequirement: elevationRequired` to the affected manifest entry. Apply it only to the validated scope and route. Follow the [elevation field rules](../../../author-winget-manifest/references/manifest/defaults-and-return-codes.md#elevationrequirement) for placement and other behaviors.

### Require and inspect installer logs

Pass the installer's supported log argument on every silent validation run, including when WinGet supplies that argument by default and the manifest correctly omits it. Use the family workflow, static parser result, or WinGet default-switch table to choose the syntax. Give each validation case a unique path under `C:\DumplingsValidation\Logs` and preserve the exact argument list in evidence.

Treat `<LOGPATH>` as a destination hint. An installer may create the named file, create a directory at that path, use the path as a filename prefix and write several adjacent logs, or ignore it and write under `%TEMP%`. Record the launch time and inspect all of these locations. During an apparent hang, read newly written text logs with `Get-Content -Tail 200` while the process is still running. After completion, retrieve and read the complete log file, log directory, adjacent matching files, and relevant new `%TEMP%` logs, then preserve them in the transient evidence directory. Do not paste full logs into chat.

If the installer documents no log switch or rejects logging, record that limitation and still inspect newly created or modified files under `%TEMP%`, `%ProgramData%`, and the installer's working directory. Absence of a requested log is evidence to investigate, not proof that installation succeeded.

### Capture WinGet diagnostic logs separately

When testing through `winget install --manifest` inside the VM, add `--verbose-logs` and capture `winget --info` to identify that client's **Logs** directory. `--logs` or `--open-logs` opens the default directory. It does not download PR artifacts. `-o` or `--log` selects the installer log destination and is separate from WinGet's own diagnostic log. Do not assume `%TEMP%\AICLI` or a particular packaged-client path applies to every build or user. Keep both logs in the validation evidence.

Archive logs promptly. Current [logging settings](https://github.com/microsoft/winget-cli/blob/master/doc/Settings.md#logging) default to deleting files older than seven days or beyond a 128 MB total at process startup. WinGet's own log wraps near 16 MB. Installer logs do not use that wrapping limit. Record the client's version and settings when interpreting missing or truncated history. For service-side PR logs, follow [Validation logs and check results](../../../author-winget-manifest/references/submission/validation-logs.md), which uses the completion check's CDN artifact link.

### Capture the process result

Capture the outer process result and retain the exact exit code:

```powershell
$LogPath = 'C:\DumplingsValidation\Logs\Silent\Installer.log'
$StartedAtUtc = [DateTime]::UtcNow
$Process = Start-Process -FilePath C:\DumplingsValidation\Installer.exe -ArgumentList @('<silent switches>', '<log switch with log path>') -PassThru

$WaitResult = & 'C:\DumplingsValidation\Wait-WinGetVMProcess.ps1' -Process $Process -TimeoutSeconds 900
if ($WaitResult.TimedOut) {
  Get-ChildItem -LiteralPath (Split-Path -Path $LogPath -Parent) -File -Recurse -ErrorAction SilentlyContinue | Where-Object LastWriteTimeUtc -GE $StartedAtUtc | ForEach-Object { "### $($_.FullName)"; Get-Content -LiteralPath $_.FullName -Tail 200 -ErrorAction SilentlyContinue }
  [pscustomobject]@{ StartedAtUtc = $StartedAtUtc.ToString('o'); ExitCode = $null; Mode = 'silent'; TimedOut = $true }
  throw 'Silent installation exceeded the validation timeout. Collect the live logs from the host before terminating the process.'
}
[pscustomobject]@{
  StartedAtUtc = $StartedAtUtc.ToString('o')
  ProcessId = $WaitResult.ProcessId
  ExitCode = $WaitResult.ExitCode
  Mode = '<interactive|silent|silentWithProgress|cancelled>'
  TimedOut = $false
}
```

Do not replace the bounded process-object wait with `Start-Process -Wait`. On Windows, `-Wait` waits for the started process and its descendants, so an updater, helper, or launched application that remains alive can make validation appear hung after the installer itself has exited. [PowerShell issue #15555](https://github.com/PowerShell/PowerShell/issues/15555) reproduces this difference from `Wait-Process`, which waits only for the specified processes. The current [`Start-Process -Wait` contract](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process#-wait) documents the process-tree behavior. Keep `-PassThru`, apply an explicit timeout to the returned process, and inspect the process tree separately when wrapper behavior matters.

The returned process can also be a short-lived launcher. Waiting for that process alone does not prove that its child installer has finished. For example, `runas.exe` can exit after launching its child without forwarding the child's exit code, as the issue describes. Record the outer exit code separately, track the actual installer with a bounded wait, and confirm its logs and installed state before taking the after-install snapshot.

The controller stages `Wait-WinGetVMProcess.ps1` beside the collector. It polls one retained process handle in short, bounded slices and leaves the process alive on timeout. Follow [bounded process waits](vm-process-wait.md) for known nested PIDs, an explicit process-tree wait, and remoting-session cleanup. Do not assume that wrapping a launch in `Start-ThreadJob` alone waits for its descendants.

The normal success expectation is exit code `0`. A nonzero code may indicate failure or a documented successful outcome such as success-with-reboot. Accept it only when vendor documentation, installer-family return-code evidence, or a repeatable successful installed-state comparison proves the meaning. Then author `InstallerSuccessCodes` or `ExpectedReturnCodes` only when required by the manifest rules. A zero exit code is still insufficient without the expected installed state and a blocker-free unattended run.

When the process hangs, leave it running long enough to collect its live evidence from the host, then terminate it inside the guest and treat the route as failed:

```powershell
& $Tool -Action CollectLogs -VMName PackageValidation -Phase SilentTimeout -UserName SpecterShell -AllowEmptyPassword -OutputDirectory $Evidence -LogPath 'C:\DumplingsValidation\Logs\Silent\Installer.log' -InstallerStartedAtUtc '<UTC launch timestamp>' -InstallerMode silent -InstallerTimedOut
```

After a completed run, pass the exact exit code:

```powershell
& $Tool -Action CollectLogs -VMName PackageValidation -Phase Silent -UserName SpecterShell -AllowEmptyPassword -OutputDirectory $Evidence -LogPath 'C:\DumplingsValidation\Logs\Silent\Installer.log' -InstallerStartedAtUtc '<UTC launch timestamp>' -InstallerExitCode 0 -InstallerMode silent
```

The controller writes `<Phase>.InstallerLogs.json` and copies bounded log files to `Logs\<Phase>`. The JSON records requested, adjacent, and recent `%TEMP%` candidates, tail text, copied byte counts, timeout state, the exit code, and `ExitCodeIsZero`. Review its warnings when files exceed the per-file or total limits. Use `-SkipLogFileTransfer` only when metadata and tails are sufficient. Adjust `MaximumLogFiles`, `MaximumLogFileBytes`, `MaximumTotalLogBytes`, or `LogTailLineCount` only for an evidenced need.

Run cancellation, elevated/non-elevated behavior, user/machine scope, and quiet/passive variants as separate checkpoint-restored cases. For wrappers, record whether the outer process propagates nested MSI codes. If the silent process exceeds the case timeout, inspect logs before termination and treat the route as failed unless the logs prove a bounded prerequisite operation that subsequently completes in a clean repeat.

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

Delete the task after collecting evidence. Add `/rl highest` only when the specific validation route requires an elevated first run. Do not use it for ordinary user-context initialization.

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

Review `VisibleARPChanges` first. Keep `HiddenARPChanges` to explain embedded MSI/custom EXE behavior. Review `EnvironmentPathChanges` for added, removed, or modified user and machine PATH entries. Each entry includes command candidates observed at capture time. A modified entry can mean that command candidates appeared in an existing PATH directory even when the PATH string itself did not change. Confirm each intended CLI command from a fresh shell. Record only user-facing commands. Exclude GUI executables, uninstallers, updaters, crash tools, and framework implementation helpers such as .NET's `createdump`. Confirm installed paths, executable architecture, services, drivers, and package scope independently. `WOW6432Node` does not determine installed architecture.

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
- The requested installer log and any fallback logs, including the last meaningful operation before a hang or failure.
- Exit code `0` for ordinary success, or conclusive evidence for each accepted nonzero success, cancellation, failure, and reboot code.
- `ElevationRequirement` using both launch contexts when relevant.
- User and machine PATH changes, the installed directories they expose, and commands that work from a fresh shell.
- Network endpoints, stable metadata, and payload hashes for download bootstrappers, using [VM network capture](vm-network-capture.md) when needed.
- Upgrade behavior by installing the prior version before the new version when required.

Restore the checkpoint after every independent route.

## Family-specific notes

Focused installer pages link here and list only additional checks. Typical examples are Burn chain exit-code forwarding, Advanced Installer hidden MSI entries, NSIS/Inno wrapper ownership, Qt IFW CLI behavior, and SFX command quoting.

## Stop conditions

Stop when the installer requires a response file, unavoidable user interaction, a blocking Windows Security driver-trust prompt, hardware that the approved validation VM cannot provide, private credentials, account activation, email-delivered links, unofficial payloads, or session-bound URLs that cannot be reproduced. Do not weaken the VM boundary to continue.
