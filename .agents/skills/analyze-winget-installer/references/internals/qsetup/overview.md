# QSetup internals

This page records the QSetup structures consumed by Dumplings. Use the [QSetup workflow](../../families/qsetup/workflow.md) for package analysis and manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Builder and runtime model

QSetup Composer compiles a project into a native PE launcher, an ordered `Setup.txt` instruction stream, and individually compressed physical records. It can instead emit a split kernel plus an authenticated raw companion, external non-SFX payload files, or a byte-spanned setup. The original Composer project is not required at installation time. The Execution Engine reads `Setup.txt`, maps named records to destination folders, evaluates installation conditions, performs system operations, launches nested programs, and creates the configured uninstaller and Add/Remove Programs entry.

Three identities must not be conflated. The PE launcher identifies the QSetup runtime, `SET_PROG_*` and `SET_COMPANY_*` directives identify the packaged application, and `SET_ADD_REMOVE_PROGRAMS_DISPLAY_NAME` identifies the uninstall key and visible ARP name. Physical record names form a fourth namespace: `00021#Composer.exe` can install as `Composer.exe` under a destination selected by an earlier `SET_SUB_DIR` directive.

The setup launcher commonly remains x86 while `SET_ALLOWED_OS` selects QSetup's 64-bit setup state or the payload contains x64 binaries. The outer PE architecture is therefore runtime evidence, not application architecture. The parser selectively materializes the configured main executable and at most 64 adjacent DLL or .NET sidecar files under a shared byte limit, then reports payload architecture and dependency evidence separately from the launcher.

## Container layers

QSetup appends independently compressed records to a PE launcher. The overlay preamble and terminal footer changed across releases, but the record framing stayed stable in verified 1.0 through 5.0, 7.0 through 8.1, and 12.0 artifacts.

```text
PE launcher
`-- overlay
    +-- generation-specific preamble
    +-- split descriptor, optional
    +-- repeated QSetup records
    |   +-- CompressedLength, uint32 LE
    |   `-- zlib stream
    |       +-- |Name[*]?|Stamp|, ASCII
    |       +-- BodyMarker, 0x00
    |       `-- payload bytes
    +-- generation-specific footer
    +-- zero alignment, 0..7 bytes
    `-- one or more WIN_CERTIFICATE records, optional
```

Alternative media preserve the same package grammar at different physical layers:

```text
split kernel PE                         split companion
`-- overlay                             +-- generation preamble at offset 0
    +-- preamble                        +-- matching split descriptor
    +-- descriptor with companion size  +-- ordinary zlib records
    `-- zero-record footer              `-- footer with OverlayOffset = 0

