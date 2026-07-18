# DeployMaster

## When To Use

Use `InstallerType: exe` for installers built with DeployMaster. WinGet has no
DeployMaster-specific defaults, so every non-default mode and switch must be
supported by static documentation or VM evidence.

## Detection

Strong evidence is a validated DeployMaster package locator at file offset
`0x80`, a matching CRC32-protected package region, and DeployMaster PE version
comments. Do not classify an arbitrary LZMA overlay from marker strings alone.

```powershell
. .\Modules\PackageModule\Index.ps1
$Info = Get-DeployMasterInfo -Path $InstallerPath
```

## Binary Structure

DeployMaster keeps an absolute package locator at file offset `0x80`. The locator protects a bounded package range with expected file size and CRC32. The package begins with LZMA properties followed by a version-dependent control header and compressed metadata/file ranges.

```text
PE setup stub
+-- locator at [abs] 0x80
`-- package at PackageOffset
    +-- 5-byte LZMA properties
    +-- 70/74-byte observed control header
    +-- compressed metadata range
    `-- compressed file-data range
```

```text
Base   Offset  Size  Field
-----  ------  ----  ---------------------------------------------
[abs]  0x80    4     PackageOffset, uint32 LE -> [abs]
[abs]  0x84    4     IntegrityLength, uint32 LE
[abs]  0x88    4     ExpectedCRC32, uint32 LE
[abs]  0x8C    8     ExpectedFileSize, uint64 LE
[abs]  0x94    4     Reserved/observed
```

The CRC covers the declared integrity range, not all bytes to EOF. Current and legacy control headers are selected only after size/range checks. Undocumented control fields remain `Observed`; the parser uses only fields demonstrated by controlled builder samples and rejects truncated or expanding-out-of-bound ranges.

## Manifest Shape

DeployMaster is a generic EXE family. The documented silent and install-folder
switches therefore need explicit installer-level fields:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # DeployMaster
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /silent
    InstallLocation: /appfolder "<INSTALLPATH>"
```

Remove a switch or mode that the current package does not support. Do not infer
an unattended switch from another generic EXE family.

## WinGet Defaults And Overrides

WinGet supplies no DeployMaster defaults for generic `InstallerType: exe`.
Treat the documented DeployMaster switches as complete installer-level
overrides, and retain only modes demonstrated by the current package.

## Step-By-Step Analysis

### Step 1: Parse Once

`Get-DeployMasterInfo` validates the locator, file size, CRC32, current or
legacy control-header layout, and structured LZMA metadata. Reuse the returned
object instead of calling multiple `Read-*FromDeployMaster` helpers:

```powershell
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode,
  Scope, SupportedScopes, InstallerArchitecture,
  ApplicationArchitectureMode, ApplicationArchitectures,
  SupportedOperatingSystemArchitectures, WritesAppsAndFeaturesEntry, Warnings

$Info.FileEntries
$Info.FileAssociations
$Info.FileExtensions
```

The parser distinguishes these builder modes:

- x86 application for x86 Windows only.
- x86 application for x86 and x64 Windows.
- x86 and x64 applications selected for the running Windows architecture.
- x64 application with an x86 installer stub.
- x64 application with a pure x64 installer.

Use the installed application architecture for manifest authoring. The outer
stub architecture is separate evidence and does not by itself determine the
manifest `Architecture`.

### Step 2: Expand Bounded Content

Expansion never starts the installer. It writes each decoded runtime core,
structured metadata block, and package file beneath separate safe paths:

```powershell
$Files = Expand-DeployMasterInstaller -Path $InstallerPath -DestinationPath $DestinationPath
$Files
```

Inspect `Runtime\DeployMasterCore-x86.exe` and/or
`Runtime\DeployMasterCore-x64.exe` for runtime behavior. Inspect `Payload` for
the installed files and nested installers. Use `-Name` to select one file.

### Step 3: Resolve Scope And ARP

The package-control scope byte is authoritative static builder evidence:

- `0`: current user.
- `1`: all users.
- `2`: user and machine scope.

The structured identity block supplies `DisplayName`, `DisplayVersion`,
`Publisher`, and separate user/machine install locations. DeployMaster's
built-in uninstaller uses the display name as its uninstall-key identity, so
the parser returns that value as `ProductCode` and emits built-in ARP writes.

Custom Registry-tab actions are not decoded yet. If `Warnings` reports this
limitation, use VM evidence to detect custom ARP overrides before relying on
the built-in values. For `Brinno.BrinnoVideoPlayer`, VM evidence confirms an
x86 HKLM EXE ARP entry keyed `Brinno Video Player` with no `WindowsInstaller`
value.

### Step 4: Resolve File Associations

`FileAssociations` contains each literal extension, description, default flag,
icon indexes, action names, executable indexes, and parameters. Include
`FileExtensions` when the literal extensions are valid.

An executable index of `-1` means the action did not resolve to a packaged
file and should not be treated as an installed open command. Protocols and
arbitrary custom registry associations still require separate static or VM
evidence.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for
silent behavior, exit codes, default scope of a dual-scope package, custom ARP
writes, or first-run associations. DeployMaster-specific checks are:

- Test `/silent` and `/appfolder` exactly as documented for the package.
- Compare HKCU and both HKLM uninstall views with the parsed scope.
- Confirm whether unresolved file-type actions are intentionally omitted.
- Confirm installed executable architecture rather than using the stub alone.

## Known Packages

- `Brinno.BrinnoVideoPlayer`

## Implementation Sources

- [DeployMaster manual](https://www.deploymaster.com/manual.html)
- [DeployMaster silent installation](https://www.deploymaster.com/manual.html#silent)
