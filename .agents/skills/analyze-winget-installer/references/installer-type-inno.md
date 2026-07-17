# Inno Setup Installer Type

Switch documentation: [Inno Setup setup command line](https://jrsoftware.org/ishelp/index.php?topic=setupcmdline).

## When To Use

Use `InstallerType: inno` when WinGet invokes an Inno Setup installer directly. If the Inno installer only wraps another installer, keep `InstallerType: inno` for the invoked EXE but model Apps & Features metadata from the payload that writes the visible ARP entry.

## Detection

Route here when `Get-InnoInfo` succeeds, the installer contains the Inno loader resource `#11111`, or the analyzer returns high-confidence Inno evidence.

`Get-InnoInfo.WritesAppsAndFeaturesEntry` resolves literal `CreateUninstallRegKey` and `Uninstallable` values. It is `$null` when either directive requires compiled-code evaluation, because the runtime result cannot be inferred safely. Do not trust outer Inno ARP metadata when it is false or unresolved; route the package through wrapper/no-ARP analysis instead.

## Manifest Shape

Use this shape when [Step 2](#step-2-identify-the-visible-arp-owner) proves that the outer Inno installer writes the visible entry, [Step 4](#step-4-determine-scope) finds one supported scope, and no Apps & Features override is required. `$Info.ProductCode` is the source-derived built-in uninstall key, including Inno's `_is1` suffix. `$Info.AppId` remains available as the distinct application identity.

```yaml
Installers:
- Architecture: x64
  InstallerType: inno
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <VisibleInnoUninstallKey>
```

Apply the WinGet defaults below. Do not copy default `InstallModes` or `InstallerSwitches` into this minimal shape.

## Manifest Shape: Dual Scope

Use this shape only when `$Info.SupportsCommandLineScopeOverride` and `$Info.SupportsDualScope` are true. Inno enables `/CURRENTUSER` and `/ALLUSERS` only when `PrivilegesRequiredOverridesAllowed` includes `commandline`; `dialog` alone exposes an interactive wizard choice that WinGet cannot select reliably.

```yaml
Installers:
- Architecture: x64
  InstallerType: inno
  Scope: user
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Custom: /CURRENTUSER
  ProductCode: <VisibleInnoUninstallKey>
- Architecture: x64
  InstallerType: inno
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Custom: /ALLUSERS
  ProductCode: <VisibleInnoUninstallKey>
```

The scope switches are non-default and must remain on their respective installer entries. Preserve their supported casing. Do not use this shape for privilege-sensitive installers that change scope only according to elevation or UAC behavior.

## Manifest Shape: Nested MSI/WiX Owns Visible ARP

Use this shape when `$Info.WritesAppsAndFeaturesEntry` is false and [Step 2](#step-2-identify-the-visible-arp-owner) proves that an extracted MSI/WiX payload owns the visible entry. Use `Expand-InnoInstaller` only to obtain the required payload, then parse that MSI once with `Get-MsiInstallerInfo`.

```yaml
Installers:
- Architecture: x64
  InstallerType: inno
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <VISIBLE-MSI-PRODUCT-CODE>
  AppsAndFeaturesEntries:
  - UpgradeCode: <VISIBLE-MSI-UPGRADE-CODE>
    InstallerType: wix
```

Use `InstallerType: msi` in the Apps & Features entry when the nested package is not WiX-authored. Do not use nested MSI metadata when that MSI entry is hidden and a custom EXE entry is visible.

## WinGet Defaults And Overrides

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

## Step-By-Step Analysis

Follow the steps in order. Reuse the detailed Inno result and invoke extraction only when header metadata cannot establish wrapper ownership or installed payload architecture.

### Step 1: Parse The Inno Metadata Once

Load PackageModule and perform the complete header parse without running the installer:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InnoInfo -Path $InstallerFile
$Info.DisplayVersion
$Info.DisplayName
$Info.Publisher
$Info.ProductCode
$Info.DefaultInstallLocation
$Info.DefaultScope
$Info.SupportedScopes
$Info.SupportsDualScope
$Info.WritesAppsAndFeaturesEntry
$Info.SupportedArchitectures
$Info.UnsupportedArchitectures
$Info.EncryptionUse
$Info.CompressMethod
$Info.Warnings
```

`Get-InnoInfo` also returns `AppName`, `AppVerName`, `AppVersion`, `AppId`, `ResolvedAppId`, `UninstallRegKeyBaseName`, `UninstallDisplayName`, raw directive values, unresolved constants/fields, privilege directives, architecture expressions or packed architecture sets, encryption evidence, loader signature, and `ParserVersionInfo`. Reuse these properties throughout the analysis.

Do not follow `$Info` with `Read-ProductVersionFromInno`, `Read-ProductNameFromInno`, `Read-PublisherFromInno`, `Read-ProductCodeFromInno`, `Test-InnoDualScope`, `Read-SupportedScopesFromInno`, `Read-UnsupportedArchitecturesFromInno`, `Test-InnoUnsupportedArchitecture`, or `Test-InnoAppsAndFeaturesEntry` for the same installer. Those convenience functions invoke `Get-InnoInfo` again.

### Step 2: Identify The Visible ARP Owner

First use `$Info.WritesAppsAndFeaturesEntry`, `CreateUninstallRegKey`, `Uninstallable`, `CreatesUninstallRegistryKey`, and `RegistersUninstaller`:

- true and metadata matches the product: the outer Inno setup should write its own visible entry; continue with the first or dual-scope shape.
- false: treat the installer as a wrapper or no-ARP package. Do not use outer `AppId` as the manifest product code without payload/VM evidence.
- `$null`: one of the directives is dynamic. Preserve the product code only with payload or VM evidence; do not substitute the directive's default.

Use file extraction only on this branch or when architecture evidence requires it:

```powershell
$OutputDirectory = Join-Path $env:TEMP 'InnoExtract'
Expand-InnoInstaller -Path $InstallerFile -DestinationPath $OutputDirectory -Name 'nested.msi'
```

`Expand-InnoInstaller` performs bounded, source-backed extraction of one exact source name, destination name, or base file name from unencrypted Inno 5.3 through 7.x installers. It supports ANSI and Unicode file-entry layouts, 32-bit and 64-bit location offsets, SHA-1 and SHA-256 file verification, solid chunks, the Inno CALL/JMP transforms, and stored, Zlib, BZip2, LZMA, and LZMA2 payloads. The returned path preserves compiled destination constants such as `{app}` instead of guessing their runtime value.

Do not use `-Name '*'` as a full-unpack shortcut. Target the nested file needed for the next analysis step so unrelated solid-chunk data is discarded through a bounded stream rather than written to disk. Fully encrypted headers cannot be parsed, file-encrypted payloads require the setup password, and external disk-spanning slice files are not accepted by this path. These conditions fail deterministically; they do not imply malformed metadata.

Inspect embedded `.msi`, `.msp`, `.msu`, setup `.exe`, and `[Run]`-target payloads. Route nested MSI/WiX files through `Get-MsiInstallerInfo`; route custom EXEs through their focused parser. Do not infer ownership merely because a setup-like file is embedded.

Known wrapper example: `Argente.*` uses an Inno wrapper around a custom installer and does not write the outer Inno ARP entry. Use the shared Argente task/package pattern and validate the nested component's visible ARP behavior.

### Step 3: Determine Architecture

Use these `$Info` fields together. Inno 5.3 through 6.2 stores architecture choices as packed sets; Inno 6.3 and later stores expressions. The parser normalizes both forms:

- `ArchitecturesAllowed` and `EffectiveArchitecturesAllowed` describe supported operating-system architectures.
- `ArchitecturesInstallIn64BitMode` and its effective value identify when Inno uses 64-bit install mode.
- `SupportedArchitectures` and `UnsupportedArchitectures` contain the parser's normalized result.
- `PackedArchitecturesAllowed` and `PackedArchitecturesInstallIn64BitMode` preserve legacy raw set bytes when applicable.
- `InstallerArchitecture` is the setup stub architecture and does not by itself determine installed application architecture.

Set manifest `Architecture` from the installed payload and effective architecture expressions. Do not label a universal x86 stub as x86 when `ArchitecturesAllowed` excludes x86 and the payload is x64 or arm64. Treat operating-system compatibility as distinct from payload architecture, and never use `neutral` when binaries are installed.

If the parser warns that a future, malformed, or unknown architecture expression cannot be evaluated, inspect extracted binaries or route to Step 8. `UnsupportedOSArchitectures` should reflect proven exclusions, not filename guesses.

### Step 4: Determine Scope

Use `$Info.PrivilegesRequired` for default scope:

| `PrivilegesRequired` | Default scope |
| --- | --- |
| `none` | `user` |
| `lowest` | `user` |
| `poweruser` | `machine` |
| `admin` | `machine` |

Then route with `$Info.PrivilegesRequiredOverridesAllowed`, `SupportsCommandLineScopeOverride`, `DefaultScope`, and `SupportedScopes`:

- `commandline` present: `/CURRENTUSER` and `/ALLUSERS` are available; use the dual-scope shape.
- only `dialog` present: the wizard can ask interactively, but WinGet cannot select both scopes; do not duplicate entries.
- one supported scope: use that scope when privilege and default-directory evidence agree.
- empty or contradictory values: omit `Scope` and route to Step 8 when scope is required.

`WinSCP.WinSCP` is default-machine dual scope (`admin`, `commandline,dialog`). `LOOT.LOOT` is default-user dual scope (`lowest`, `commandline,dialog`). `Git.Git` is a privilege-sensitive special case and should not be generalized into normal command-line dual-scope behavior.

Observed dual-scope examples follow. Always verify the current installer because publishers can change Inno directives:

- `1357310795.JboxTransfer`
- `Alibaba.Quark`
- `Alibaba.QuarkCloudDrive`
- `Alibaba.UC`
- `Alibaba.UCCloudDrive`
- `Anxcye.AnxReader`
- `appmakes.Typora`
- `ArminOsaj.AutoDarkMode`
- `Balsamiq.Wireframes`
- `BartelsMedia.MacroRecorder`
- `BartelsMedia.PhraseExpress`
- `ChristianThoeing.PasswordTech`
- `CPEditor.CPEditor`
- `CrystalLang.Crystal`
- `DOSBoxStaging.DOSBoxStaging`
- `EasyTidy.EasyTidy`
- `ECSoftware.eWriterViewer`
- `ECSoftware.Help+ManualTranslationAssistant`
- `ECSoftware.HelpXplain`
- `ECSoftware.SnipSVG`
- `EngageHealth.EngageAgent`
- `Filestar.Filestar`
- `Freeplane.Freeplane`
- `fuyoo.BSRDC`
- `G3G4X5X6.ultimate-cube`
- `Gephi.Gephi`
- `GIMP.GIMP.3`
- `Greenshot.Greenshot`
- `HeidiSQL.HeidiSQL`
- `jEdit.jEdit`
- `JLC.EasyEDA.Pro`
- `JLC.LCEDA.Pro`
- `KaiKramer.KeyStoreExplorer`
- `KDE.RKWard`
- `LOOT.LOOT`
- `MacroDeck.MacroDeck`
- `maotoumao.MusicFree`
- `Meltytech.Shotcut`
- `MiniZinc.MiniZincIDE`
- `nomacs.nomacs`
- `OpenMPT.OpenMPT`
- `OpenRefine.OpenRefine`
- `OwlLabs.MeetingOwl`
- `PostgreSQL.pgAdmin`
- `Redisant.BACnetExplorer`
- `Redisant.ComtradeChart`
- `Redisant.DataAssistant`
- `Redisant.EtcdAssistant`
- `Redisant.GarnetAssistant`
- `Redisant.IEC104ClientSimulator`
- `Redisant.IEC104ServerSimulator`
- `Redisant.IEC61850ClientSimulator`
- `Redisant.IEC61850ServerSimulator`
- `Redisant.KafkaAssistant`
- `Redisant.LittleTips`
- `Redisant.ModbusMasterEmulator`
- `Redisant.ModbusSlaveEmulator`
- `Redisant.MQTTAssistant`
- `Redisant.NoSQLAssistant`
- `Redisant.OPCUAClientSimulator`
- `Redisant.PulsarAssistant`
- `Redisant.RabbitMQAssistant`
- `Redisant.RedisantToolbox`
- `Redisant.RedisAssistant`
- `Redisant.RocketMQAssistant`
- `Redisant.ZooKeeperAssistant`
- `RubyInstallerTeam.Ruby.3.2`
- `RubyInstallerTeam.Ruby.3.3`
- `RubyInstallerTeam.Ruby.3.4`
- `RubyInstallerTeam.Ruby.4.0`
- `RubyInstallerTeam.RubyWithDevKit.3.2`
- `RubyInstallerTeam.RubyWithDevKit.3.3`
- `RubyInstallerTeam.RubyWithDevKit.3.4`
- `RubyInstallerTeam.RubyWithDevKit.4.0`
- `RyanYuuki.AnymeX`
- `ScooterSoftware.BeyondCompare.5`
- `Shift.Shift`
- `SillanumSoftware.VisualAnalyser`
- `SoftDeluxe.FreeDownloadManager`
- `SpaceTime.Sheas-Cealer`
- `SpecialK.SpecialK`
- `Stellarium.Stellarium`
- `TenacityTeam.Tenacity`
- `TTYPlus.MTPuTTY`
- `VaclavSlavik.Poedit`
- `VapourSynth.VapourSynth`
- `vkbo.novelWriter`
- `WinSCP.WinSCP`
- `XiaoLan.CodexAccountSwitch`
- `Xmarmalade.AlistHelper`.

### Step 5: Determine Switches And Install Modes

Compare actual installer behavior with the WinGet defaults:

- Standard Inno behavior: omit `InstallModes`, `Silent`, `SilentWithProgress`, `Log`, and `InstallLocation`.
- Scope overrides: retain `/CURRENTUSER` or `/ALLUSERS` in `Custom` on the corresponding entry.
- Post-install launch task: retain `/mergetasks=!runcode` in `Custom` only when the current installer exposes that task.
- Different silent syntax or unsupported mode: write the complete replacement child and exact `InstallModes` array.
- Custom code that detects `WizardSilent`, exits, displays an unskippable dialog, or requires license input: route to Step 8.

Do not treat Inno generally as lacking `silentWithProgress`; `/SILENT` is its WinGet default. Preserve `/NORESTART` in any custom silent replacement.

### Step 6: Record Metadata And Associations

Use `$Info.DisplayVersion`, `DisplayName`, `Publisher`, `DefaultInstallLocation`, `ProductCode`, and `AppId` as structured header evidence. Do not derive missing values from arbitrary strings. For the built-in visible ARP entry, Inno expands `AppId`, shortens ASCII values longer than 57 characters to a 48-character prefix plus `~` and CRC32, and appends `_is1`; the parser applies the same rules. `ProductCode` is null when the outer installer does not write its built-in ARP entry or when `AppId` contains unresolved runtime constants.

The parser converts deterministic directory constants to manifest-safe environment paths, including `{win}`, `{sysnative}`, `{sd}`, `{localappdata}`, `{userappdata}`, `{commonappdata}`, `{userpf}`, `{usercf}`, `{userfonts}`, `{commonfonts}`, explicit 32/64-bit Program Files/Common Files constants, and `auto*` constants when default scope and install mode make their result unambiguous. It leaves redirectable shell folders, architecture-dependent system-directory constants such as `{sys}`/`{syswow64}`, and runtime-dependent constants such as `{code:...}`, `{param:...}`, `{reg:...}`, `{ini:...}`, `{cm:...}`, `{src}`, and `{tmp}` unresolved. Check `$Info.UnresolvedFields` and `$Info.UnresolvedConstants`; Dumplings preserves the corresponding existing manifest fields instead of writing unresolved expressions.

Inno's constant expander treats `{{` outside a constant as a literal `{`. This is why an AppId compiled from `{{GUID}` becomes `{GUID}` before the uninstall key is calculated; it is not a Kiro/Qoder-specific workaround.

For Inno 6.5 and later, check `EncryptionUse`. `Files` means header metadata is readable but payload extraction requires the setup password. `Full` encrypts metadata too, so parsing fails deterministically rather than probing alternate offsets. The parser validates the encryption-header CRC before reading compressed blocks.

The current Inno aggregate parser does not expose compiled `[Registry]` protocol and file-extension associations. Inspect extracted/static script evidence when available, otherwise capture associations during VM installation and first run. An absent static result does not prove that the application never registers an association.

### Step 7: Build The Manifest

Select the shape from the previous routes, then apply these rules:

- Direct visible Inno ARP, one scope: use the first shape.
- Direct visible Inno ARP with command-line scope override: use the dual-scope shape.
- Nested visible MSI/WiX ARP: use the nested shape and include its `UpgradeCode`.
- Nested custom EXE ARP: retain outer `InstallerType: inno`, but add only visible overrides proved for the nested component.
- Add `AppsAndFeaturesEntries` only for a meaningful visible mismatch in installer type, name, publisher, or version.
- Keep `ProductCode` at installer level and do not duplicate it inside Apps & Features entries.
- Recheck `InstallModes` and every `InstallerSwitches` child against WinGet defaults; remove equal values and retain complete non-default replacements.
- Keep scope-specific `Custom` values on their respective installer entries.

### Step 8: Escalate Unresolved Behavior To VM Validation

Do not execute the installer on the host. Use the Hyper-V workflow when any required fact remains unresolved, especially:

- outer and nested ARP ownership cannot be proven;
- `ProductCode` is unresolved because `AppId` contains runtime constants or custom ARP behavior;
- a future or malformed header leaves privilege or architecture evidence unresolved;
- payload files are encrypted and required metadata is not available from the header;
- scope changes according to elevation/UAC rather than command-line overrides;
- custom code may reject or alter silent installation;
- extracted payload architecture conflicts with header expressions;
- protocols or file extensions may be registered only by custom code or first run.

Before finishing, trace every decision to `$Info`, extracted payload evidence, a nested parser result, or recorded VM evidence.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for dual-scope routes, privilege-dependent behavior, custom silent handling, wrapper/no-ARP cases, and first-run associations not proved by the parsed script.

## Implementation Sources

- [Inno Setup](https://github.com/jrsoftware/issrc)
- [InnoUnpacker/innounp](https://github.com/jrathlev/InnoUnpacker-Windows-GUI)
- [Komac](https://github.com/russellbanks/Komac)
