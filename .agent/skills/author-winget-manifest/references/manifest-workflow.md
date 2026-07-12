# Installer Manifest Workflow

## Inputs

Use this reference after source discovery has produced trusted installer evidence. If installer metadata is incomplete, use the installer-analysis workflow before writing final YAML.

Expected inputs:

- Package identifier and existing manifest path, if any.
- Official `PackageUrl`, `PublisherUrl`, support URL, privacy URL, license URL, and release notes URL.
- Installer URLs, redirect chains, query-parameter stability, architectures, hashes, file sizes, signatures, and installer technology.
- Version evidence from upstream release metadata and installed ARP metadata.
- MSI/MSIX/ProductCode/UpgradeCode/PackageFamilyName where applicable.
- Silent install behavior, supported install modes, process exit codes, elevation behavior, dependencies, commands, protocols, and file extensions.
- Release-date evidence from the release source or installer HTTP response.

## File Set

Create multi-file manifests:

- `<PackageIdentifier>.yaml` with `ManifestType: version`
- `<PackageIdentifier>.installer.yaml` with `ManifestType: installer`
- `<PackageIdentifier>.locale.<default-locale>.yaml` with `ManifestType: defaultLocale`
- Optional additional locale files only when there is reliable localized metadata.

Use schema `1.12.0` by default. Preserve an older accepted schema only when updating a package and there is a specific compatibility reason.

## Version File

Set:

- `PackageIdentifier`: exact casing and segments matching the manifest path.
- `PackageVersion`: normally the installed ARP version or the version that best prevents upgrade loops.
- `DefaultLocale`: the locale of the default locale manifest, usually `en-US` unless the publisher metadata is primarily another language.
- `ManifestVersion`: `1.12.0`.

If upstream marketing version and ARP `DisplayVersion` differ, decide explicitly which value is `PackageVersion` and whether `AppsAndFeaturesEntries.DisplayVersion` is required.

## Default Locale File

Author the default-locale manifest and any additional locale manifests according to [Locale Manifest Workflow](locale-workflow.md). That reference defines every locale field, its evidence sources, localization inheritance, and the winget-pkgs conventions used by this project.

## Installer File

Required per installer:

- `Architecture`
- `InstallerType`
- `InstallerUrl`
- `InstallerSha256`

URL rules:

- Use only an official, public URL that WinGet can download without browser state, cookies, account login, form state, or expiring query parameters.
- Do not write signed/session URLs containing dynamic keys, tokens, signatures, expiry timestamps, or changing hash parameters into `InstallerUrl`.
- If an official stable URL redirects to a signed final URL, prefer the stable previous URL as `InstallerUrl`.
- If no stable public URL exists, stop manifest authoring and report that automation must capture update traffic in a VM instead.

Installer type rules:

- Use `msi` for direct MSI installers.
- Use `msix`, `appx`, `msixbundle`, or `appxbundle` for packaged app installers and include `PackageFamilyName`/`SignatureSha256` when applicable.
- Use known EXE installer types (`inno`, `nullsoft`, `burn`, `wix`) when detected.
- Use `exe` only when no more specific supported type applies and silent switches are known.
- Use `zip` with `NestedInstallerType` and `NestedInstallerFiles` for archives.
- Use `portable` only for standalone portable executables or archive-contained portable binaries that match WinGet portable policy.

Architecture rules:

- Specify the installed application architecture, not just the bootstrapper architecture.
- Use `neutral` only when the same installer and installed binaries are architecture-neutral.
- Split installers by architecture when URLs or hashes differ.

Installer locale rules:

- Add `InstallerLocale` only when two or more installer entries are differentiated by locale, such as separate locale-specific binaries, URLs, or hashes.
- Omit `InstallerLocale` for a single installer, a multilingual installer, or identical installer binaries shared across locales.
- Do not infer `InstallerLocale` from the manifest's locale files or from an installer UI language selector. It describes which locale-specific installer payload the entry represents.

Switch and behavior rules:

- Prefer WinGet defaults for known installer types.
- Add `InstallerSwitches` only when required for silent install, custom install behavior, or known publisher-specific requirements.
- Add `UnsupportedArguments` when `--location` or `--log` is known unsupported.

### InstallerSwitches

