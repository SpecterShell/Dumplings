# Inno static analysis

[Back to the Inno workflow](workflow.md)

## Parse the Inno metadata once

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
$Info.EditionId
$Info.CharacterMode
$Info.RegistryWrites
$Info.FileExtensions
$Info.Protocols
$Info.MetadataRecordCounts
$Info.PascalScriptInfo
$Info.ParserVersionInfo
$Info.Warnings
```

`Get-InnoInfo` also returns `AppName`, `AppVerName`, `AppVersion`, `AppId`, `ResolvedAppId`, `UninstallRegKeyBaseName`, `UninstallDisplayName`, raw directive values, unresolved constants/fields, privilege directives, architecture expressions or packed architecture sets, encryption evidence, loader signature, and `ParserVersionInfo`. Reuse these properties throughout the analysis.

`PascalScriptInfo` is the bounded `[Code]` header view: presence, byte length, IFPS version, declared type/global/function counts, entry-point index, and import size. It is null only when an embedded program header could not be validated; `Present: false` means the selected structure has no compiled program. Official Inno structures before 4.0 do not serialize `CompiledCodeText`, while the My Inno Setup Extensions line introduced it earlier.

Request detailed script evidence in the same top-level parse when header fields contain `{code:...}` constants or script behavior affects scope, silent installation, registry writes, process launches, restart behavior, or downloads:

```powershell
$Info = Get-InnoInfo -Path $InstallerFile -IncludePascalScriptAnalysis
$ScriptInfo = Get-InnoPascalScriptInfo -Path $InstallerFile
$Disassembled = Get-InnoPascalScriptInfo -Path $InstallerFile -IncludeDisassembly -MaximumDisassemblyCharacters 4194304
```

The detailed result contains typed functions, arguments, direct call edges, string constants, external declarations, DLL imports, and calls grouped by manifest-relevant effect. `StaticReturnValues` contains only straight-line functions whose complete body proves one constant return. Those values can resolve matching setup-header `{code:Function}` strings, recorded in `ResolvedPascalCodeConstants`. A branch, call, pointer, indexed operand, exception path, unknown opcode, or nonconstant input leaves the function unresolved.

The disassembly is static evidence, not decompiled Pascal source or an emulator result. Treat unresolved registry writes, process launches, privilege checks, indirect calls, and external DLL effects as VM-validation inputs.

Do not follow `$Info` with `Read-ProductVersionFromInno`, `Read-ProductNameFromInno`, `Read-PublisherFromInno`, `Read-ProductCodeFromInno`, `Test-InnoDualScope`, `Read-SupportedScopesFromInno`, `Read-UnsupportedArchitecturesFromInno`, `Test-InnoUnsupportedArchitecture`, or `Test-InnoAppsAndFeaturesEntry` for the same installer. Those convenience functions invoke `Get-InnoInfo` again.

## Identify the visible ARP owner

First use `$Info.WritesAppsAndFeaturesEntry`, `CreateUninstallRegKey`, `Uninstallable`, `CreatesUninstallRegistryKey`, and `RegistersUninstaller`:

- true and metadata matches the product: the outer Inno setup should write its own visible entry; continue with the first or dual-scope shape.
- false: treat the installer as a wrapper or no-ARP package. Do not use outer `AppId` as the manifest product code without payload/VM evidence.
- `$null`: one of the directives is dynamic. Preserve the product code only with payload or VM evidence; do not substitute the directive's default.

Use file extraction only on this branch or when architecture evidence requires it:

```powershell
$OutputDirectory = Join-Path $env:TEMP 'InnoExtract'
Expand-InnoInstaller -Path $InstallerFile -DestinationPath $OutputDirectory -Name 'nested.msi' -CollisionAction Rename
```

`Expand-InnoInstaller` performs bounded, source-backed extraction across catalogued layouts from Inno Setup 1.3.21 through 7.x. Omit `-Name` to enumerate and extract the complete validated file table, or supply an exact name/wildcard to limit work. It supports ANSI and Unicode entries, legacy and resource loaders, 32-bit and 64-bit framing, external multi-disk media, Adler32, CRC32, MD5, SHA-1, and SHA-256 verification, solid chunks, all three source-defined CALL/JMP transforms, and stored, Zlib, BZip2, LZMA, and LZMA2 payloads. Virtual roots such as `{app}` are removed while catalog subdirectories are preserved.

Prefer the narrowest useful `-Name` when only one nested payload is needed. For complete extraction, omit `-Name` and set an appropriate `-MaximumExpandedBytes`. Use `-CollisionAction Prompt|Error|Skip|Overwrite|Rename` when the installer has language aliases or duplicate destinations; interactive calls default to `Prompt`, while automation must pass `Rename`. For external media, keep official slice names beside the setup executable or pass their directories/files with `-DiskSourcePath`; missing, truncated, wrongly identified, or size-mismatched slices fail before decompression. Fully encrypted headers cannot be parsed and file-encrypted payloads still require the setup password. My Inno Setup Extensions and ResTools use explicit catalog routes. ISX is classified but extraction is rejected. Unknown future formats are accepted only when the nearest compatible descriptor consumes every required record and stream boundary exactly.

Inspect embedded `.msi`, `.msp`, `.msu`, setup `.exe`, and `[Run]`-target payloads. Route nested MSI/WiX files through `Get-MsiInstallerInfo`; route custom EXEs through their focused parser. Do not infer ownership merely because a setup-like file is embedded.

Known wrapper example: `Argente.*` uses an Inno wrapper around a custom installer and does not write the outer Inno ARP entry. Use the shared Argente task/package pattern and validate the nested component's visible ARP behavior.

## Record metadata and associations

Use `$Info.DisplayVersion`, `DisplayName`, `Publisher`, `DefaultInstallLocation`, `ProductCode`, and `AppId` as structured header evidence. Do not derive missing values from arbitrary strings. For the built-in visible ARP entry, Inno expands `AppId`, shortens ASCII values longer than 57 characters to a 48-character prefix plus `~` and CRC32, and appends `_is1`; the parser applies the same rules. `ProductCode` is null when the outer installer does not write its built-in ARP entry or when `AppId` contains unresolved runtime constants.

The parser converts deterministic directory constants to manifest-safe environment paths, including `{win}`, `{sysnative}`, `{sd}`, `{localappdata}`, `{userappdata}`, `{commonappdata}`, `{userpf}`, `{usercf}`, `{userfonts}`, `{commonfonts}`, explicit 32/64-bit Program Files/Common Files constants, and `auto*` constants when default scope and install mode make their result unambiguous. It leaves redirectable shell folders, architecture-dependent system-directory constants such as `{sys}`/`{syswow64}`, and runtime-dependent constants such as `{code:...}`, `{param:...}`, `{reg:...}`, `{ini:...}`, `{cm:...}`, `{src}`, and `{tmp}` unresolved. Check `$Info.UnresolvedFields` and `$Info.UnresolvedConstants`; Dumplings preserves the corresponding existing manifest fields instead of writing unresolved expressions.

Inno's constant expander treats `{{` outside a constant as a literal `{`. This is why an AppId compiled from `{{GUID}` becomes `{GUID}` before the uninstall key is calculated; it is not a Kiro/Qoder-specific workaround.

For Inno 6.5 and later, check `EncryptionUse`. `Files` means header metadata is readable but payload extraction requires the setup password. `Full` encrypts metadata too, so parsing fails deterministically rather than probing alternate offsets. The parser validates the encryption-header CRC before reading compressed blocks.

`RegistryWrites` contains the bounded literal records from the compiled `[Registry]` table. `FileExtensions` and `Protocols` project deterministic registrations below `HKCR` or `Software\Classes`; they exclude unresolved `{code:...}` paths. Check `MetadataTablesResolved` and `MetadataRecordCounts` before treating an empty collection as evidence that the table was empty.

Conditional records remain in `RegistryWrites` with their condition evidence and produce a warning because static parsing cannot prove that the write executes. Pascal Script, external DLLs, and application first run can create additional associations. Capture installed-state changes in the VM whenever an association is required by the manifest or the parser reports unresolved table/condition evidence.

## Build manifest fields

Select the shape from the previous routes, then apply these rules:

- Direct visible Inno ARP, one scope: use the first shape.
- Direct visible Inno ARP with command-line scope override: use the dual-scope shape.
- Nested visible MSI/WiX ARP: use the nested shape and include its `UpgradeCode`.
- Nested custom EXE ARP: retain outer `InstallerType: inno`, but add only visible overrides proved for the nested component.
- Add `AppsAndFeaturesEntries` only for a meaningful visible mismatch in installer type, name, publisher, or version.
- Keep `ProductCode` at installer level and do not duplicate it inside Apps & Features entries.
- Recheck `InstallModes` and every `InstallerSwitches` child against WinGet defaults; remove equal values and retain complete non-default replacements.
- Keep scope-specific `Custom` values on their respective installer entries.

## Escalate unresolved behavior to VM validation

Do not execute the installer on the host. Use the Hyper-V workflow when any required fact remains unresolved, especially:

- outer and nested ARP ownership cannot be proven;
- `ProductCode` is unresolved because `AppId` contains runtime constants or custom ARP behavior;
- a future or malformed header leaves privilege or architecture evidence unresolved;
- payload files are encrypted and required metadata is not available from the header;
- scope changes according to elevation/UAC rather than command-line overrides;
- custom code may reject or alter silent installation;
- extracted payload architecture conflicts with header expressions;
- protocols or file extensions are conditional, unresolved, or may be registered only by custom code or first run.

Before finishing, trace every decision to `$Info`, extracted payload evidence, a nested parser result, or recorded VM evidence.
