# Manifest model and files

## Inputs

Use this reference as soon as source discovery establishes a stable package identity and release. Create the first valid working manifest when `PackageIdentifier`, `PackageVersion`, `DefaultLocale`, the minimum required default-locale fields, and at least one installer's URL, SHA256, architecture, and type are known. Treat the remaining evidence below as incremental enrichment rather than a prerequisite for creating files.

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
- `<PackageIdentifier>.locale.<locale>.yaml` with `ManifestType: locale` for each optional additional locale that has reliable localized metadata.

The version filename has no manifest-type suffix. Use `<PackageIdentifier>.yaml`, never `<PackageIdentifier>.version.yaml`. Likewise, the default-locale filename uses `.locale.<default-locale>.yaml`, not `.defaultLocale.yaml`; `ManifestType` distinguishes the default locale from an additional locale. These names follow the winget-pkgs 1.12 multi-file structure and its manifest-path validation rules. See the official [YAML filename and folder structure](https://github.com/microsoft/winget-pkgs/blob/master/doc/manifest/schema/1.12.0/README.md#yaml-file-name-and-folder-structure) and [`Manifest-Path-Error` guidance](https://github.com/microsoft/winget-pkgs/blob/master/doc/ValidationFailureGuide.md#manifest-path-error).

Build the directory hierarchy by splitting `PackageIdentifier` at every dot. Preserve each component's casing and place it in its own directory. Thus, `Google.Chrome.Canary` belongs in `manifests/g/Google/Chrome/Canary/<PackageVersion>/`; neither `manifests/g/Google.Chrome.Canary/` nor `manifests/g/Google/Chrome.Canary/` is a valid identifier hierarchy. The final directory is the exact `PackageVersion`, so dots are valid there.

Use the latest stable schema accepted by winget-pkgs, currently `1.12.0`. Before authoring, verify the latest stable version in the official [winget-cli manifest schemas](https://github.com/microsoft/winget-cli/tree/master/schemas/JSON/manifests) or [winget-pkgs schema documentation](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema). If the stable version has changed, update both the schema URL and `ManifestVersion` consistently in every file.

When updating an existing package, upgrade every YAML file included in the submitted manifest set to the latest stable schema. Do not retain an older schema merely because the previous package version used it.

## Working manifest lifecycle

Create the target version leaf early. For a new package, initialize the logical model and save its minimal valid version, installer, and default-locale documents. For an update, read the latest manifest model, change the package version and initial installer coordinates, and save the new version leaf before investigating optional metadata.

Keep one working manifest set as the source of truth. After a download or parser proves installer metadata, apply it and save. After an official page proves locale, legal, release-note, or documentation fields, apply them and save. After VM validation proves scope, switches, ARP identity, exit codes, or first-run associations, apply them and save. Inspect the diff after each milestone so a later formatter or optimizer change is associated with the evidence that caused it.

Do not keep completed field values only in chat, scratch variables, or a final checklist while the manifest remains stale. Large raw evidence still belongs under `Sandbox/Evidence`; the working YAML and logical model should contain every field already proved. Omit unresolved optional fields until evidence arrives. If a required field is still unresolved, keep the pre-manifest evidence under `Sandbox/Evidence/.../manifest` and create the valid working set immediately after that blocker is resolved.

## Logical field locations

The logical model separates package identity, installer data, and localization instead of mirroring one physical YAML file:

- `PackageIdentifier`, `PackageVersion`, `Channel`, `Moniker`, and `ManifestVersion` are model-level fields. `Moniker` serializes to the default-locale document, but mutate it with `-Target Package -Path '/Moniker'`; it is not stored inside `DefaultLocalization`.
- `InstallerDefaults` contains fields legal at the installer-manifest root. `Installers` contains effective authored entries after those defaults are applied. Arrays remain atomic, while dictionary leaves inherit recursively.
- `DefaultLocalization` contains default-locale fields other than promoted model fields such as `Moniker`. `Localizations` contains additional locale dictionaries.

`New-WinGetManifest -InstallerDefaults` applies the supplied defaults to compatible effective installer entries before validation and serialization. With `Set-WinGetManifestValue -Target Package`, direct installer-root paths such as `/AppsAndFeaturesEntries`, `/Protocols`, or `/ReleaseDate` are routed through `InstallerDefaults` and applied across compatible installers. Use `-Target Installer` for one installer and `-Target Locale` for localized fields. Unknown package paths terminate instead of being silently discarded.

## Authoring API

For programmatic authoring, run PowerShell 7.4 or later, load `Modules/PackageModule/Index.ps1`, and operate on the logical manifest model:

```powershell
$DefaultLocalization = [ordered]@{ PackageLocale = 'en-US'; Publisher = 'Vendor'; PackageName = 'Package'; License = 'Proprietary'; ShortDescription = 'Package description.' }
$Suggestion = Get-WinGetInstallerManifestSuggestion -InstallerUrl https://downloads.example.test/setup.exe -InstallerPath C:\Installers\setup.exe -PackageVersion 1.2.3
if ($Suggestion.BlockingIssues) { throw ($Suggestion.BlockingIssues -join "`n") }
$Manifest = New-WinGetManifest -PackageIdentifier Vendor.Package -PackageVersion 1.2.3 -DefaultLocalization $DefaultLocalization -Installer $Suggestion.Installers
Save-WinGetManifest -Manifest $Manifest -Path C:\winget-pkgs\manifests\v\Vendor\Package\1.2.3
```

This initial save is a working revision, not the end of authoring. Re-read or retain `$Manifest`, apply each later locale, parser, release, and VM result through the focused mutation functions, and call `Save-WinGetManifest` again after each meaningful batch.

`New-WinGetManifest` constructs the complete logical model. `-DefaultLocalization` accepts the full default-locale dictionary, not a locale tag. `-Installer` accepts one or more complete effective installer dictionaries, and `-Localization` accepts additional locale dictionaries. The function has no `-Target`, `-PackageLocale`, or `-ManifestType` parameter; target selectors belong to the focused mutation functions, while serialization derives each physical manifest type from the logical model.

- Call `Get-WinGetInstallerManifestSuggestion` once per physical installer and reuse its `Installers` and `Analysis` output. Do not follow it with individual `Read-*` parser calls.
- Treat `BlockingIssues` as hard stops. Review `Suggestions` manually; they are intentionally not authored because the evidence is heuristic, ambiguous, first-run-only, or requires VM validation.
- Use `Add-WinGetManifestInstaller`, `Set-WinGetManifestInstaller`, and `Remove-WinGetManifestInstaller` for effective installer entries. Exact-match selectors must identify one entry.
- Use `Add-WinGetManifestLocale`, `Set-WinGetManifestLocale`, and `Remove-WinGetManifestLocale` for locale dictionaries. Locale tags match case-insensitively and the default locale cannot be removed.
- Use `Set-WinGetManifestValue` and `Remove-WinGetManifestValue` for focused RFC 6901 property paths. Numeric segments traverse existing array items, so `/AppsAndFeaturesEntries/0/DisplayName` addresses the first entry. Arrays do not merge, and adding or removing an array item requires replacing the parent array.
- Use exported `ConvertTo-WinGetAuthoringDictionary` when a `PSCustomObject` must become a detached ordered dictionary. Existing ordered dictionaries and other `IDictionary` values can be passed directly.
- `Save-WinGetManifest` serializes, optimizes, validates, stages, and atomically replaces a complete leaf directory. When the path is under a directory named `manifests`, it verifies the first-letter, identifier-component, and version hierarchy before writing. Use `-ErrorOnWarning` only when every warning must block, and use `-WhatIf` before an unfamiliar mutation.
- `Modules/PackageModule/Utilities/WinGetManifest.ps1` exposes the same workflow as a thin CLI with `new`, installer/locale/value operations, `validate`, and `show`. It never submits manifests or executes installers.

`Save-WinGetManifest` runs `Optimize-WinGetManifest` before serialization. A sole `AppsAndFeaturesEntries` item loses `ProductCode` when it duplicates installer-level `ProductCode`, and loses `DisplayName` or `Publisher` when WinGet normalization matches an authored locale identity. The optimizer removes the entry entirely when no meaningful override remains. These fields are editable, but redundant values are intentionally not emitted.

## Fixed Headers

Every manifest must start with exactly two comment lines followed by one blank line. Keep the first line fixed, and select the second line from the manifest type. Do not add a YamlCreate version, debug value, timestamp, agent name, or other generated text to this header.

Version manifest:

```yaml
# Created with YamlCreate.ps1 Dumplings Mod
# yaml-language-server: $schema=https://aka.ms/winget-manifest.version.1.12.0.schema.json
```

Installer manifest:

```yaml
# Created with YamlCreate.ps1 Dumplings Mod
# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.12.0.schema.json
```

Default-locale manifest:

```yaml
# Created with YamlCreate.ps1 Dumplings Mod
# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultLocale.1.12.0.schema.json
```

Additional-locale manifest:

```yaml
# Created with YamlCreate.ps1 Dumplings Mod
# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.12.0.schema.json
```

The schema family must agree with `ManifestType`: `version`, `installer`, `defaultLocale`, or `locale`. The version in the schema URL must agree with `ManifestVersion`, and all files in one manifest set must use the same version. Use a versioned schema URL in committed manifests; do not use `latest` or `preview` in the header.

## Version File

Set:

- `PackageIdentifier`: exact casing and segments matching the manifest path. For a new package, follow [Define The Package Identifier](../package/identity.md#define-the-package-identifier) before creating the directory tree.
- `PackageVersion`: normally the installed ARP version or the version that best prevents upgrade loops.
- `DefaultLocale`: the locale of the default locale manifest, usually `en-US` unless the publisher metadata is primarily another language.
- `ManifestVersion`: `1.12.0`.

If upstream marketing version and ARP `DisplayVersion` differ, decide explicitly which value is `PackageVersion` and whether `AppsAndFeaturesEntries.DisplayVersion` is required.

## Default Locale File

Author the default-locale manifest and any additional locale manifests according to [Locale manifest model](../locale/model.md). That reference defines every locale field, its evidence sources, localization inheritance, and the winget-pkgs conventions used by this project.
