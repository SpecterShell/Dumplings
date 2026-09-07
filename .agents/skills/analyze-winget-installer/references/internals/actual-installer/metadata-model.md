# Actual Installer metadata model

## Configuration decoding

The parser reads `setup.ini` or `aisetup.ini` under a 4 MiB bound. Text decoding checks UTF-8, UTF-16 LE, and UTF-16 BE byte-order marks, recognizes BOM-less UTF-16, uses strict UTF-8 where possible, and falls back to the platform legacy encoding for historical media. Repeated sections merge. Later duplicate keys replace earlier values because the compiled installer treats later records as effective configuration.

The complete parsed INI is retained as `Configuration`. This is deliberate: the parser currently projects only fields whose grammar and runtime meaning are established, while preserving other records for research without assigning speculative semantics.

## Section map

| Section | Runtime role | Current parser treatment |
| --- | --- | --- |
| `[Setup]` | Identity, version, destinations, scope, elevation, architecture, uninstall policy, URLs, and options | Selected literal fields decoded |
| `[Files]` | Numeric logical payload catalog and destination expressions | Parsed and joined to physical payloads |
| `[Registry]` | Explicit registry operations and custom uninstall registration | Literal roots, names, types, values, overwrite/removal policy, and registry view decoded; complete visible uninstall groups projected separately |
| `[Extensions]` | Dedicated file-association records | Literal extensions and selected fields decoded |
| `[Shortcuts]` | Ordered shortcut definitions | Legacy path and later destination/name layouts decoded into typed records |
| `[Commands]` | Ordered command execution | File, parameters, display mode, timing, wait, OS filter, and elevation fields decoded |
| `[Variables]` | Literal and runtime-populated custom variables | Literal, registry, `GETURL`, and `GETFILE` sources classified without performing dynamic reads |
| Other sections | Dialogs, languages, updater behavior, and generation-specific settings | Preserved in `Configuration`; interpreted only when a stable grammar is established |

## Setup identity

The current parser reads field names through small precedence groups because naming changed across releases.

| Semantic value | Accepted keys |
| --- | --- |
| Display name | `AppName` |
| Application version | `AppVersion` |
| Publisher | `CompanyName`, then `Publisher` |
| Builder version | `AIVer`, then `Version`, with PE product version as a fallback |
| Product GUID | `GUID`, `Guid`, or `ProductGUID` |
| Main executable | `MainExecutable`, then `MainExe` |
| Uninstaller | `UninstallFile`, `UninstallFileName`, then `Uninstaller` |
| Publisher URL | `WebSite`, then `PublisherUrl` |
| Support URL | `SupportLink`, then `SupportUrl` |

Only a brace-delimited canonical GUID is accepted as ProductCode. The parser does not normalize arbitrary text into a GUID.

`AppVersion` can be a dynamic expression such as `<V>`. A value consisting of an unresolved variable is not application-version evidence, even when the PE itself has a literal version. The parser returns null for `DisplayVersion`, records it in `UnresolvedFields`, and emits `ActualInstaller.Metadata.DynamicVersion`.

## File table

Each non-negative numeric key becomes one logical file record.

```text
Index         parsed integer key
Destination   first field, trimmed
RecordValue   second field when present
IfExistsMode  recognized overwrite policy when present
RemoveOnUninstall recognized removal policy when present
PolicyEncoding route-specific field representation
AdditionalFields fields whose semantics remain unassigned
Fields        complete unmodified field array
```

The parser sorts by numeric index before positional cabinet mapping. It does not use dictionary insertion order as the final identity. Blank destinations and nonnumeric keys are ignored as non-file records.

For cabinet routes, a positive decimal `RecordValue` is validated against the exact physical CAB length before positional mapping. This prevents a missing generated row from shifting every later payload. Expanded records store textual if-exists and remove-on-uninstall fields. Current compact records store the if-exists list index and removal checkbox as two digits: ask, overwrite, overwrite-if-newer, or skip followed by zero or one. Early numbered-ZIP records place the if-exists index in its own field and retain the following unclassified value under `AdditionalFields`. ZIP routes use the numeric key as physical identity and reject duplicate decimal entry names.

## Registry records

Observed current rows use `*?` framing.

```text
RegistryPath *? ValueName *? Type *? Value *? Overwrite *? Remove *? View
```

The current parser requires at least path, value name, and type. It recognizes literal `HKCU`, `HKLM`, `HKCR`, and long root names. `HKEY_DEFAULT` or `HKDE` resolves to HKLM for a machine default and HKCU for a user default. Known value types are normalized to `REG_SZ`, `REG_EXPAND_SZ`, `REG_MULTI_SZ`, `REG_DWORD`, and `REG_BINARY`.

Overwrite and removal flags are exposed as booleans when recognized. `Default`, `32-bit`, and `64-bit` view tokens are normalized, although an unknown architecture enum leaves the default view unresolved. A literal root is not proof that the write will use that hive under every elevation and redirection policy; see [setup runtime](setup-runtime.md).

`RegistryOperations` retains structurally valid rows even when their key or value contains a runtime-only variable. `CanProject` is true only when both key identity and data are statically resolved; only those records enter `RegistryWrites`, ARP grouping, and the shared association projector. Literal protocol and file-class keys can therefore produce protocol or extension evidence without allowing unresolved expressions to become installed-state claims.

## Extension records

The dedicated `[Extensions]` table also uses `*?` in observed media.