WinGet fills each missing known switch key independently. Omit a manifest switch key when its complete value is identical to the WinGet default:

| Effective installer type | `Silent` | `SilentWithProgress` | `Log` | `InstallLocation` |
| --- | --- | --- | --- | --- |
| `msi`, `wix`, `burn` | `/quiet /norestart` | `/passive /norestart` | `/log "<LOGPATH>"` | `TARGETDIR="<INSTALLPATH>"` |
| `nullsoft` | `/S` | `/S` | none | `/D=<INSTALLPATH>` |
| `inno` | `/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART` | `/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART` | `/LOG="<LOGPATH>"` | `/DIR="<INSTALLPATH>"` |
| All other effective types | none | none | none | none |

- If one key differs, include the complete replacement for that key; WinGet does not merge individual command-line tokens into an overridden value.
- Keep switches that prevent an automatic reboot in `Silent` and `SilentWithProgress`. Examples include MSI `/norestart`, Advanced Installer EXE `/norestart`, and InstallShield `/V/norestart`.
- Put behavior common to every install mode in `Custom`. In particular, post-install launch suppression belongs in `Custom`, not duplicated in the silent fields.
- Chromium mini-installer uses `Custom: --do-not-launch-chrome` when that switch is verified for the package.
- VS Code-derived Inno installers commonly use `Custom: /mergetasks=!runcode` to disable the run-after-install task. Verify the current installer before retaining it.
- Because `Custom` is appended after the selected interactive/silent switch, it applies consistently to all modes.
- Source: winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp) and [`ShellExecuteInstallerHandler`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/ShellExecuteInstallerHandler.cpp).

### InstallModes

- Apply this rule across all installer families, not only MSI/WiX.
- Omit `InstallModes` for WinGet-known installer types when WinGet's defaults accurately represent the specific installer.
- WinGet supplies default silent and silent-with-progress switches for `burn`, `wix`, `msi`, `nullsoft`, and `inno`. Inno has distinct `/VERYSILENT` and `/SILENT` defaults, so do not treat it as lacking `silentWithProgress` globally.
- Add `InstallModes` for a known type only when evidence proves that this specific installer supports a different subset from its WinGet type defaults.
- Specify it for generic `exe` and other unknown types. Most use `interactive` and `silent` because they do not distinguish silent-with-progress behavior.
- Include `silentWithProgress` for a generic type only when verified. Common examples include InstallShield EXE and Advanced Installer EXE wrappers over MSI that accept separate quiet and passive switches.
- Treat the array as an exact supported set, not a list of modes that merely appear plausible from family defaults.
- Source: winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

WinGet-known behavior:

| Effective installer type | Behavior when `InstallModes` and switches are omitted |
| --- | --- |
| `msi`, `wix`, `burn` | WinGet supplies quiet and passive MSI switches for silent and silent-with-progress operation. |
| `nullsoft` | WinGet supplies `/S` for both silent modes. |
| `inno` | WinGet supplies `/VERYSILENT` for silent and `/SILENT` for silent-with-progress, with its standard suppression/no-restart arguments. |
| `msix`, `appx` | Deployment uses the packaged-app path rather than EXE command-line switches; omit `InstallModes` unless schema/package evidence requires a restriction. |
| `portable` | No installer wizard mode applies; omit `InstallModes`. |
| `zip` | Follow the effective `NestedInstallerType`; do not infer modes from the ZIP container itself. |

### InstallerSuccessCodes And ExpectedReturnCodes

