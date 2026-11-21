# Archive workflow

## When to use

Use this workflow when the downloaded artifact is an archive that contains an installer. Inspect its entries before choosing `NestedInstallerType`; a ZIP is not necessarily portable.

## Detection

Identify the archive by magic and structured catalog data rather than its filename extension. Enumerate entries with bounded, traversal-safe archive APIs and identify PE, MSI, MSIX, runtime sidecar, license, and data candidates.

See [Archive internals](../../internals/archive/overview.md) for container boundaries and extraction invariants.

## Static analysis
Read [Archive parser internals](../../internals/archive/overview.md) before changing detection, extraction, binary decoding, or parser limits.

1. Run `Get-WinGetInstallerAnalysis -Path C:\Path\To\Product.zip`.
2. Extract only candidate nested installers to a temporary directory.
3. Route each candidate through [Installer analysis](../../workflows/installer-analysis.md) as if it were downloaded directly.
4. Select the file WinGet should invoke and preserve its relative path exactly.
5. Determine whether multiple installers represent architectures, locales, prerequisites, or an execution chain. Do not list prerequisite installers under `NestedInstallerFiles`; that field lists portable command targets.
6. Apply switches, modes, ARP metadata, scope, and architecture according to the selected nested family.

## Manifest shape

Use this shape after inspecting the nested executable through its focused installer-family workflow:

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

Add installer switches only when analysis of the nested EXE proves the complete values.

Use `NestedInstallerType: wix` when `Get-MsiInstallerInfo` identifies WiX. Use the visible MSI or custom ARP product code returned by the parser.

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

## WinGet defaults and overrides

Switch and mode behavior follows the effective `NestedInstallerType`. Remove fields equal to that type's WinGet defaults. A generic nested EXE has no WinGet switch defaults, so provide complete supported values.

Use [VM validation](../../workflows/vm-validation.md) when static evidence cannot prove nested command selection, execution order, ARP ownership, or switches.

When `NestedInstallerType` is `portable`, inspect the complete runtime layout rather than extracting only the command EXE. Add `ArchiveBinariesDependOnPath: true` if that executable depends on DLLs, native runtimes, plugins, or required relative-path files that remain in the extracted directory. Omit it for incidental documentation and other unrelated files. Follow the [portable workflow](../portable/workflow.md) for command aliases, PE dependency analysis, and VM verification of the installed command.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow the canonical [VM validation workflow](../../workflows/vm-validation.md) and record only family-specific differences discovered during installation and first run.

## Known examples

- `SquadraTechnologies.secRMM`: architecture-specific ZIP archives containing WiX MSI installers.
