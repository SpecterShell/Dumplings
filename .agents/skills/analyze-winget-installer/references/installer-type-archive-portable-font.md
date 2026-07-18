# Archive, Portable, And Font Installer Types

## When To Use

Use this page for ZIP/archive installers, archive-contained portable packages, loose portable executables, and font packages.

## Detection

Route here when magic and structured inspection identify an archive, a standalone portable binary, or a font file. Inspect archive entries before choosing `NestedInstallerType`; do not assume ZIP means portable, and do not trust a filename extension over file content.

## Binary Structure

This route has no single container format. Identify the outer magic first, then apply the corresponding standard structure and analyze selected binary entries independently.

```text
Archive
+-- format header/signature         ZIP, 7z, RAR, TAR, or another supported type
+-- entry catalog                   names, sizes, compression, CRC/hash
`-- selected entry range
    `-- PE / MSI / MSIX / font      route again by content

Loose PE
+-- DOS header: 4D 5A ("MZ")
+-- PE signature: 50 45 00 00
+-- COFF/optional headers           machine, subsystem, data directories
`-- sections / CLR metadata / imports
```

Archive entry offsets and lengths are container-relative; PE RVAs are image-relative and must be mapped through the section table. A ZIP central directory is catalog evidence, not proof that an entry is safe to export. Dumplings bounds expansion and rejects rooted, traversing, duplicate, linked, or escaping paths. Any package containing a binary uses concrete WinGet architecture, never `neutral`.

## Manifest Shape: ZIP With Nested EXE

Use this shape after [Step 2](#step-2-route-each-nested-installer) proves that the selected archive entry is the installer WinGet should invoke. Route the extracted EXE through its focused family page before adding switches.

```yaml
Installers:
- Architecture: x64
  InstallerType: zip
  NestedInstallerType: exe
  NestedInstallerFiles:
  - RelativeFilePath: ProductSetup.exe
  InstallerUrl: https://example.com/Product-1.2.3-x64.zip
  InstallerSha256: <SHA256>
```

Add installer-level `InstallerSwitches` only when the nested EXE's focused analysis proves complete values.

## Manifest Shape: ZIP With Nested MSI

Use this shape when the selected nested database passes `Get-MsiInstallerInfo`. Use `NestedInstallerType: wix` when its `InstallerBuilder` is WiX, and use the visible MSI/custom ARP product code returned by the parser.

```yaml
Installers:
- Architecture: x64
  InstallerType: zip
  NestedInstallerType: msi
  NestedInstallerFiles:
  - RelativeFilePath: Product.msi
  InstallerUrl: https://example.com/Product-1.2.3-x64.zip
  InstallerSha256: <SHA256>
  ProductCode: '{00000000-0000-0000-0000-000000000000}'
```

## Manifest Shape: ZIP With Portable Binary

Use this shape only when every selected command target is intended to run without installation and [Steps 3-4](#step-3-determine-portable-architecture) establish concrete architecture and dependencies.

```yaml
Installers:
- Architecture: x64
  InstallerType: zip
  NestedInstallerType: portable
  NestedInstallerFiles:
  - RelativeFilePath: Product.exe
    PortableCommandAlias: product
  InstallerUrl: https://example.com/Product-1.2.3-x64.zip
  InstallerSha256: <SHA256>
```

Use one or more `NestedInstallerFiles` only for portable packages. Set `ArchiveBinariesDependOnPath` only with evidence.

## Manifest Shape: Loose Portable Binary

Use this shape when the downloaded PE is the command target and does not perform setup-like behavior.

```yaml
Installers:
- Architecture: x64
  InstallerType: portable
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  Commands:
  - product
```

Reject `portable` when the binary installs services, drivers, ARP entries, or launches a setup/bootstrap workflow.

## Manifest Shape: Font

Use this shape only for a supported font artifact, not an archive that happens to contain fonts plus application binaries.

```yaml
Installers:
- Architecture: neutral
  InstallerType: font
  InstallerUrl: https://example.com/Font-1.2.3.ttf
  InstallerSha256: <SHA256>
