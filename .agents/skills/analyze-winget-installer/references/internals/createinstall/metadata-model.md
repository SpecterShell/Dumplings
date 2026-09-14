# CreateInstall metadata model

## Evidence hierarchy

The parser prefers compiled project values and deterministic operation calls over PE version resources. PE identity remains a fallback when a project value is empty or cannot be located. Registry values reconstructed from executable code take precedence for ARP-facing display metadata because they describe what Windows receives.

| Output | Primary evidence | Fallback or unresolved rule |
| --- | --- | --- |
| `DisplayName` | visible reconstructed ARP `DisplayName`, then `MAINVAR.progname` | PE `ProductName` only when project evidence is unavailable |
| `DisplayVersion` | visible ARP value, then `MAINVAR.ver` | PE `ProductVersion` |
| `Publisher` | visible ARP value, then `MAINVAR.compname` | PE `CompanyName` |
| `ProductCode` | exactly one deterministic visible uninstall-key leaf | null for zero, multiple, dynamic, or conditional identities |
| `Scope` | deterministic uninstall root | `requireAdministrator` can establish machine when no ARP route exists; otherwise null |
| `DefaultInstallLocation` | visible ARP `InstallLocation`, then `instlocal` when the `instlocation` route flag exists, otherwise `setuppath` | null when the selected macro remains dynamic or absent |
| switches and modes | resolved `MAINVAR.silentpar` | interactive-only when empty or unresolved |

## Macro resolution

Project expressions use `#name#` references. The parser recursively follows project variables under a depth bound and converts source-backed shell folders into manifest-safe paths. Examples include `%ProgramFiles(x86)%`, `%ProgramFiles%`, `%APPDATA%`, `%LOCALAPPDATA%`, `%COMMONAPPDATA%`, `%USERPROFILE%`, `%WINDIR%`, `%SystemRoot%\System32`, the Start Menu, desktop, fonts, and temporary directory.

Unknown macros are preserved in `UnresolvedFields` and diagnostic evidence. A runtime-populated value is not replaced with the corresponding folder on the analysis host. Relative path joining uses CreateInstall's authored path/name pairs and retains unresolved components instead of normalizing them away.

## Conditions

CreateInstall's source-backed `ifcondition` route supports an optional leading `!`, project or runtime macros, and zero-argument `@function` predicates. A macro is true when its string is nonempty and is neither `0` nor `false`, case-insensitively.

The parser resolves literal project macros. It exposes unresolved `@function` evidence through `GenteeExpressions`, including the guarded operation, object and call offsets, affected fields, operation context, referenced-function bounds, literals, direct callees, decoded commands, and transitive variable candidates. It does not execute arbitrary GE bytecode.

## Installed files

`ExtractedFiles` is the physical GEA catalog. `InstalledFiles` is the source-selected projection produced from `unpackgroup` or `unpackgroupex` calls, group IDs, wildcards, destinations, overwrite flags, and conditions. An archive entry omitted by every active group is not claimed as installed. A conditional group remains conditional evidence.

The extended route carries a per-file list with overwrite, attribute, wildcard, and condition fields. The parser validates the referenced table rather than associating a table by proximity. Installed paths are normalized only after macros and source paths are resolved.

## Registry and associations

Built-in Add/Remove calls generate deterministic registry writes. `regsetsex` tables add custom `REG_SZ`, `REG_DWORD`, `REG_EXPAND_SZ`, `REG_MULTI_SZ`, or binary-style values with explicit hive, subkey, registry view, and condition evidence. Later deterministic writes override earlier writes with the same hive, view, key, and value name.

The association projector consumes only literal deterministic `Software\Classes` records. Dedicated extension calls can establish an extension and ProgID when all parts resolve. Protocols and file extensions remain empty when their commands are conditional, macro-dependent, first-run-only, or represented only by text markers.

## System effects

The parser returns typed records for shortcuts, executed EXEs and MSI packages, environment changes, Visual C++ prerequisite checks, services, fonts, COM/type libraries, .NET assembly registration, scheduled tasks, file copies, downloads, nested archive extraction, and INI changes. It preserves operation-specific options and conditions but does not execute them.

The current four-parameter environment append and delete routines have distinct source-backed literal sequences and return `Append` or `Remove`. A structurally compatible routine with an unknown sequence remains `AppendOrRemove`. Prerequisite package identifiers are candidates derived from checked Visual C++ generations and architecture; they are evidence, not automatic WinGet dependencies.

## Nested execution

`runmsiex` is decoded into MSI action, UI mode, restart policy, log path, wait behavior, source path, arguments, and condition. Ordinary run routes preserve executable, arguments, working directory, and wait behavior. A child path can be matched to `InstalledFiles` or `ExtractedFiles`, but the outer parser does not copy child ProductCode, architecture, switches, or return codes into the parent.

Downloads and nested 7z, cabinet, and ZIP operations identify content that may not exist in the outer GEA catalog. The parser reports URL, destination, filters, options, and condition where available; it never fetches a URL and does not recursively project an inner archive as installed files.

## Architecture and dependencies

The parser chooses source-selected application candidates, extracts only those files and relevant adjacent libraries into a temporary directory, and calls the shared PE architecture and dependency analyzers. `PayloadArchitectures`, `PayloadArchitectureInfo`, and `PayloadDependencyInfo` describe application payloads. `OuterArchitectureInfo` describes the setup runtime and must not be substituted for them.

Mixed or conditional payloads can produce more than one architecture. Dependency recommendations remain advisory because an imported DLL name does not prove that a separate package dependency is required or that the package's version range is correct.
