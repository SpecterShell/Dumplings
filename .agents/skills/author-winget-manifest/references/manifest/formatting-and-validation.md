# Manifest formatting and validation

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
# Created with YamlCreate.ps1 Dumplings Mod
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
- Manifest path splits every `PackageIdentifier` component into its own directory and ends with the exact `PackageVersion`.
- Every file begins with the exact fixed two-line header for its `ManifestType`.
- Every schema URL is versioned, matches `ManifestVersion`, and uses the latest stable schema consistently across the manifest set.
- Required fields exist in all files.
- Installer type and architecture match evidence.
- Version and ARP mapping will not cause upgrade loops.
- Install modes, elevation, success codes, expected return codes, and release date are backed by recorded evidence.
- No third-party URLs are used.
- No host execution of unknown installers occurred.
- Every applicable installer and locale field was considered; optional fields were not omitted merely because the first source lacked them.
- `UnsupportedOSArchitectures` is absent.
- Known default switches, including NSIS `/S`, are not redundantly authored.
- The complete manifest set has passed through logical-model serialization after authoring; isolated drafts have passed through `Format-WinGetManifest`.

## Iterative formatting and final validation

Parse and serialize the complete working manifest set immediately after its initial valid creation, then repeat this after each meaningful evidence-backed change. Do not wait for the final evidence pass. `ConvertTo-WinGetManifestYaml` deep-copies the logical model, removes cross-document redundancies, recomputes legal root/installer field levels, and applies schema property order. Its post-processing removes a common `InstallerLocale` and redundant fields from a sole Apps & Features entry as described above. It does not discover missing metadata or replace validation.

```powershell
Import-Module .\Modules\PackageModule\Index.ps1 -Force

$Manifest = Read-WinGetManifest -Path $ManifestDirectory
$ManifestBundle = ConvertTo-WinGetManifestYaml -Manifest $Manifest
```

Write the returned `Version`, `Installer`, and locale contents through the repository writer used by the current workflow. Review every incremental diff: meaningful evidence must remain unchanged, common installer values may move to the manifest level, redundant locale/ARP fields may disappear, and keys may be deterministically ordered according to the schema. Run ordinary validation after each saved milestone so structural mistakes are corrected while the evidence is still fresh, then perform the strict final review before submission.

`-ErrorOnWarning` deliberately turns every warning into a blocking result. Do not use it as the ordinary save mode for a reviewed family-specific exception. For example, a Chromium mini-installer can be intentionally silent without manifest `InstallerSwitches`, while schema-only validation sees only a generic `InstallerType: exe` and reports `ExeInstallerMissingSilentSwitches`. Record the static Chromium-family evidence, run normal validation, review that warning explicitly, and reserve `-ErrorOnWarning` for manifest sets expected to have no accepted warnings.

For an isolated manifest dictionary, `Format-WinGetManifest` remains available as a non-destructive formatter. It cannot perform the common-locale or locale-to-ARP comparisons because the other physical documents are not available.

For package-level processing, parse once with `Read-WinGetManifest` or `ConvertFrom-WinGetManifestYaml`. These return the logical model containing effective authored installers and separate localizations. Use `ConvertTo-WinGetManifestDocumentSet` for ordered objects, `ConvertTo-WinGetManifestYaml` for the raw multi-file bundle, and `Update-WinGetManifest` for Dumplings state updates. Singleton input is intentionally emitted as a multi-file manifest; WinGet runtime default switches and return codes are validation evidence and are never written into the logical model.