```text
Legacy: Extension *? Executable *? Description *? DefaultIcon *? MakeDefault
Modern: Extension *? Executable *? Description *? Parameters *? WorkingDirectory *? IconIndex *? DefaultIcon *? MakeDefault
```

The parser validates the extension token, strips a leading dot, lowercases it, identifies the five-field or eight-field layout, resolves deterministic path variables, and preserves the raw field array. Dynamic expressions remain null in the resolved properties rather than becoming literal registry claims.

The first field of current builder media can appear as `aip`; the parser returns `aip` for manifest projection and `.aip` in the detailed association object.

## Shortcuts and commands

`[Shortcuts]` records are classified as the older complete-shortcut-path form or the later destination-and-name form. The parser returns authored and statically resolved shortcut path or destination, target, parameters, working directory, icon, icon index, display mode, and elevation fields while retaining the complete field array and source row.

`[Commands]` records return file, parameters, display mode, timing, wait behavior, operating-system filter, and administrator flag. Some 8.x and 9.x command fields use a bytewise XOR-2 transform. The parser accepts the transformed value only when it yields documented command, URL, path, switch, or installer-variable syntax; arbitrary text is never decoded merely because XOR-2 produces printable characters. A bounded evaluator resolves simple documented `IF` comparisons when both operands are literals or deterministic installer variables. Runtime operands, malformed forms, and `IFMSG` remain `Unknown`; they are never evaluated against host files, registry, environment, or network state. A command is execution evidence, not proof that a nested executable accepts the outer setup switches.

## Variables

Actual Installer variables use angle brackets. The parser resolves only deterministic variables needed for package identity and path projection.

| Variable | Static projection |
| --- | --- |
| `<ProgramFiles>` | `%ProgramFiles(x86)%` for a 32-bit project, `%ProgramFiles%` for x64-compliant media |
| `<ProgramFiles86>` | `%ProgramFiles(x86)%` |
| `<ProgramFiles64>` | `%ProgramFiles%` |
| `<CommonFiles>` | `%CommonProgramFiles(x86)%` or `%CommonProgramFiles%` by x64 compliance |
| `<AppData>` | `%APPDATA%` |
| `<LocalAppData>` | `%LOCALAPPDATA%` |
| `<CommonAppData>` | `%ProgramData%` |
| `<Windows>`, `<WindowsDir>` | `%WINDIR%` |
| `<System>`, `<SystemDir>` | `%SystemRoot%\SysWOW64` for a 32-bit project, `%SystemRoot%\System32` for x64-compliant media |
| `<SystemDir64>` | `%SystemRoot%\System32` |
| `<AppName>` | literal `AppName` |
| `<AppEdition>` | literal `AppEdition` |
| `<CompanyName>` | literal company or publisher field |
| `<Publisher>` | literal publisher or company field |
| `<AppVersion>` | literal version only |
| `<AppNameVersion>` | literal name and version joined with one space |
| `<GUID>` | canonical configured Product GUID |
| `<MainExe>`, `<MainExecutable>` | configured main executable expression |

The parser iterates deterministic substitutions with a depth limit and returns null if any angle-bracket variable remains. Explicit architecture variables remain resolvable when the generic architecture enum is unknown; generic `<ProgramFiles>`, `<CommonFiles>`, and `<System>` do not.

The builder supports many additional sources, including registry values, INI values, file content, Internet `GETURL` and `GETFILE` operations, command output, and custom variables. Typed variable records preserve those source expressions and mark them dynamic. They are never evaluated against the parser host.

## Setup policy and requirements

`SetupParameters` is tokenized so the parser can identify `-nosilent`, `-silentinstalluserinfo`, `-nocmdifsilent`, `-silentuninst`, `-useappver`, `-noChangeRootKey`, `-IgnoreRegistryWriteErrors`, and `-defdir`. These switches alter compiled runtime policy; they are not setup command-line arguments supplied by WinGet.

The `Requirements` result preserves recognized operating-system gates, Internet requirements, enabled prerequisite families and versions, running-application checks, and installed-version bounds. It does not convert prerequisite evidence directly into WinGet dependencies.

## Installation directories

The parser reads the primary installation directory and an optional alternate directory. For dual-scope configurations it selects the expression matching the compiled default scope: an AppData-rooted path for user default or a Program Files-rooted path for machine default. It then resolves only the deterministic variables above.

The resulting `DefaultInstallLocation` represents the compiled default, not every supported scope variant. `SupportedScopes`, `DefaultScope`, and `ScopeSwitches` carry the alternative route.

## Boolean values

Historical INI data spells booleans as `1/0`, `yes/no`, `true/false`, or `on/off`, case-insensitively. Unknown values use the caller's explicit default. This compatibility rule should not be extended to arbitrary strings.

## Interpretation rule

Adding a field to the raw `Configuration` does not make it safe to project. A new interpretation needs a stable table grammar, controlled builder evidence or published runtime semantics, and at least one fixture proving the relevant route. Dynamic or conditional data should remain raw plus a structured diagnostic.

## Source references

- [Actual Installer variables](https://www.actualinstaller.com/help/installer-variables.html)
- [Actual Installer setup parameters](https://www.actualinstaller.com/help/setup-parameters.html)
- [Actual Installer commands](https://www.actualinstaller.com/help/commands.html)
- [Actual Installer files and folders](https://www.actualinstaller.com/help/files-and-folders.html)
- [Actual Installer registry behavior](https://www.actualinstaller.com/help/registry.html)
