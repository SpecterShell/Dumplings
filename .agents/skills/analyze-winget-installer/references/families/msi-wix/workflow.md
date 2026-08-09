# MSI and WiX workflow

## When to use

Use `InstallerType: msi` for a direct MSI database whose authoring system is not WiX. Use `InstallerType: wix` when static evidence identifies a WiX-authored MSI. This page also covers Advanced Installer-authored and InstallShield-authored direct MSI packages.

If an EXE wrapper invokes an MSI, keep the outer EXE installer type and use this page to analyze the nested MSI's product, upgrade, architecture, location, and visible ARP behavior.

## Detection
Route here when the file is a readable MSI database, `Get-MsiInstallerInfo` succeeds, or an archive/EXE wrapper exposes a nested MSI that is the effective visible ARP writer.

MSI and MSP files are both Compound File Binary files with magic bytes `D0 CF 11 E0 A1 B1 1A E1`. Distinguish them by root storage CLSID rather than filename extension:

- `{000C1084-0000-0000-C000-000000000046}`: Windows Installer package, merge module, or patch-creation properties file.
- `{000C1086-0000-0000-C000-000000000046}`: Windows Installer patch package (`.msp`), for example a `Macrobond.Macrobond` patch installer.
- `{000C1082-0000-0000-C000-000000000046}`: Windows Installer transform (`.mst`), not a standalone WinGet installer.

Do not route an MSP or MST through the direct MSI manifest shapes. Use structured CFB and Windows Installer database evidence rather than the file extension.

## Static analysis
1. Parse the database once and classify its builder through [MSI analysis](analysis.md).
2. Select the matching [manifest shape](manifest-shapes.md).
3. Determine architecture, scope, and launch-context behavior through [Scope and elevation](scope-and-elevation.md).
4. Read [MSI and WiX internals](../../internals/msi-wix/overview.md) only when implementing or debugging the parser.

## Manifest shape

Select the [MSI, WiX, Advanced Installer, InstallShield, or custom-ARP shape](manifest-shapes.md) established by database analysis. Project only fields supported by parser or VM evidence into the installer entry.

## WinGet defaults and overrides

WinGet populates missing switch fields independently for both `InstallerType: msi` and `InstallerType: wix`:

| Field | WinGet default |
| --- | --- |
| `InstallerSwitches.Silent` | `/quiet /norestart` |
| `InstallerSwitches.SilentWithProgress` | `/passive /norestart` |
| `InstallerSwitches.Log` | `/log "<LOGPATH>"` |
| `InstallerSwitches.InstallLocation` | `TARGETDIR="<INSTALLPATH>"` |

With standard MSI behavior, the effective install modes are `interactive`, `silent`, and `silentWithProgress`. Apply these omission and override rules:

- Omit `InstallModes` when all three standard modes are supported. If the package supports a different set, write the complete supported array explicitly.
- Remove each `InstallerSwitches` child whose complete value is identical to the WinGet default. Missing children are populated independently.
- If a package needs a different value, explicitly write the complete replacement for that child. WinGet does not merge command-line tokens with the default value.
- Keep `/norestart` or an equivalent no-reboot argument in custom `Silent` and `SilentWithProgress` replacements.
- Keep mode-independent public properties or behavior arguments in `InstallerSwitches.Custom`.
- Omit `ExpectedReturnCodes` unless the package adds behavior not represented by WinGet's built-in MSI return-code mapping.

These defaults come from winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

## Apps & Features

Use [visible ARP analysis](analysis.md#identify-the-visible-arp-entry) to distinguish the native MSI entry from custom or hidden registration. Do not substitute metadata from a hidden entry.

## Scope and architecture

Use [scope and elevation analysis](scope-and-elevation.md) together with summary-template and payload evidence. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## Dependencies

Inspect `LaunchCondition`, `AppSearch`, `RegLocator`, and prerequisite records together rather than matching one Office-related string. A condition that blocks until Visual Studio Tools for Office Runtime is detected can justify `Microsoft.VSTOR`; a condition that blocks until Microsoft Office, Outlook, Word, Excel, or PowerPoint is detected can justify `Microsoft.Office`. Registry or add-in rows without a blocking condition prove integration, not an unconditional package dependency.

If an EXE wrapper installs the prerequisite before launching this MSI, retain the wrapper or omit the dependency for that wrapper. If the manifest selects the direct MSI instead, add every hard external prerequisite proved by the MSI or publisher. Follow the manifest-authoring [dependency workflow](../../../../author-winget-manifest/references/manifest/dependencies.md).

## VM validation
Follow [VM validation](../../workflows/vm-validation.md) when the database cannot prove visible ARP behavior, scope, elevation, UI mode, or custom actions.

## Known examples

- `NickeManarin.ScreenToGif`: WiX builder detection.
- `Housatonic.ProjectViewer365`: Advanced Installer MSI behavior.
- `Figma.Figma`: hidden MSI plus `.msq` ARP identity.
- `CatoNetworks.CatoClient`: silent-install elevation behavior.
