# Setup Factory workflow

## When to use

Use `InstallerType: exe # Setup Factory` for Indigo Rose Setup Factory installers. The Dumplings parser supports the version 7 signature and version 8/9 overlay layout without executing the installer.

## Detection

Setup Factory 7 overlays begin with `E0 E1 E2 E3 E4 E5 E6 E7`. Versions 8 and 9 use `E0 E0 E1 E1 ... E7 E7` after the last PE section. Generic `Setup Factory`, `Indigo Rose`, or `IRSetup` strings are supporting evidence only.

## Static analysis

Read [Setup Factory Parser Internals](../../internals/setup-factory/overview.md) before changing detection, extraction, binary decoding, or parser limits.

```powershell
Test-SetupFactory -Path C:\Path\To\Setup.exe
Get-SetupFactoryInfo -Path C:\Path\To\Setup.exe
```

### Parse structured Setup Factory metadata

```powershell
$Info = Get-SetupFactoryInfo -Path C:\Path\To\Setup.exe
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode, InstallLocation, Scope, WritesAppsAndFeaturesEntry

Expand-SetupFactoryInstaller -Path C:\Path\To\Setup.exe -DestinationPath C:\Temp\SetupFactory -Name irsetup.dat -CollisionAction Rename
```

The parser extracts bounded overlay records, verifies CRC values, parses `CSessionVar`, recursively resolves `%Variable%` expressions, and reads built-in uninstall configuration and literal Lua registry writes. It does not probe arbitrary strings.

Version 7 PKWARE implode data is decoded in-process with strict input validation, back-reference validation, an explicit end marker, and an expanded-output limit. Never execute the embedded `irsetup.exe`.

`defactory` is useful only as historical format research for Setup Factory 4-7. It rejects versions 8-9 and does not recover uninstall actions. Dumplings instead uses format evidence from `sfextract` and `SFUnpacker`; neither external executable is a runtime dependency.

### Resolve built-in and custom ARP writes

Use `ProductCode`, `DisplayName`, `DisplayVersion`, and `Publisher` only when returned from structured uninstall or literal registry evidence. `WritesAppsAndFeaturesEntry: false` means the outer installer may delegate registration to a nested payload and requires manual inspection or VM ARP-delta validation.

Prefer explicit custom uninstall registry writes over built-in uninstall settings. If values remain conditional or contain unresolved variables, leave them unset and inspect in a VM.

### Determine registry scope and payload architecture

Literal HKCU uninstall writes indicate user scope; HKLM writes indicate machine scope. A resolved `%ProgramFilesFolder%` installation path is machine-scope evidence when no explicit custom registry write overrides it. Determine architecture from installed binaries or PE behavior, not from the ARP hive.

### Validate conditional Lua and runtime behavior

Verify switches and restart behavior in a Hyper-V guest. Use VM ARP comparison when Lua conditions, unresolved variables, nested payloads, or custom actions prevent a deterministic static result.

## Manifest shape

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Setup Factory
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /S
    SilentWithProgress: /S
  ProductCode: <ProductCode>
```

Switch documentation: [Setup Factory command line options](https://www.indigorose.com/webhelp/suf9/Program_Reference/Command_Line_Options.htm).

## WinGet defaults and overrides

WinGet supplies no Setup Factory defaults for generic `InstallerType: exe`. Treat `/S` and every other shown field as a complete family-specific override, explicitly state supported modes, and remove `SilentWithProgress` when it is not behaviorally distinct or accepted by the current installer.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) when conditional Lua, unresolved session variables, custom actions, nested payloads, restart behavior, or ARP ownership cannot be resolved statically.

## Known examples

- `BicomSystems.OutCALL`
- `BicomSystems.gloCOM`
- `BicomSystems.Communicator`
- `Locklizard.SafeguardPDFViewer`
- `Locklizard.SafeguardPDFWriter`
