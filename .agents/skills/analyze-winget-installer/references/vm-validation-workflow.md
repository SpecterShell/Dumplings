# VM-Only Dynamic Validation Workflow

Use this workflow only for facts static analysis cannot prove. Never execute an unknown installer on the host. The bundled scripts capture state but deliberately do not launch installers or applications.

## 1. Prepare Hyper-V From PowerShell Core

Codex on Windows must load the Windows PowerShell Hyper-V module explicitly:

```powershell
$env:PSModulePath += ';C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
Import-Module Hyper-V -UseWindowsPowerShell -PassThru
Get-Command Get-VM, Copy-VMFile
```

Compatibility-session Hyper-V objects are deserialized. Use their values for orchestration, not methods. Confirm that the VM is running, PowerShell Direct accepts the guest credential, and **Guest Service Interface** is enabled for `Copy-VMFile`.

Start from a clean checkpoint. Do not attach host submission directories as writable shared storage.

## 2. Capture The Baseline

The host controller stages the Windows PowerShell 5.1-compatible guest collector and retrieves JSON through PowerShell Direct:

```powershell
$Tool = '.\.agents\skills\analyze-winget-installer\scripts\Invoke-WinGetVMInstalledState.ps1'

& $Tool -Action Capture -VMName PackageValidation -Phase BeforeInstall `
  -UserName PandaTopo -AllowEmptyPassword -OutputDirectory .\VMValidation\Package
```

Prefer `-Credential $Credential` for normal password-protected guests. `-AllowEmptyPassword` must always be explicit and never stores a password in the repository.

The snapshot records:

- HKLM 64-bit, HKLM 32-bit, and HKCU ARP entries, including hidden/incomplete entries.
- Direct `Software\Classes` protocols and extensions with ProgID commands and icons.
- `RegisteredApplications` capability mappings.
- Registry value types, hive, view, scope evidence, user SID, elevation, and capture phase.

## 3. Run The Installer Explicitly Inside The VM

Copy the installer separately, verify its SHA256 inside the guest, and run only the intended test case. The state scripts never do this step.

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

## 4. Capture After Installation

```powershell
& $Tool -Action Capture -VMName PackageValidation -Phase AfterInstall `
  -UserName PandaTopo -AllowEmptyPassword -OutputDirectory .\VMValidation\Package

& $Tool -Action Compare `
  -BeforePath .\VMValidation\Package\BeforeInstall.json `
  -AfterPath .\VMValidation\Package\AfterInstall.json `
  -OutputDirectory .\VMValidation\Package
```

Review `VisibleARPChanges` first. Keep `HiddenARPChanges` to explain embedded MSI/custom EXE behavior. Confirm installed paths, executable architecture, services, drivers, and package scope independently; `WOW6432Node` does not determine installed architecture.

## 5. Capture First-Run Associations

Some applications register protocols and extensions only on first launch. Launch the application explicitly inside the VM, complete only unavoidable initialization, close it, then capture:

```powershell
& $Tool -Action Capture -VMName PackageValidation -Phase AfterFirstRun `
  -UserName PandaTopo -AllowEmptyPassword -OutputDirectory .\VMValidation\Package

& $Tool -Action Compare `
  -BeforePath .\VMValidation\Package\AfterInstall.json `
  -AfterPath .\VMValidation\Package\AfterFirstRun.json `
  -OutputDirectory .\VMValidation\Package
```

Accept only literal protocol/extension changes whose ProgID or capability command resolves to the installed application. Exclude `UserChoice`, recent-file, Explorer cache, and unrelated dependency registrations.

## 6. Decide Manifest Evidence

Read [Installed-State And Association Workflow](installed-state-workflow.md) before converting deltas into `AppsAndFeaturesEntries`, `Protocols`, or `FileExtensions`.

Also verify:

- Claimed `InstallModes` and complete switch replacements.
- Success, cancellation, failure, and reboot exit codes.
- `ElevationRequirement` using both launch contexts when relevant.
- Network endpoints, stable metadata, and payload hashes for download bootstrappers.
- Upgrade behavior by installing the prior version before the new version when required.

Restore the checkpoint after every independent route.

## Family-Specific Notes

Focused installer pages link here and list only additional checks. Typical examples are Burn chain exit-code forwarding, Advanced Installer hidden MSI entries, NSIS/Inno wrapper ownership, Qt IFW CLI behavior, and SFX command quoting.

## Stop Conditions

Stop when the installer requires a response file, unavoidable user interaction, hardware, private credentials, account activation, email-delivered links, unofficial payloads, or session-bound URLs that cannot be reproduced. Do not weaken the VM boundary to continue.