spanned media
+-- setup.exe: first byte range
+-- setup.exe.001: immediate continuation
+-- setup.exe.002: immediate continuation
`-- ...: no per-part header

non-SFX media
+-- setup kernel containing Setup.txt
`-- exact external payload or payload._z files named by SET_COPY_FILES
```

The NUL after the pipe-delimited record header is framing. It must be consumed before exporting the payload; retaining it turns `MZ`, `BM`, and other file signatures into invalid `00 4D 5A`, `00 42 4D`, and equivalent output.

## Structural dispatch

The parser treats preamble, record stream, terminal structure, and `Setup.txt` as one validation chain. No individual marker is sufficient.

```text
candidate PE
+-- locate raw PE overlay
+-- choose exactly one preamble grammar
+-- validate an optional split descriptor and bind its exact companion
+-- walk adjacent length-prefixed zlib records
|   `-- validate every decoded |Name[*]?|Stamp| NUL header
+-- stop only at exact EOF or a validated footer/certificate boundary
+-- bind footer overlay offset and count to the parsed stream
`-- require Setup.txt with SET_COMPOSER_BUILD, directly or in a bounded nested setup wrapper
```

The preamble route determines where records begin. The terminal route validates where they end. `FormatGeneration` is the resulting structural label, not a value copied from `SET_COMPOSER_BUILD` or PE resources. A compatible unrepresented release can use a known route when all structural predicates pass, but its claimed version does not relax those predicates.

## Overlay preambles

### QSetup 1 and 2: direct records

```text
Base       Offset  Size  Field
---------  ------  ----  -----------------------------------------
[overlay]  0x00    4     First CompressedLength, uint32 LE
[overlay]  0x04    N     First zlib member
```

The parser accepts this route only when the first length is bounded and the following two bytes form a valid RFC 1950 zlib header.

### QSetup 3 through 5: double-pipe preamble

```text
Base       Offset  Size  Field
---------  ------  ----  -----------------------------------------
[overlay]  0x00    4     FormatVersion, uint32 LE
[overlay]  0x04    2     Magic, ASCII "||"
[overlay]  0x06    4     PreambleLength, uint32 LE
[overlay]  0x0A    N     UTF-8 pipe-delimited preamble
```

### QSetup 7 and later: versioned preamble

```text
Base       Offset  Size  Field
---------  ------  ----  -----------------------------------------
[overlay]  0x00    4     FormatVersion, uint32 LE
[overlay]  0x04    1     CompressionFormat
[overlay]  0x05    4     PreambleLength, uint32 LE
[overlay]  0x09    N     UTF-8 pipe-delimited preamble
```

The preamble begins and ends with a pipe and contains an executable-name field. QSetup 6 has no stable fixture; it must satisfy one of these structural routes rather than being assigned a route from its claimed product version.

The remaining pipe fields are preserved as preamble evidence. Their labels and use changed between releases, and the parser assigns no network, update, or executable-selection meaning beyond the validated presence of an `.exe` field. `CompressionFormat` is retained for reporting. Every verified record still uses zlib, so an unfamiliar format byte does not authorize a different decoder.

### Split-media descriptor

Current split media inserts a stored UTF-8 descriptor after the ordinary generation preamble and before the first record. A kernel descriptor has seven split fields because it includes the companion length; the companion has six because the length is already the physical stream length.

```text
Base          Offset  Size  Field
------------  ------  ----  -----------------------------------------
[descriptor]  0x00    4     DescriptorLength, uint32 LE
[descriptor]  0x04    N     |SourceDirectory|CompanionName|Mode|Secret|DeclaredLength?|
```

`CompanionName` must be a leaf filename, `Mode` and optional `DeclaredLength` are decimal, and the observed secret is 16 through 128 lowercase ASCII letters. The parser requires the main and companion preambles, secrets, and companion names to match and requires the kernel's declared length to equal the supplied file. The split companion starts at absolute offset zero and carries its own preamble, descriptor, records, and footer; it is not a PE.

## Record framing

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[record]  0x00    4     CompressedLength, uint32 LE
[record]  0x04    N     Complete zlib member
[decoded] 0x00    M     |Name[*]?|Stamp|, ASCII, at most 4096 bytes
[decoded] M       1     BodyMarker, 0x00
[decoded] M+1     ...   payload bytes
```

`*` marks a required physical record. Each record advances by exactly `4 + CompressedLength`; the decoder is bounded to that range and cannot consume the next record. Record names are physical catalog identities and commonly use a numeric prefix such as `00021#Composer.exe`.

The decoded header is limited to 4096 bytes, must use ASCII framing, and must end after the third pipe. `Name` cannot contain a pipe or `*`; `Stamp` is decimal text. QSetup does not store a separate expanded length in this outer frame, so callers that request content enforce their own output bound while `ZLibStream` validates the complete RFC 1950 member. Enumeration reads only the small decoded header. Payload bytes are decompressed only for `Setup.txt`, selective analysis, or explicit extraction.

## Terminal structures

### QSetup 1 and 2: compact footer

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[footer]  0x00    4     RecordCount, uint32 LE
[footer]  0x04    4     OverlayOffset, uint32 LE
[footer]  0x08    4     Magic, uint32 LE: 0x4A3B2C1D
```

### QSetup 3 through 8: legacy footer

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[footer]  0x00    4     FooterVersion, uint32 LE
[footer]  0x04    4     OverlayOffset, uint32 LE
[footer]  0x08    4     RecordCount, uint32 LE
[footer]  0x0C    4     Magic, uint32 LE: 0x4A3B2C1D
[footer]  0x10    4     Observed generation field, not marker 1234
[footer]  0x14    50    Observed or reserved fields
[footer]  0x46    4     FooterLength, uint32 LE: 74
```

