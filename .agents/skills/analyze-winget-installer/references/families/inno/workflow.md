# Inno Setup workflow

## When to use

Use `InstallerType: inno` when WinGet invokes an Inno Setup installer directly. If the Inno installer only wraps another installer, keep `InstallerType: inno` for the invoked EXE but model Apps & Features metadata from the payload that writes the visible ARP entry.

## Detection
Route here when `Get-InnoInfo` succeeds, the installer contains the Inno loader resource `#11111`, or the analyzer returns high-confidence Inno evidence.

`Get-InnoInfo.WritesAppsAndFeaturesEntry` resolves literal `CreateUninstallRegKey` and `Uninstallable` values. It is `$null` when either directive requires compiled-code evaluation, because the runtime result cannot be inferred safely. Do not trust outer Inno ARP metadata when it is false or unresolved; route the package through wrapper/no-ARP analysis instead.

## Static analysis
1. Parse once and determine visible ARP ownership through [Inno analysis](analysis.md).
2. Select the matching [manifest shape](manifest-shapes.md).
3. Resolve architecture, scope, and silent behavior through [Scope and silent behavior](scope-and-silent.md).
4. Read [Inno internals](../../internals/inno/overview.md) only when implementing or debugging the parser.

## Manifest shape

Select the [direct, dual-scope, or nested-payload shape](manifest-shapes.md) established by static analysis. Project only fields supported by parser or VM evidence into the installer entry.

## WinGet defaults and overrides

WinGet populates missing switch fields independently for `InstallerType: inno`:

| Field | WinGet default |
| --- | --- |
| `InstallerSwitches.Silent` | `/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART` |
| `InstallerSwitches.SilentWithProgress` | `/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART` |
| `InstallerSwitches.Log` | `/LOG="<LOGPATH>"` |
| `InstallerSwitches.InstallLocation` | `/DIR="<INSTALLPATH>"` |

With standard Inno behavior, the effective install modes are `interactive`, `silent`, and `silentWithProgress`. Inno supports silent-with-progress by default through `/SILENT`.

- Omit `InstallModes` when all three modes are supported. If this installer supports a different set, write the complete array explicitly.
- Remove each `InstallerSwitches` child whose complete value equals the WinGet default. Missing children are populated independently.
- Explicitly specify the complete replacement when a child differs; WinGet does not merge command-line tokens into its default.
- Preserve `/NORESTART` or equivalent no-reboot behavior in custom silent replacements.
- Put mode-independent arguments in `Custom`, including scope selection and post-install launch suppression.
- Omit `ExpectedReturnCodes` unless the installer has behavior beyond WinGet's built-in Inno return-code mapping.

For VS Code-derived installers that expose the standard run-after-install task, suppress launch through:

```yaml
InstallerSwitches:
  Custom: /mergetasks=!runcode
```

Verify the task in the current installer or an accepted current package before retaining it. Package IDs to inspect include `Microsoft.VisualStudioCode`, `Microsoft.VisualStudioCode.Insiders`, `VSCodium.VSCodium`, `VSCodium.VSCodium.Insiders`, `Anysphere.Cursor`, `Codeium.Windsurf`, `Amazon.Kiro`, `ByteDance.Trae`, `ByteDance.Trae.CN`, `ByteDance.TraeWork`, `ByteDance.TraeWork.CN`, `Alibaba.Qoder`, `Alibaba.QoderWork`, `Tencent.CodeBuddy`, `Tencent.WorkBuddy`, `Google.Antigravity`, `Google.AntigravityIDE`, `Baidu.Comate`, `Baidu.SwanIDE`, `Huawei.QuickAppIde`, `ByteDance.DouyinIDE`, `Alibaba.MiniProgramStudio`, `EclipseFoundation.TheiaIDE`, `Alibaba.Lingma`, and `Meituan.CatPaw`.

These defaults come from winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

## Apps & Features

Use [visible ARP analysis](analysis.md#identify-the-visible-arp-owner) to identify the Apps & Features entry. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use [scope and architecture analysis](scope-and-silent.md) for compiled architecture expressions and privilege-sensitive roots. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation
Follow [VM validation](../../workflows/vm-validation.md) and the focused checks in the linked analysis pages.

## Known examples

- `ScooterSoftware.BeyondCompare.5`: dual-scope Inno installer.
- `WinSCP.WinSCP`: dual-scope behavior and explicit uninstall registration.
- `Alibaba.Quark`: architecture and scope conditions.
- `Argente.Utilities`: Inno wrapper whose nested custom payload owns ARP.
