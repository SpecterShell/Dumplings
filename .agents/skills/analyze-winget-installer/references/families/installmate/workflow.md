# InstallMate workflow

## When to use

Use `InstallerType: exe` for a structurally confirmed Tarma InstallMate package. Product strings such as `InstallMate`, `Tarma Installer`, or `Tarma Software` are routing hints, not sufficient detection evidence.

## Detection

Run `Test-InstallMate` or `Get-InstallMateInfo`. The parser requires a valid PE plus one of the source-backed package routes: an overlay-relative `tiz1` whose Zlib stream begins with `tzff` `Setup.ini`; a bounded `tiz2` RFC 1950 Zlib stream; a bounded `tiz3` raw-LZMA stream; or a bounded `tiz4` raw-LZMA2 stream in an overlay or at `+0x10` in `.tsustub`/`.tsuarch`. Every modern route must decode to a type-2 `tzf3` record containing a `tin?` database. When a launcher contains multiple TIZ archives, the unique archive with that setup database is selected.

Read [InstallMate internals](../../internals/installmate/overview.md) before changing detection, decompression, database routing, or extraction limits.

## Manifest shape

InstallMate is a generic EXE family, so WinGet supplies no family-specific switches, modes, or return-code mappings. The documented template is advisory until the current media accepts it:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallMate
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /q2 /b0
    SilentWithProgress: /q1 /b0
    InstallLocation: '"INSTALLDIR=<INSTALLPATH>"'
    Log: /log:"<LOGPATH>"
  ExpectedReturnCodes:
  - InstallerReturnCode: 5
    ReturnResponse: cancelledByUser
  - InstallerReturnCode: 9
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 11
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 12
    ReturnResponse: rebootRequiredToFinish
  - InstallerReturnCode: 13
    ReturnResponse: packageInUse
  - InstallerReturnCode: 14
    ReturnResponse: alreadyInstalled
  - InstallerReturnCode: 16
    ReturnResponse: diskFull
  - InstallerReturnCode: 20
    ReturnResponse: installInProgress
  ProductCode: <ProductCode>