### Current QSetup: modern footer

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[footer]  0x00    4     FooterVersion, uint32 LE
[footer]  0x04    4     OverlayOffset, uint32 LE
[footer]  0x08    4     RecordCount, uint32 LE
[footer]  0x0C    4     Magic, uint32 LE: 0x4A3B2C1D
[footer]  0x10    4     Marker, uint32 LE: 1234
[footer]  0x14    50    Version-dependent fields
[footer]  0x46    4     FooterLength, uint32 LE: 74
```

The footer offset, record count, magic, self-length, parsed record endpoint, zero alignment, and complete certificate trailer must agree. QSetup 7.5 and 8.1 samples carry a valid WIN_CERTIFICATE trailer even though the PE security directory does not declare it, so the parser validates the trailer structurally instead of relying only on the PE directory.

The compatibility `Footerless` route is accepted only when the record stream ends exactly at physical EOF. It receives no release label and cannot absorb trailing garbage. When a footer exists, a compact or 74-byte structure must consume the next exact bytes; the parser does not scan backward for magic and does not skip an unrecognized suffix.

Each certificate record uses the standard `WIN_CERTIFICATE` envelope: `dwLength:uint32 LE`, `wRevision:uint16 LE`, `wCertificateType:uint16 LE`, and certificate bytes, rounded to an eight-byte boundary. Revision must be `0x0100` or `0x0200` and type must be PKCS signed data (`2`). Every record through EOF must validate, including old QSetup media whose PE security directory omits the table.

## Setup.txt instruction stream

`Setup.txt` is UTF-8 text compiled into an ordinary QSetup record. Each recognized instruction occupies one logical line in this form:

```text
SET_FLAG;
SET_NAME(value);
// comment
```

Names are case-insensitive `SET_` identifiers containing ASCII letters, digits, and underscores. A directive without parentheses has Boolean value `true`. The optional trailing semicolon is syntax rather than data. Repeated directives are retained in source order because operations such as `SET_SUB_DIR`, `SET_COPY_FILES`, shortcuts, associations, and Execution Engine actions are sequences rather than scalar settings. Scalar metadata reads the first value. Unknown and dynamic values remain literal evidence; the parser does not execute QSetup expressions.

Explicit false values (`0`, `false`, `no`, `off`, or `disabled`) disable a Boolean directive even though the line is present. This distinction matters for uninstaller generation and ARP registration. `DirectiveRecords` retains name, value, and source line; `SetupDirectives` groups repeated values by name for scalar and collection lookup.

## Installed payload catalog

`Setup.txt` is an ordered instruction stream. `SET_SUB_DIR` selects the destination for subsequent `SET_COPY_FILES` records. QSetup 1 and 2 separate physical record names with commas; later releases use pipes. A physical name such as `00005#PDFExec.exe` maps to the installed name `PDFExec.exe`.

```text
SET_SUB_DIR(<Application Folder>\bin)
SET_COPY_FILES(00001#app.exe|00002#support.dll)

00001#app.exe -> <Application Folder>\bin\app.exe
00002#support.dll -> <Application Folder>\bin\support.dll
```

Default extraction strips the resolved application root and retains the installed relative path. Targets outside the application root are placed under `_destinations\<root>`; unresolved destinations are isolated under `_unresolved`. `-RawRecords` exports physical entries under `_qsetup\records` from the requested media layer and does not follow a nested wrapper.

`SET_SUB_DIR` is stateful. It changes the destination for following copy directives until another subdirectory directive appears. A leading decimal flag prefix before `*` is returned as `DestinationFlags` or `Flags`; observed values combine group, platform, and file-option state, but individual bits are not assigned semantics without an isolating fixture. An embedded copy descriptor resolves to a physical record. A non-SFX descriptor instead resolves an exact caller-supplied filename or `._z` form; the latter is decoded as zlib. Duplicate or ambiguous companion names fail rather than selecting by enumeration order.

## Setup directives and ARP

The parser accepts identity and installed-state evidence only from literal `SET_*` directives. Presence alone does not enable a boolean directive when its explicit value is `0`, `false`, `no`, `off`, or `disabled`.

Visible built-in ARP registration requires enabled `SET_CREATE_UNINSTALL` and `SET_ADD_UNINSTALL_TO_ADD_REMOVE_PROGRAMS`. The uninstall key and `DisplayName` use `SET_ADD_REMOVE_PROGRAMS_DISPLAY_NAME`, with `SET_PROG_NAME` as the documented fallback. `DisplayVersion`, `Publisher`, `InstallLocation`, icon, support URL, and update URL come from their corresponding literal directives. An explicit uninstaller name is normalized to an `.exe` path. When that field is blank, the parser first searches compiled shortcuts for a target whose leaf is `UnInstall_<SET_PROG_STAMP>.exe`; archived QSetup 1.0, 5.0, and 8.1 media prove this exact compiled route. If no shortcut supplies the target, the format catalog permits only generation-verified formulas: `UnInstall_<stamp>.exe` for QSetup 1–7 and `<media>_<stamp>.exe` for QSetup 12 and later. QSetup 8–11 blank-name media remain unresolved rather than inheriting an unverified formula.