```

Font manifests belong under the `fonts` root, not the normal `manifests` root.

## WinGet Defaults And Overrides

- ZIP with nested installer: switch and mode behavior follows the effective `NestedInstallerType`. Remove fields equal to that type's WinGet defaults and provide complete overrides for differences.
- ZIP with generic nested EXE: WinGet supplies no switches; explicitly specify supported modes and complete switch values.
- ZIP/loose portable and font: omit `InstallModes` and `InstallerSwitches`; no installer wizard is invoked.
- Never apply archive-extractor switches to a nested installer command unless the manifest schema and WinGet behavior explicitly require them.

## Step-By-Step Analysis

### Step 1: Inspect Archive And File Structure

Run the bundled analyzer first:

```powershell
Get-WinGetInstallerAnalysis -Path C:\Path\To\Product.zip
```

Enumerate entries with bounded, traversal-safe archive APIs. Identify executables, MSI/MSIX packages, runtime sidecars, licenses, and data files. Do not extract or execute every entry merely to classify the archive.

### Step 2: Route Each Nested Installer

Extract only candidate nested installers to a temporary directory and route each through [Installer Analysis Workflow](workflow.md) as if it were downloaded directly. Select the file WinGet should invoke, preserve its relative path exactly, and model ARP/scope/switch behavior from that nested family.

For multiple installers, determine whether they represent architectures, locales, prerequisites, or a chain. Do not create `NestedInstallerFiles` for prerequisite installers; that field is for portable command targets.

### Step 3: Determine Portable Architecture

For loose portable executables, DLL-backed apps, and archive portable candidates, use:

```powershell
$Architecture = Get-PEArchitectureInfo -Path C:\Path\To\Product.exe
$Dependencies = Get-PEDependencyInfo -Path C:\Path\To\Product.exe
```

Pass adjacent native DLLs, same-name managed DLLs, `.runtimeconfig.json`, `.deps.json`, and bundled-runtime markers as related files:

```powershell
$Related = Get-ChildItem C:\Path\To -File | Where-Object { $_.Name -match '\.(dll|runtimeconfig\.json|deps\.json)$' }
$Architecture = Get-PEArchitectureInfo -Path C:\Path\To\Product.exe -RelatedFile $Related.FullName
$Dependencies = Get-PEDependencyInfo -Path C:\Path\To\Product.exe -RelatedFile $Related.FullName
```

The helpers accept DLL primary paths for static evidence, but a DLL alone is not automatically a valid portable command target. Use `RecommendedWinGetArchitecture` when singular; create concrete entries from `RecommendedWinGetArchitectures` when multiple values are supported. Managed AnyCPU still requires concrete WinGet architectures. Never use `neutral` for a package containing PE binaries; ARM32 is excluded.

### Step 4: Determine Portable Dependencies

`Get-PEDependencyInfo` maps imported VC runtime DLLs to packages such as `Microsoft.VCRedist.2015+.x64` and reports UCRT separately. Verify whether runtime DLLs are bundled before adding dependencies.

For .NET 5+ apps, inspect the apphost-bound managed DLL and `runtimeconfig.json`, including uncompressed single-file bundle metadata. Map framework-dependent apps to `Microsoft.DotNet.Runtime.N`, `Microsoft.DotNet.DesktopRuntime.N`, or `Microsoft.DotNet.AspNetCore.N`; omit the base Runtime when Desktop or ASP.NET Core covers the same major. Do not add runtime dependencies when `includedFrameworks`, `hostfxr.dll`, `hostpolicy.dll`, `coreclr.dll`, or `System.Private.CoreLib.dll` proves self-contained deployment.

### Step 5: Build And Validate The Manifest

Choose the shape only after nested type, command target, architecture, and dependencies are resolved. Reject portable classification for setup-like behavior. Require VM validation when first run mutates the machine, architecture depends on native DLL loading, or static evidence cannot distinguish command binaries from installer/bootstrapper binaries.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when nested command selection, installed binary architecture, runtime dependencies, first-run mutation, or portable behavior cannot be proved statically.

## Implementation Sources

- [.NET](https://github.com/dotnet/dotnet)
- [Dependencies](https://github.com/lucasg/Dependencies)
