# CreateInstall

## When To Use

Use `InstallerType: exe` for CreateInstall-generated setup EXEs.

## Detection

Strong evidence includes `CreateInstall`, `Novostrim`, CreateInstall project extensions such as `.ci` or `.ciq`, or accepted package manifests for `Novostrim.CreateInstall*`.

### Parser API

```powershell
$Info = Get-CreateInstallInfo -Path $InstallerPath
Expand-CreateInstallInstaller -Path $InstallerPath -DestinationPath $DestinationPath
```

The parser validates Gentee GEA v1/v2 container structures and expands stored
and LZGE-compressed files with the bundled decoder. It applies bounded
header, entry, block, path, and output limits. Password-protected entries and
PPMd blocks are reported but intentionally not extracted. PE identity does
not prove the visible uninstall key, so do not derive `ProductCode` from an
arbitrary GUID or string inside the payload.

## Binary Structure

CreateInstall appends a Gentee GEA container to its PE launcher. Dumplings searches for the aligned container magic and validates the full header before trusting any payload size.

```text
PE setup stub
`-- GEA container at [overlay]
    +-- 73-byte GEA v1/v2 header
    +-- NUL-terminated UTF-8 volume pattern
    +-- optional password records
    +-- metadata/catalog (stored or LZGE)
    `-- ordinary and moved file-data regions
```

```text
Base       Offset  Size  Field
---------  ------  ----  ---------------------------------------------
[overlay]  0x00    4     Magic: 47 45 41 00 ("GEA\0")
[overlay]  0x04    2     VolumeNumber, uint16 LE
[overlay]  0x06    4     UniqueID, uint32 LE
[overlay]  0x0A    1     MajorVersion
[overlay]  0x0B    1     MinorVersion
[overlay]  0x14    4     Flags, uint32 LE
[overlay]  0x18    2     VolumeCount, uint16 LE
[overlay]  0x1A    4     HeaderSize, uint32 LE
[overlay]  0x1E    8     SummarySize, int64 LE
[overlay]  0x26    4     InfoSize, uint32 LE
[overlay]  0x2A    8     ArchiveFileSize, int64 LE
[overlay]  0x32    8     VolumeSize, int64 LE
[overlay]  0x3A    8     LastVolumeSize, int64 LE
[overlay]  0x42    4     MovedSize, uint32 LE
[overlay]  0x46    3     Memory/Block/Solid multipliers
```

GEA v2 file records begin with flags (2), FILETIME (8), size (8), compressed size (8), and CRC32 (4); v1 uses 32-bit sizes. Each file block is `[order:1][compressed-size:8]` in v2 or `[order:1][compressed-size:4]` in v1. The order high nibble selects storage/compression. Password and PPMd flags are reported, not bypassed.

## Manifest Shape

Existing accepted `Novostrim.CreateInstall*` manifests use `-silent` for silent and silent-with-progress installation.

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # CreateInstall
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x86.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: -silent
    SilentWithProgress: -silent
  UpgradeBehavior: install
  ProductCode: <ProductCode>
```

## WinGet Defaults And Overrides

WinGet supplies no CreateInstall defaults for generic `InstallerType: exe`. Treat parsed switch values as complete overrides and explicitly specify supported modes. Do not retain placeholder switches returned from weak marker-only detection.

## Step-By-Step Analysis

### Step 1: Parse CreateInstall Metadata

Load PackageModule once, parse the installer once, and reuse the result:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-CreateInstallInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, Scope, SupportedScopes,
  RequestedExecutionLevel, WritesAppsAndFeaturesEntry, CanExpand, ExtractedFiles, Warnings
```

Treat `GEA`, `ExtractedFiles`, and `Warnings` as structured archive evidence. `CanExpand: false` blocks extraction when the archive is encrypted or contains unsupported PPMd/unknown blocks.

### Step 2: Extract Supported Payload Files

```powershell
if ($Info.CanExpand) {
  $Files = Expand-CreateInstallInstaller -Path $InstallerPath -DestinationPath $DestinationPath
  $Files | Select-Object FullName, Length
}
```

Analyze nested PE/MSI files separately. Extraction does not prove which payload writes the visible uninstall entry.

### Step 3: Resolve ARP Identity And Scope

Inspect the parser evidence before using package history:

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

The current parser intentionally returns `ProductCode: null` and `WritesAppsAndFeaturesEntry: null` because PE version resources and a GEA file table do not prove ARP ownership. Use the VM installed-state comparison for a new product. Current accepted manifests provide these package-specific product-code-like display keys:

- `Novostrim.CreateInstall`: `ProductCode: CreateInstall`
- `Novostrim.CreateInstall.Free`: `ProductCode: CreateInstall Free`
- `Novostrim.CreateInstall.Lite`: `ProductCode: CreateInstall Light`

### Step 4: Validate Unresolved Script Behavior

Do not assume every CreateInstall-generated package accepts `-silent`; verify with existing manifests from the same product line, static strings, or VM validation.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for project-defined silent switches, script conditions, scope, and visible ARP identity.

## Known CreateInstall Packages

- `Novostrim.CreateInstall`
- `Novostrim.CreateInstall.Free`
- `Novostrim.CreateInstall.Lite`