The built-in uninstall key is `Software\Microsoft\Windows\CurrentVersion\Uninstall\<DisplayName>`. An explicit machine route projects HKLM and an explicit user route projects HKCU. QSetup's 64-bit setup state uses the 64-bit registry view even though the launcher remains I386; ordinary I386 media uses the 32-bit view. If scope remains conditional, the parser can retain the ProductCode identity but does not fabricate a concrete registry root or built-in registry-write set. File associations use the selected scope root when known and otherwise remain class-root evidence.

The parser emits an `AppsAndFeaturesEntries` row only for a proven visible registration. Literal custom uninstall writes take precedence over the built-in row; multiple visible custom keys remain separate entries and leave installer-level `ProductCode` unresolved. `SystemComponent=1` custom rows are retained in `CustomArpEntries` and `RegistryWrites` but excluded from visible matching. A nested MSI code in `SET_MSI_CODES`, an executed prerequisite, or PE version metadata does not replace the outer QSetup ProductCode.

## Path aliases

The parser resolves deterministic aliases including Program Files, Common Files, Windows, System32, fonts, Local AppData, roaming AppData, ProgramData, user profile, documents, temporary directory, application folder, common folder, and auxiliary folder. Separator and literal `.` or `..` segments are normalized after alias expansion. Traversal above the resolved root and dynamic or unknown `<...>` aliases return no path.

Alias expansion is recursive for at most eight passes because application, common, and auxiliary roots can refer to one another. Expansion uses manifest-safe environment variables and never substitutes values from the analyst's host. `<AbsoluteDir>` contributes no prefix but still passes through normal path and traversal validation.

## Execution Engine layouts

QSetup stores execution actions as fixed pipe-delimited arrays. Setup actions use `*` sentinels and uninstall actions use `^` sentinels.

```text
Route                     Fields  Commands  Descriptor start  Argument start
------------------------  ------  --------  ----------------  --------------
LegacyFourCommand         59/60   4         20                46
ModernSixCommand          73      6         20                53
```

Each enabled command descriptor occupies three fields and pairs with a three-field argument slot. The parser projects process-launch commands and preserves host-dependent condition descriptors instead of evaluating them. Condition predicates are classified as filesystem, application registration, process state, service, operating system, localization, network, printer, registry, environment, hardware, dependency, user interaction, installer state, user identity, dialog state, variable state, or unknown. Each condition records whether it requires runtime state or direct user interaction. Verified layouts cover QSetup 1.0, 4.0, 5.0, 7.0, 7.5, 8.1, and 12.0.

The descriptor array and argument array are physically separate. Pairing by list position is required; looking for executable-looking strings loses the command type, wait behavior, stage, and condition owner. Recognized launch commands include application, executable, batch, MSI, shell, and DLL routes, with wait and no-wait variants. `ExecutedPayloads` records the literal command, parameters, show mode, setup or uninstall phase, stage, and whether runtime conditions still control execution. Non-launch commands are classified into file-association, registry, INI, environment, architecture-state, user-interaction, process-control, service, COM-registration, font, download, restart, Windows Installer, nested-execution, filesystem, security, restore-point, text-file, installer-control, and variable-state categories.

Modern actions expose sequence and a literal `UnConditional` mode. Legacy actions lack that explicit mode and remain conditional because their environment tests cannot be evaluated from the fixed slots alone. Unconditional setup-time `Create File Association` commands can contribute an authoritative extension; conditional and uninstall-time forms remain system-effect evidence. A user-interaction predicate or command produces a dedicated manual-validation diagnostic. An action whose sentinel positions, field count, command enable flag, or slot geometry is malformed is retained as a structured incomplete diagnostic rather than partially shifted output.

## Other system effects

`SET_ADD_ASSOCIATION_ITEM` supplies literal extension, ProgID, command, and icon evidence. `SET_START_PROGRAM_LINK_ITEM` contains name, target, subfolder, parameters, working directory, window style, icon, and version-dependent trailing flags. `SET_PERFORM_ENVIRONMENT_OP` uses the observed five-field order `Name|Value|Operation|UninstallAction|Scope`.

The builder's current operation pages compile registry and INI items to eight fields and XML items to seven fields, including empty sentinels:

