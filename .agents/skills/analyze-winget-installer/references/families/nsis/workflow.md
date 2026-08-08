# NSIS workflow

## When to use

Use `InstallerType: nullsoft` when WinGet invokes an NSIS/Nullsoft installer directly. If the NSIS installer only wraps another installer, keep `InstallerType: nullsoft` for the invoked EXE but model Apps & Features metadata from the payload that writes the visible ARP entry.

## Detection
Route here when `Get-NSISInfo` succeeds, the NSIS archive first header is found at a 512-byte aligned PE overlay start with `DEADBEEF` followed by `NullsoftInst`, or the analyzer returns high-confidence NSIS evidence.

`Get-NSISInfo` also recognizes the NSISBI large-installer fork. Its parser evidence reports `ParserVersionInfo.IsNsisBi`, 64-bit data-block offsets, and external-payload flags; do not reject an otherwise valid installer merely because its documented first-header flags extend beyond upstream NSIS's `0x0F` mask.

For NSIS, the simplest wrapper test is whether the outer installer writes uninstall registry values. `Get-NSISInfo` reports only explicit uninstall registry writes recovered from the compiled script, not arbitrary version-string probing. If `WritesAppsAndFeaturesEntry` is false or nested installer payloads exist, inspect the payload or use VM ARP deltas.

Run content-based family detection before calling `Get-NSISInfo` directly. The strict parser throws when the file is not NSIS; this is a type-mismatch result rather than partial metadata failure. `Get-WinGetInstallerAnalysis` handles candidate rejection and should be the first entry point for an unknown EXE.

## Static analysis
1. Parse once and determine visible ARP ownership through [NSIS analysis](analysis.md).
2. Select the matching [manifest shape](manifest-shapes.md).
3. If Test-ElectronBuilder succeeds, inspect [electron-builder feeds](electron-builder.md).
4. Resolve architecture, scope, and silent behavior through [Scope and silent behavior](scope-and-silent.md).
5. Read [NSIS internals](../../internals/nsis/overview.md) only when implementing or debugging the parser.

## Manifest shape

Select the [direct, localized-ARP, dual-scope, or nested-payload shape](manifest-shapes.md) established by static analysis. Project only fields supported by parser or VM evidence into the installer entry.

## WinGet defaults and overrides

WinGet populates missing switch fields independently for `InstallerType: nullsoft`:

| Field | WinGet default |
| --- | --- |
| `InstallerSwitches.Silent` | `/S` |
| `InstallerSwitches.SilentWithProgress` | `/S` |
| `InstallerSwitches.InstallLocation` | `/D=<INSTALLPATH>` |
| `InstallerSwitches.Log` | No default |

With the standard behavior, the effective install modes are `interactive`, `silent`, and `silentWithProgress`. Both silent modes use `/S`, so `silentWithProgress` does not imply that an NSIS installer displays progress.

Apply these omission and override rules:

- Omit `InstallModes` when the installer supports the standard three modes. If it supports a different set, write the complete supported array explicitly.
- Remove each `InstallerSwitches` child whose complete value is identical to the WinGet default. Missing children are populated independently, so retaining one custom child does not require copying the default children.
- If the installer needs a different value, explicitly write the complete replacement for that child. WinGet replaces that field; it does not merge command-line tokens with the default value.
- Keep additional mode-independent arguments in `InstallerSwitches.Custom`, including scope selection and post-install launch suppression.
- Add `Log` only when the installer implements a verified logging switch. Nullsoft has no WinGet default for it.
- Do not add `Silent: /S`, `SilentWithProgress: /S`, or `InstallLocation: /D=<INSTALLPATH>` merely to document NSIS defaults.
- When a custom NSIS command rejects path-only quoting, VM-test whether the complete install-location switch must be quoted. `Ekahau.Capture` uses the literal argument `"/DIR=<INSTALLPATH>"`, authored as `InstallLocation: '"/DIR=<INSTALLPATH>"'` so YAML preserves the double quotes. Do not generalize this syntax to ordinary NSIS installers.

These defaults come from winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

## Apps & Features

Use [visible ARP analysis](analysis.md#identify-the-visible-arp-owner) to distinguish outer registry writes from nested payload registration. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use [scope and architecture analysis](scope-and-silent.md), including targeted scope parses for MultiUser installers. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation
Follow [VM validation](../../workflows/vm-validation.md) and the focused checks in the linked analysis pages.

## Known examples

- `CCF.CCFLink`: explicit uninstall registry metadata in compiled NSIS code.
- `CometNetwork.BitComet`: architecture-dependent ARP identities.
- `KDE.Rolisteam`: dual-scope NSIS behavior.
- `HaiYing.AionUi`: nested or custom ARP ownership requiring warning preservation.