```

Remove any switch, mode, return code, ProductCode, or scope that is not supported by the analyzed generation or confirmed package behavior. Install levels 2 and 3 are elevation-dependent fallback behavior and do not prove that the command line can select scope.

## Static parsing

### 1. Parse the installer once

Load PackageModule, call `Get-InstallMateInfo` once, and retain the result for every field decision:

```powershell
. .\Modules\PackageModule\Index.ps1
$Info = Get-InstallMateInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode, ProductCodeEvidence, PackageCode, Scope, DefaultScope, SupportedScopes, SupportsDualScope, InstallLevel, InstallLevelName, DefaultInstallLocation, InstallerSwitches, InstallModes, AppsAndFeaturesEntries, CanExpand, Diagnostics
$Info.ArchiveInfo
$Info.DatabaseInfo
$Info | Select-Object Components, Folders, RegistryWrites, EnvironmentChanges, Shortcuts, ExecutionActions, Prerequisites, Services
```

`ArchiveInfo.FormatVersion` preserves the two physical TIZ version words. `ArchiveInfo.BuilderFormatVersion` exposes their observed release order. Use the PE product version for package versioning; do not treat either archive value as application-version evidence.

### 2. Establish product and ARP identity

Prefer `ProductCodeEvidence` in this order: resolved legacy `Setup.ini` uninstall key, resolved typed `tin` `UninstallKey`/`ProductCode`, then the named PE `StringFileInfo.ProductCode` value. Do not scan arbitrary GUID strings. `AppsAndFeaturesEntries` combines the built-in uninstall identity with complete literal current-generation registry writes. Conditional, dynamic, incomplete, and older-generation custom registration or visibility behavior requires installed-state evidence before replacing conflicting manifest values.

Legacy `Setup.ini` media can also establish `DisplayName`, `DisplayVersion`, `Publisher`, and `DefaultInstallLocation`. Modern typed symbols are preferred over PE version strings when present. Current `tin9`, `tinA`, and `tinB` media also exposes literal registry writes, including custom ARP values and fixed 32-bit-only or 64-bit-only registry views. Preserve an existing field when the corresponding value is unresolved or a diagnostic identifies incomplete or conditional registry handling. A literal write owned by a conditional component remains evidence but is not promoted to ARP, protocol, or file-extension metadata.

### 3. Interpret scope conservatively

Legacy media uses its explicit uninstall hive or `AdminRights` field. Current controlled `tinB` media provides install levels 0 through 5. Older modern databases currently fall back to the PE requested execution level: `requireAdministrator` is machine scope, `asInvoker` is user scope, and `highestAvailable` is conditional dual-scope behavior.

Do not create separate user and machine installer entries merely because `SupportedScopes` contains both. First prove a command-line scope selector and validate each resulting ARP identity.

### 4. Expand only when needed

Omitting `-Name` expands all cataloged files. Supply a wildcard for selective extraction and use `Rename` for non-interactive internal calls:

```powershell
if ($Info.CanExpand) {
  Expand-InstallMateInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
  Expand-InstallMateInstaller -Path $InstallerPath -DestinationPath $DestinationPath -Name '*.msi' -CollisionAction Rename
}
```

InstallMate 2.x files below `<AppFolder>` are emitted at their Setup.ini-relative installed paths. Files targeting other roots go below `_destinations`. Current `tin9`, `tinA`, and `tinB` files use the decoded component/folder graph and are emitted at installed paths beneath the primary folder; destinations outside that root go below `_destinations`. An unresolved folder retains `Payload/<record-key>/<leaf-name>` as a collision-safe extraction identity, not `InstallationMetadata.Files.RelativeFilePath` evidence. `CanExpand` is false for a database revision without a verified file-record layout.

### 5. Review diagnostics and system effects

Inspect `Diagnostics`, `UnresolvedFields`, `RegistryWrites`, `EnvironmentChanges`, `Shortcuts`, `ExecutionActions`, `Prerequisites`, `Services`, `ServiceActions`, `Protocols`, and `FileExtensions`. Current `tin9`, `tinA`, and `tinB` records provide structured system-effect evidence. Only complete, unconditional registry writes with fully resolved component references feed ARP, protocol, and file-extension projection. Component and action conditions remain unevaluated. Prerequisite handlers expose `RequiresAdministrator` when that builder option is present, but this does not establish manifest `ElevationRequirement` until the handler condition and silent elevation behavior are validated. Environment entries expose install and remove actions, current-user-only behavior, update persistence, and separator values. Service entries expose resolved binary paths, arguments, service type, start type, delayed automatic start, error control, account evidence, dependencies, recovery command, localized reboot text, and recovery actions. `ServiceActions` separately reports `svca` start, stop, pause, resume, delete, and no-action operations for installation and removal, including literal arguments. Older-generation system-effect layouts remain unresolved; do not infer them from payload strings.

### 6. Apply WinGet projection

Use `Get-WinGetInstallerAnalysis` when schema-valid WinGet suggestions are needed. Keep `Family` as `InstallMate` and `InstallerType` as `exe`. Suggestions are review input; authoritative artifact evidence and VM results take precedence over the family template.

## Apps & Features

Use the resolved uninstall-key value as `ProductCode` when the package writes the built-in visible ARP entry. Current literal registry records can refine the ARP projection, but incomplete or conditional values still require installed-state evidence. Include `AppsAndFeaturesEntries` only when its name, publisher, version, installer type, or other matching fields differ materially from the package/default-locale values. Validate hidden, disabled, conditional, or dynamic uninstall registrations in the VM.

For `Tarma.PublishOrPerish` 8.19.5300.9483, isolated VM evidence found a machine-wide EXE ARP entry keyed `{D7808C1C-93A9-4369-8385-A789888ED9D7}`, with no `WindowsInstaller` value.

## Scope and architecture

Use explicit setup-database and PE execution-level evidence for scope. Derive architecture from installed payload binaries when package architecture matters; the launcher architecture alone may describe only the setup stub.

## VM validation

Follow the [VM validation workflow](../../workflows/vm-validation.md). InstallMate-specific checks are accepted `/q1`, `/q2`, `/b0`, `INSTALLDIR`, and log syntax; exit-code mappings; elevation-dependent install levels; visible and hidden ARP rows; custom registry data; associations; installed paths; and payload architecture. For install level 3, test silent behavior when all-users installation is unavailable because the interactive current-user fallback cannot be answered.

## Known examples

- `Tarma.PublishOrPerish`
- `WaveMetrics.IgorPro`

## Validation notes

The parser is statically covered by cached 2.25, 2.99, 3.2, 3.8, 5.2, 5.7, 5.9, 8.x, 9.10, 9.114, and controlled current media. Controlled InstallMate 11 fixtures cover payload-bearing TIZ2/Zlib extraction, component conditions, fixed 32-bit and 64-bit registry views, all documented environment install/remove actions and scope/separator flags, prerequisite Administrator-rights behavior, and component/folder, registry, shortcut, execution, prerequisite, service, driver-service, service-recovery, and `svca` service-control records. The `tin5` revisions between the verified 5.2 and 5.7 layouts, older-generation system-effect records, and one-off ancient downloads unavailable from Internet Archive remain explicit gaps.

## Source references

- [InstallMate setup command line](https://tarma.com/support/im9/setup/cmdline.htm)
- [InstallMate advanced build settings](https://tarma.com/support/im9/using/dialogs/build-advanced.htm)
- [InstallMate packaging](https://tarma.com/support/im11/using/packaging.htm)
- InstallMate 11 shipped help and builder data files
- [Tarma InstallMate](https://tarma.com/)
