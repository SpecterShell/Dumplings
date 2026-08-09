# Portable workflow

## When to use

Use this workflow for a loose portable command binary or an archive whose selected binaries run without installation. Reject portable classification when the artifact installs services, drivers, ARP entries, or launches a setup or bootstrap process.

## Detection

Identify PE files by content and inspect their headers, imports, CLR metadata, runtime sidecars, and adjacent native DLLs. A DLL can provide static evidence but is not automatically a valid portable command target.

See [Portable internals](../../internals/portable/overview.md) for PE, .NET host, and Tauri asset structures.

## Static analysis
Read [Portable parser internals](../../internals/portable/overview.md) before changing detection, extraction, binary decoding, or parser limits.

## Manifest shape

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

Use `NestedInstallerFiles` only for portable command targets. Set `ArchiveBinariesDependOnPath` only with evidence.

```yaml
Installers:
- Architecture: x64
  InstallerType: portable
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  Commands:
  - product
```

## WinGet defaults and overrides

Omit `InstallModes` and `InstallerSwitches`; no installer wizard is invoked. Use [VM validation](../../workflows/vm-validation.md) when first run mutates the machine, architecture depends on native DLL loading, or portable behavior remains ambiguous.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

```powershell
$Related = Get-ChildItem C:\Path\To -File | Where-Object { $_.Name -match '\.(dll|runtimeconfig\.json|deps\.json)$' }
$Architecture = Get-PEArchitectureInfo -Path C:\Path\To\Product.exe -RelatedFile $Related.FullName
$Dependencies = Get-PEDependencyInfo -Path C:\Path\To\Product.exe -RelatedFile $Related.FullName
```

Use `RecommendedWinGetArchitecture` when singular and create concrete entries from `RecommendedWinGetArchitectures` when multiple values are supported. AnyCPU still requires concrete architectures. Never use `neutral` when a package contains PE binaries; ARM32 is excluded.

`Get-PEDependencyInfo` maps VC runtime imports to WinGet dependencies and reports UCRT evidence separately. Verify whether the runtime DLLs are bundled. For .NET 5 and later, inspect the bound managed DLL, `runtimeconfig.json`, and bundle metadata. Do not add a runtime dependency when bundled `hostfxr.dll`, `hostpolicy.dll`, `coreclr.dll`, `System.Private.CoreLib.dll`, or `includedFrameworks` proves a self-contained deployment. This helper does not infer Windows App Runtime, Microsoft UI XAML, VSTO Runtime, or Office requirements for unpackaged applications; follow the manifest-authoring [dependency workflow](../../../../author-winget-manifest/references/manifest/dependencies.md) when structured installer or publisher evidence proves one of these requirements.

## Tauri assets

Use the Tauri helpers on the application executable, not its installer wrapper:

```powershell
if (Test-TauriExecutable -Path C:\Path\To\Application.exe) {
  $Tauri = Get-TauriExecutableInfo -Path C:\Path\To\Application.exe
  Expand-TauriExecutable -Path C:\Path\To\Application.exe -Name '/index.html' -CollisionAction Rename
}
```

Treat reverse-domain identifiers and ACL strings as candidates rather than package metadata. `CanExpand: false` can mean a custom or URL-backed asset provider. Do not infer absent resources or fetch URLs found as arbitrary binary strings.

## VM validation

Follow the canonical [VM validation workflow](../../workflows/vm-validation.md) and record only family-specific differences discovered during installation and first run.

## Known examples

- `1357310795.TboxWebdav`: framework-dependent and self-contained .NET variants.
- `Logtalk.Logtalk`: source-only package where `Architecture: neutral` is valid because no binary is present.
