# QSetup metadata model

## Setup.txt grammar

`Setup.txt` is UTF-8 text stored as an ordinary QSetup record. Recognized directives are case-insensitive ASCII `SET_` names.

```text
SET_FLAG;
SET_NAME(value);
// comment
```

A directive without parentheses has Boolean value `true`. Explicit `0`, `false`, `no`, `off`, or `disabled` disables it. Repeated values are retained in source order because file groups, shortcuts, associations, and actions are sequences. Scalar metadata reads the first value.

Unknown directives and dynamic values remain literal evidence. The parser does not execute QSetup expressions.

## Installed file projection

`SET_SUB_DIR` changes the destination for following `SET_COPY_FILES` records. QSetup 1 and 2 separate file references with commas; later routes use pipes. A numeric physical prefix is removed from the installed name.

```text
SET_SUB_DIR(<Application Folder>\bin)
SET_COPY_FILES(00001#app.exe|00002#support.dll)

00001#app.exe -> <Application Folder>\bin\app.exe
00002#support.dll -> <Application Folder>\bin\support.dll
```

An embedded descriptor resolves to a validated record. A non-SFX descriptor resolves only from caller-supplied files or directories; `._z` companions are zlib streams. Duplicate or ambiguous companion names fail.

## Path aliases

The parser resolves deterministic Program Files, Common Files, Windows, System32, fonts, local AppData, roaming AppData, ProgramData, user profile, documents, temporary, application, common, and auxiliary aliases. Expansion runs for at most eight passes because configured roots can refer to one another. Literal `.` and `..` segments are normalized after expansion. Escape above the resolved root or an unknown dynamic alias returns no path.

## Operations

Current registry and INI records use eight pipe fields; XML records use seven. Empty leading and trailing sentinels are part of the grammar.

```text
SET_PERFORM_REGISTRY_OP(|Root\Key|ValueName|Data|SetupAction|UninstallAction|Type|)
SET_PERFORM_INIFILE_OP( |Path|Section|Name|Value|SetupAction|UninstallAction|)
SET_PERFORM_XMLFILE_OP( |Path|NodePath|Value|SetupAction|UninstallAction|)
```

The parser also accepts the historical short INI and XML directive names. Registry value types map String, Integer, Hex, MultiString, and ExpandString to Win32 kinds. Only literal `Create` and `Create if not Exist` setup actions become registry-write evidence.

`SET_ADD_ASSOCIATION_ITEM` supplies extension, ProgID, command, and icon data. Protocol projection requires a literal class key, `URL Protocol`, and an open command. Conditional or uninstall-only operations stay typed evidence and do not become authoritative manifest fields.

## Shortcuts and environment

QSetup 1 through 3 use compact comma-separated `Name,Target` shortcut records. Later historical media use compact pipe records, and current media use extended records with subfolder, parameters, working directory, window style, icon, icon index, and trailing flags. The parser reports `CompactComma`, `CompactPipe`, or `ExtendedPipe`; unisolated trailing bits remain `ObservedFlags`.

`SET_PERFORM_ENVIRONMENT_OP` uses `Name|Value|Operation|UninstallAction|Scope`. The normalized effect preserves the original scope token and setup/uninstall actions.

## Execution Engine records

Execution actions are fixed pipe-delimited arrays. Setup actions use `*` sentinels and uninstall actions use `^` sentinels.

| Route | Fields | Commands | Descriptor start | Argument start |
| --- | ---: | ---: | ---: | ---: |
| `LegacyFourCommand` | 59 or 60 | 4 | 20 | 46 |
| `TransitionalFourCommand` | 67 | 4 | 20 | 47 |
| `ModernSixCommand` | 73 | 6 | 20 | 53 |

The QSetup 6 transitional route stores condition arguments at fields 35 through 46 and retains seven observed tail fields at 59 through 65. Those tail values are exposed as `ObservedTrailingFields`; they remain uninterpreted until a non-empty controlled sample establishes their semantics.

Descriptors and arguments live in separate array regions and pair by index. The parser preserves command type, wait policy, phase, stage, parameters, and condition owner. Recognized categories cover process launch, association, registry, INI, environment, architecture state, user interaction, process control, services, COM, fonts, downloads, restarts, Windows Installer, nested execution, filesystem, security, restore points, text files, installer control, and variable state.

Conditions are classified by dependency on filesystem, installed applications, processes, services, operating system, locale, network, printer, registry, environment, hardware, user input, setup state, identity, dialogs, or variables. Host-dependent states remain unresolved. Literal unconditional modes can promote supported effects; malformed geometry produces a structured diagnostic instead of shifted fields.
