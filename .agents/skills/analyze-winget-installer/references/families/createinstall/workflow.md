# CreateInstall workflow

## When to use

Use `InstallerType: exe` for CreateInstall-generated setup EXEs.

## Detection

Strong evidence includes `CreateInstall`, `Novostrim`, CreateInstall project extensions such as `.ci` or `.ciq`, or accepted package manifests for `Novostrim.CreateInstall*`.

The parser validates Gentee GEA v1/v2 container structures and expands stored, LZGE-compressed, and Gentee PPMd-I files with bundled source-backed decoders. It applies bounded header, entry, block, path, model-memory, and output limits. Password-protected entries are reported but intentionally not extracted. PE identity does not prove the visible uninstall key, so do not derive `ProductCode` from an arbitrary GUID or string inside the payload.

Do not pass GEA PPMd blocks to SharpCompress's standard `PpmdStream`. Gentee's variant changes the PPMd-I model and allocator as well as the block framing, and order-1 blocks continue model state across independent range streams.

## Static analysis

Read [CreateInstall Parser Internals](../../internals/createinstall/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse CreateInstall metadata

Load PackageModule once, parse the installer once, and reuse the result:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-CreateInstallInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, Scope, SupportedScopes,
  RequestedExecutionLevel, WritesAppsAndFeaturesEntry, CanExpand, ExtractedFiles, Diagnostics
```

Treat `GEA`, `ExtractedFiles`, and `Diagnostics` as structured archive evidence. `CanExpand: false` blocks extraction when the archive is encrypted or contains an unknown compression method.

PPMd payloads are decoded by the source-shipped managed `SharpCompress.Gentee` companion provider. Standard SharpCompress PPMd-I is not compatible with GEA's model-update and solid-continuation rules. The provider uses the compressed size declared by each GEA block as a hard boundary and rejects truncated blocks rather than reading into the following record.

### Extract supported payload files

```powershell
if ($Info.CanExpand) {
  $Files = Expand-CreateInstallInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
  $Files | Select-Object FullName, Length
}
```

Analyze nested PE/MSI files separately. Extraction does not prove which payload writes the visible uninstall entry.

### Resolve ARP identity and scope

Inspect the parser evidence before using package history:

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

The parser derives `ProductCode` only when the compiled Gentee program contains a source-verified call to CreateInstall's built-in `addremoveext` routine with a literal uninstall-key argument. If that call is absent, dynamic, or conditional, use the VM installed-state comparison. Current accepted manifests provide these product-code-like uninstall keys:

- `Novostrim.CreateInstall`: `ProductCode: CreateInstall`
- `Novostrim.CreateInstall.Free`: `ProductCode: CreateInstall Free`
- `Novostrim.CreateInstall.Lite`: `ProductCode: CreateInstall Light`
- `CrossPlusA.Balabolka`: `ProductCode: Balabolka`

### Validate unresolved script behavior

Do not assume every CreateInstall-generated package accepts `-silent`; verify with existing manifests from the same product line, static strings, or VM validation.

## Manifest shape

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

## WinGet defaults and overrides

WinGet supplies no CreateInstall defaults for generic `InstallerType: exe`. Treat parsed switch values as complete overrides and explicitly specify supported modes. Do not retain placeholder switches returned from weak marker-only detection.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for project-defined silent switches, script conditions, scope, and visible ARP identity.

## Known examples

- `CrossPlusA.Balabolka`
- `Novostrim.CreateInstall`
- `Novostrim.CreateInstall.Free`
- `Novostrim.CreateInstall.Lite`