```text
SET_PERFORM_REGISTRY_OP(|Root\Key|ValueName|Data|SetupAction|UninstallAction|Type|)
SET_PERFORM_INI_OP(     |Path|Section|Name|Value|SetupAction|UninstallAction|)
SET_PERFORM_XML_OP(     |Path|NodePath|Value|SetupAction|UninstallAction|)
```

Registry types map `String`, `Integer`, `Hex`, `MultiString`, and `ExpandString` to the corresponding Win32 value kinds. Only literal `Create` and `Create if not Exist` setup actions become registry-write evidence. Root aliases are normalized without changing the key, deterministic path aliases are resolved inside values, and malformed field counts, roots, types, or integers produce structured diagnostics.

Association projection requires a syntactically valid extension, a literal ProgID, and a create-enabled record. It writes the extension mapping, class description, optional open command, and optional icon as registry evidence. Protocols require a literal class key with a `URL Protocol` value and an open command; they are projected from decoded registry operations rather than inferred from class names or URL-looking commands.

Shortcut records can target files or URLs. QSetup 1–3 use a compact comma-separated `Name,Target` record, later historical media use a compact pipe-delimited `|Name|Target|` record, and modern media use an extended pipe record containing subfolder, parameters, working directory, window style, icon, icon index, and version-dependent trailing flags. The parser labels these layouts `CompactComma`, `CompactPipe`, and `ExtendedPipe`; only the extended trailing values remain `ObservedFlags`. Environment operations preserve both normalized user/machine scope and the original scope token. Execution Engine commands and direct directives are projected into typed system-effect collections. Conditions remain attached to each effect and use `Unknown` when runtime state is required.

## Scope, elevation, architecture, and requirements

Scope evidence follows this order: explicit `SET_ALL_USERS` or `SET_CURRENT_USER`, PE requested execution level, then a resolved user or machine installation root. Conflicting or insufficient evidence yields no single scope. `requireAdministrator` proves an elevated route but does not by itself identify every generic registry operation's final hive.

`SET_ALLOWED_OS` can prove that the package runs only on x64 Windows, which supports `PackageArchitecture=x64` when stronger payload evidence is absent. The parser first inspects the configured main payload PE and bounded adjacent DLL and .NET sidecar set. It returns the selected files, payload architecture, imports, CLR target evidence, VC runtime evidence, and recommended package dependencies without automatically authoring them.

`SET_DOT_NET_FRAMEWORK_REQ_VER` and literal GUIDs from `SET_MSI_CODES` are prerequisite evidence. They are not automatically promoted to WinGet dependencies because the runtime can conditionally skip, download, or execute a prerequisite and because an MSI code is not necessarily the outer package's ARP identity.

## Command-line behavior

The QSetup manual defines `/hide`, `/silent`, and `/InstallDir="<path>"` for generated setups. `/hide` is the no-interface route and maps to WinGet `Silent`; `/silent` retains progress and maps to `SilentWithProgress`. The parser exposes both only when the compiled dialogs do not request user name, company, or serial information. Those fields require runtime input and make the artifact interactive-only under the documented behavior.

The Composer build process has its own success result. That result is not the generated setup process result, so the parser does not emit a non-default `InstallerSuccessCodes` value from Composer documentation. A controlled QSetup 12 `/hide` setup and its generated uninstaller both returned zero. Nested Execution Engine commands have independent switches and exit behavior and must be analyzed as separate payloads.

## Installation phases and ownership

At runtime the engine resolves scope and aliases, evaluates requirements and conditions, copies selected records, applies system operations, creates shortcuts and associations, runs stage-specific Execution Engine actions, and writes the generated uninstaller and optional ARP entry. The physical order of records supplies storage, while `Setup.txt` supplies execution and destination order. These orders need not match.

The outer QSetup runtime owns its built-in ARP entry. A nested MSI or EXE can create another visible entry, and an Execution Engine action can delegate most installation work. `ExecutedPayloads` must therefore be reviewed before treating outer metadata or switches as the application's only installed-state owner.

## Bounds and ownership

Layout and record readers accept caller-owned seekable streams and restore the layout reader’s original position. The parser bounds preamble and descriptor size, certificate size, record count, compressed record length, decoded configuration size, record-header length, nested-wrapper depth, selective payload analysis, reconstructed spanned-media size, and aggregate extraction output. Extraction resolves source and destination paths before managed I/O, rejects traversal, and delegates collision policy to the shared extraction helper.

