# Inno scope and silent behavior

[Back to the Inno workflow](workflow.md)

## Architecture

Use these `$Info` fields together. Inno 5.3 through 6.2 stores architecture choices as packed sets; Inno 6.3 and later stores expressions. The parser normalizes both forms:

- `ArchitecturesAllowed` and `EffectiveArchitecturesAllowed` describe supported operating-system architectures.
- `ArchitecturesInstallIn64BitMode` and its effective value identify when Inno uses 64-bit install mode.
- `SupportedArchitectures` and `UnsupportedArchitectures` contain the parser's normalized result.
- `PackedArchitecturesAllowed` and `PackedArchitecturesInstallIn64BitMode` preserve legacy raw set bytes when applicable.
- `InstallerArchitecture` is the setup stub architecture and does not by itself determine installed application architecture.

Set manifest `Architecture` from the installed payload and effective architecture expressions. Do not label a universal x86 stub as x86 when `ArchitecturesAllowed` excludes x86 and the payload is x64 or arm64. Treat operating-system compatibility as distinct from payload architecture, and never use `neutral` when binaries are installed.

If the parser warns that a future, malformed, or unknown architecture expression cannot be evaluated, inspect extracted binaries or route to the canonical [VM validation workflow](../../workflows/vm-validation.md). `UnsupportedOSArchitectures` should reflect proven exclusions, not filename guesses.

## Scope

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
- empty or contradictory values: omit `Scope` and use the canonical [VM validation workflow](../../workflows/vm-validation.md) when scope is required.

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

## Silent behavior and install modes

Compare actual installer behavior with the WinGet defaults:

- Standard Inno behavior: omit `InstallModes`, `Silent`, `SilentWithProgress`, `Log`, and `InstallLocation`.
- Scope overrides: retain `/CURRENTUSER` or `/ALLUSERS` in `Custom` on the corresponding entry.
- Post-install launch task: retain `/mergetasks=!runcode` in `Custom` only when the current installer exposes that task.
- Different silent syntax or unsupported mode: write the complete replacement child and exact `InstallModes` array.
- Custom code that detects `WizardSilent`, exits, displays an unskippable dialog, or requires license input: use the canonical [VM validation workflow](../../workflows/vm-validation.md).

Do not treat Inno generally as lacking `silentWithProgress`; `/SILENT` is its WinGet default. Preserve `/NORESTART` in any custom silent replacement.