- `InstallerSuccessCodes` contains non-default process exit codes that mean installation succeeded. Do not add observed failure, cancellation, or reboot codes as success codes.
- During VM validation, record the process exit code for every interactive, silent, and silent-with-progress run that is tested, including runs that reboot, fail, or are cancelled.
- Omit `ExpectedReturnCodes` from snippets for known installer types. WinGet injects its own defaults for `burn`, `wix`, `msi`, `inno`, and `msix`.
- Add an explicit expected return code to a known type only for a package-specific addition or override not represented by WinGet's defaults.
- For a generic EXE, cancel the wizard before installation starts and record whether it returns a distinct cancellation code.
- For an EXE wrapper over MSI, determine whether it propagates MSI exit codes. If it does, mirror the complete current MSI mapping from winget-cli's `GetDefaultKnownReturnCodes`, because the outer generic `exe` type will not receive MSI defaults automatically. Use the [Windows Installer error-code reference](https://learn.microsoft.com/en-us/windows/win32/msi/error-codes) to interpret evidence.
- Do not assume a wrapper forwards the nested process exit code; verify it dynamically in the VM.
- WinGet does not inject a default expected response for a code listed in `InstallerSuccessCodes`, allowing a proven package-specific success code to override a known-type default failure interpretation.
- Source: winget-cli [`GetDefaultKnownReturnCodes`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

Default return-code families:

| Effective installer type | WinGet-provided defaults |
| --- | --- |
| `msi`, `wix`, `burn` | Windows Installer results covering install-in-progress, disk-full, service failure, reboot, cancellation, already-installed, rejected/blocked, invalid input, and unsupported language/platform cases. |
| `inno` | Exit codes `2` and `5` as `cancelledByUser`; exit code `8` as `rebootRequiredForInstall`. |
| `msix`, `appx` | Packaged-app deployment HRESULTs covering missing dependency, disk full, cancellation, already installed, downgrade, policy blocks, package in use, and unsupported system cases. |
| Other effective types | No default expected-return mapping is injected; add only package-specific, evidenced mappings. |

### ElevationRequirement

- Use `elevationProhibited` only when the installer cannot run elevated and explicitly rejects or fails elevated execution. `Spotify.Spotify` is a known example.
- Do not use `elevationProhibited` on the user-scope entry of an installer that selects user or machine scope from current privileges. This includes many install4j packages, `Git.Git`, `JetBrains.*`, and `Mozilla.*`. Otherwise an elevated WinGet process cannot prefer the machine-scope entry correctly.
- Use `elevationRequired` only when non-elevated execution is unsupported: the installer rejects it, exits immediately, or cannot proceed without elevation.
- Known elevation-required examples include `AFAS.ProfitCommunicationCenter.*`, `CatoNetworks.CatoClient`, `Corsair.iCUE.4`, `Cribl.CriblEdge`, `CrisisGo.CrisisGo`, `DisplayLink.GraphicsDriver`, `DisplayLink.GraphicsDriver.HotDesking`, `ESET.Nod32`, `ExacqTechnologies.exacqVisionClient`, `Microsoft.VCRedist.2005.*`, `NorconsultDigital.ISYLinker`, `PaloAltoNetworks.PrismaAccessBrowser`, `RealVNC.VNCServer`, `RealVNC.VNCViewer`, `Thorlabs.TSP01`, and `Thorlabs.ThorlabsDeviceSDK`.
- Use `elevatesSelf` only when the installer conditionally requests elevation itself and remains valid when initially launched without elevation.

### ReleaseDate

Use the release date in this evidence order:

1. The matching GitHub release publication date for GitHub-release sources, following the same release selection used by Dumplings GitHub tasks.
2. A version-specific official release-notes or release-history page.
3. The installer's `Last-Modified` HTTP response header when no authoritative release record is available.

Record the source of the date. Do not substitute a page update date, repository commit date, or unrelated asset timestamp.

## AppsAndFeaturesEntries

Add `AppsAndFeaturesEntries` only when WinGet would otherwise parse or match an ARP value differently from the manifest identity. Relevant differences include:

- ARP `DisplayVersion` is missing, unsortable, contains marketing text, or differs from `PackageVersion`.
- ARP `DisplayName` differs materially from `PackageName` after WinGet name normalization.
- ARP `Publisher` differs materially from default locale `Publisher`.
- The manifest `InstallerType` differs from the ARP entry technology, such as an EXE wrapper installing an MSI.
- The effective ARP installer type differs from the outer installer type.

Rules:

- Omit `DisplayVersion` when it is identical to `PackageVersion`.
- Omit `DisplayName` when the only difference from `PackageName` is a version string that WinGet normalization removes. For example, `7pace Timetracker 1.37.55247` and `7pace Timetracker` normalize to the same package name.
- Retain `DisplayName` when meaningful text survives normalization or when an architecture-bearing ARP name is required for more accurate architecture correlation.
- Keep `ProductCode` at installer level. Do not duplicate the same value in `AppsAndFeaturesEntries.ProductCode`.
- When an `AppsAndFeaturesEntries` item is needed and either the outer `InstallerType` or that item's `InstallerType` is `msi`, `wix`, or `burn`, always include its `UpgradeCode`.
- Include `InstallerType` inside `AppsAndFeaturesEntries` only when it differs from the installer node type or is needed to disambiguate.
- If a wrapper writes an EXE ARP entry and hides the MSI ARP entry, model the visible ARP entry, not only the embedded MSI.
- Do not retain an entry merely because an older manifest included redundant fields; remove it when installer-level and locale fields now match the visible ARP identity and no required mismatch remains.

## Existing Packages

When updating an existing package:

- Read the previous version's manifests before changing field style.
- Preserve established package identifier, casing, locale set, moniker, tags, and installer grouping unless evidence shows they are wrong.
- Compare new installer domains, product codes, upgrade codes, ARP names, and publisher values to previous manifests.
- Treat domain changes and identity changes as security-sensitive and report them before proceeding.
- Block updates that move an existing package from an official publisher domain to an unaffiliated GitHub mirror, personal account, third-party CDN, or aggregator unless the publisher explicitly cross-links that source.
- Do not invent a higher `PackageVersion` from third-party sites when the publisher does not publish that version. This can force `winget upgrade` to run an untrusted installer under an existing package identifier.

## Root And Installer Field Priority

Author complete installer-level entries first. Dumplings calls `Move-KeysToInstallerLevel` before processing and `Move-KeysToManifestLevel` after processing.

- A non-empty installer scalar overrides the same root scalar. Common values move to root only when every installer has the same value and none omits it.
- The priority rule applies recursively to scalar leaves inside dictionaries. A root `InstallerSwitches.Silent` can coexist with an installer-specific `Custom` or overridden `Silent` leaf.
- Arrays do not merge. A different installer-level array replaces the root array as a whole. Never combine `InstallModes`, `UnsupportedOSArchitectures`, `ExpectedReturnCodes`, or dependencies element by element.
- Dual-scope entries require complete installer-level `Scope` and scope-specific switch leaves. Never put `Scope: machine` at root when one installer entry is user scope.
- Sort properties according to `ConvertTo-SortedYamlObject`; let Dumplings promote safe common values after entries are complete.

## Shared Installer Defaults

- Use `InstallerLocale` only when separate installer files are differentiated by locale. Omit it for one installer, multilingual installers, or the same binary reused across locales.
- For WinGet-known types, omit each `InstallerSwitches` child whose complete value equals WinGet's default. Missing known children are populated independently; a non-default child must contain its complete replacement.
- Omit `InstallModes` for known types when WinGet's defaults are accurate. Add it only for a proven package-specific deviation.
- For generic EXE families, specify the verified mode set. Most support `interactive` and `silent`; add `silentWithProgress` only when a distinct progress route is proved.
- Keep no-reboot arguments in `Silent` and `SilentWithProgress`. Put mode-independent post-install launch suppression in `Custom`, such as `--do-not-launch-chrome` or `/mergetasks=!runcode`.
- Do not add `ExpectedReturnCodes` for known types when WinGet already supplies the same mappings. For generic EXE-over-MSI wrappers that propagate MSI codes, include the complete MSI mapping rather than a single observed code.
- Capture actual process exit codes during VM validation for success, cancellation, failure, and reboot cases.
- Keep all snippet values at installer level; remove unsupported fields rather than copying family examples blindly.

Minimal installer skeleton:

```yaml
# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.12.0.schema.json
PackageIdentifier: Publisher.Package
PackageVersion: 1.2.3
Installers:
- Architecture: x64
  InstallerType: <type>
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
ManifestType: installer
ManifestVersion: 1.12.0
```

## Output Checklist

Before claiming the manifest is ready:

- The source is official and cross-referenced.
- All installer hashes match downloaded files.
- Installer URLs are stable across refreshes or intentionally use a stable official redirect URL.
- Manifest path matches `PackageIdentifier` and `PackageVersion`.
- Required fields exist in all files.
- Installer type and architecture match evidence.
- Version and ARP mapping will not cause upgrade loops.
- Install modes, elevation, success codes, expected return codes, and release date are backed by recorded evidence.
- No third-party URLs are used.
- No host execution of unknown installers occurred.