Detection enumerates record headers without materializing bodies. `Setup.txt` is decoded under the configuration limit, and extraction opens one bounded zlib stream per selected record. Selective PE analysis materializes only the configured main executable and relevant adjacent files to an automatically deleted directory. Spanned and nested temporary media are removed before return, and returned catalogs are detached from those deleted paths. A damaged zlib member fails when its complete body is read for configuration or extraction; an incomplete footer, mismatched count, missing or unauthenticated companion, unsafe installed path, or invalid certificate envelope fails in the owning layer and is not hidden by a weaker marker fallback.

## Known gaps

- QSetup 6.x and 9.x through 11.x lack stable fixtures. They can use a known structural route only when every preamble, record, and footer invariant passes.
- No separately branded tiny or tiny-verbose grammar was found in the available QSetup 12 builder documentation. The parser supports the structurally observable form: a bounded outer QSetup record containing an inner QSetup setup, and labels it `NestedSfxWrapper` without inventing a product name for the wrapper.
- Blank-name uninstaller generation remains unresolved for QSetup 8 through 11 when no compiled uninstall shortcut exists. Exact shortcut targets are authoritative, the QSetup 1–7 fallback is `UnInstall_<stamp>.exe`, and the VM-proven QSetup 12 fallback is `<media>_<stamp>.exe`.
- Host-dependent Execution Engine predicates, arbitrary external DLL side effects, and downloaded content cannot be resolved statically. The parser classifies and reports them for VM validation.
- Trailing shortcut flags and individual bits in numeric copy and destination flag words remain observed because no fixture isolates each bit's semantics. The complete numeric values are preserved.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/QSetup.psm1`
- `Modules/PackageModule/Libraries/Installers/QSetupFormatCatalog.psd1`

## Representative fixtures

- Seventeen cached archived Pantaray builder installers cover 1.0, 2.0, 3.0, 3.5, 4.0, 5.0, 7.0, 7.5, and 8.1 structural routes.
- Pantaray QSetup 1.0.0.1, SHA256 `C9C3F625295DCB5CB3675B79DFEE8EB5C9FF9E4B7ADEB93D395AF53D40A70EFB`, establishes direct records, compact footer, comma-separated copy and shortcut lists, the legacy action layout, and the compiled `UnInstall_24376.exe` target.
- Pantaray QSetup 4.0.0.4, SHA256 `BFEC5B30D618A4624A2F1957425F7862C26238951218B4A7E4BEC07334E046FE`, establishes the double-pipe preamble and the five-field environment-operation route.
- Pantaray QSetup 5.0.0.0, SHA256 `606EF42EF079CC630F79D6E9013F65BE67EBA64E2D7AF99CEDBEA6F07089D629`, is the late observed double-pipe and legacy-action route and carries the compiled `UnInstall_17836.exe` target.
- Pantaray QSetup 8.1.0.2, SHA256 `88C8F4BD3819696C765A1FF33935BA769BE6658DB9E1334FB1CD89FCA74C189C`, establishes the versioned preamble, modern action layout, legacy footer, undeclared certificate trailer, and explicit `un_qstp.exe` uninstaller.
- Pantaray QSetup 12.0.0.5, SHA256 `E75A31A8E51757C9CA7C33EF836EAE8387139884F2C0B94A9BBD228EFA212ED7`, establishes the modern footer marker, current ARP and association directives, and more than one hundred mapped payloads.
- `AGTEK.Trackwork` 2.25.5.6, SHA256 `6EC7D39B466DF83024E1320A8755669CFA7FEB104166D615480D2FD17F42FE62`, provides a 241-record signed vendor setup with more than ten Execution Engine actions and nested VC runtime execution.
- A controlled QSetup 12 build establishes split-kernel authentication, raw split companions, non-SFX files, strict spanned concatenation, the generated `<media>_<stamp>.exe` name, 32-bit ARP view for ordinary I386 media, quoted `InstallLocation` and `UninstallString` values, and zero exit codes for `/hide` setup and generated uninstall. This research fixture remains outside source control.

## Source references

- [Pantaray QSetup manual](https://www.panta-ray.com/pdf/qsetup_manual.pdf)
- [QSetup Execution Engine](https://www.pantaray.com/execute.html)
- [QSetup execution command reference](https://www.pantaray.com/execution_cmd.html)
- [Archived QSetup builder installers](https://web.archive.org/web/*/https://www.panta-ray.com/qstp.exe)
