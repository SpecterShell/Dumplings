# Inno constants, expressions, and Pascal Script

An Inno Setup script contains several languages that run at different times. A value that looks dynamic may have been fixed by the preprocessor, expanded by Setup from a known constant, selected by a declarative expression, or calculated by arbitrary Pascal Script. Keeping these mechanisms separate is essential when reading an installer.

## Evaluation layers

```text
compiler input
+-- Inno Preprocessor directives and macros
|   `-- produce the setup script seen by ISCC
+-- setup-section parser
|   +-- serializes directive values and entry records
|   `-- compiles selector strings and event names as data
`-- Pascal Script compiler
    `-- stores [Code] as bytecode in TSetupHeader.CompiledCodeText

setup runtime
+-- expands constants in directive and entry strings
+-- evaluates version, language, component, and task selectors
+-- invokes Check, BeforeInstall, and AfterInstall handlers
`-- runs setup event functions and procedures

uninstall runtime
`-- reloads the compiled bytecode and invokes uninstall events
```

## Inno Preprocessor

The preprocessor runs before the setup compiler parses sections. It handles `#define`, `#include`, conditionals, functions, and expressions. Its output is ordinary setup-script text. A preprocessor symbol does not survive as a variable in `Setup.exe` unless the expanded text explicitly places its value in a directive, entry, message, or `[Code]` section.

For example:

```iss
#define ProductVersion "2.4.1"

[Setup]
AppVersion={#ProductVersion}
```

The installer stores `2.4.1`; it does not store a run-time `ProductVersion` binding. Source-location directives let compiler errors refer back through included files, but they do not change the setup-data model.

Compiler-side file enumeration is also final at build time. Wildcards in a `[Files]` `Source` parameter are expanded by the compiler into file entries and payload locations. The source path from the build machine is not needed during installation.

## Constants

Brace-delimited setup constants are expanded by the setup engine. They are case-insensitive where the implementation documents that behavior. A literal opening brace is written as `{{`.

Constants fall into several groups:

| Group | Examples | Depends on |
| --- | --- | --- |
| installation paths | `{app}`, `{win}`, `{sys}`, `{syswow64}`, `{tmp}`, `{src}` | selected directory, OS, process mode |
| shell folders | `{autopf}`, `{pf}`, `{commonpf}`, `{userappdata}`, `{commonappdata}`, `{userdesktop}`, `{commondesktop}` | scope and 32/64-bit install mode |
| setup state | `{language}`, `{wizardhwnd}`, `{log}`, `{group}`, `{username}`, `{computername}` | active language, UI, logging, user data |
| installer files | `{srcexe}`, `{uninstallexe}` | source path and generated uninstall filename |
| environment and registry | `{%NAME|default}`, `{reg:root\key,value|default}` | target-machine state |
| string transforms | `{cm:MessageName,...}`, `{code:Function|parameter}` | messages or Pascal Script |

`{app}` cannot be resolved until the final wizard directory is known. `{autopf}` and similar automatic constants choose a per-user or common shell folder from the effective administrative install mode. `{pf}` and `{cf}` also interact with 64-bit install mode in current versions.

The same stored expression can therefore expand differently for two installer entries that represent different scopes, or on machines with different architecture and registry state.

### Expansion contexts

Setup does not expand every value once at startup. Expansion occurs near the operation that consumes the value. This matters for constants backed by mutable state or code.

Examples:

- `DefaultDirName` is expanded while constructing or restoring the directory-page value.
- `[Files]` destinations are expanded while files are processed.
- ARP values are expanded when the uninstall key is created, after scope, language, directory, and uninstall filename have stabilized.
- `[Run]` parameters are expanded immediately before a process is launched.
- uninstall entries can be stored in the log as already expanded values so the uninstaller can replay the exact inverse action.

An expansion error can be fatal, ignored by a specific call site, or converted into a skipped operation. The call site, not the constant syntax alone, determines failure behavior.

## Version and platform conditions

Entry records can carry minimum and maximum Windows-version bounds. The setup engine compares them with the running system before performing the entry. Architecture admission is separately controlled by `ArchitecturesAllowed`; 64-bit installation behavior is controlled by `ArchitecturesInstallIn64BitMode`.

These are distinct questions:

```text
Can Setup run on this machine?
`-- ArchitecturesAllowed and OS version bounds

Should this installation use 64-bit paths and registry views?
`-- ArchitecturesInstallIn64BitMode

Should this particular entry use 32-bit or 64-bit behavior?
`-- entry flags plus current install mode
```

An x86 SetupLdr can install x64 application files. PE architecture of the outer executable does not establish package architecture.

## Languages, components, and tasks

Most operational entries inherit a condition header containing language, component, and task expressions.

Language expressions select internal `[Languages]` names. Component and task expressions support logical combinations and wildcard-like hierarchical matching. Component names and task names use backslash-separated trees, such as `server\service`.

The active selections are built from several inputs:

- the selected setup type;
- fixed, exclusive, restart, and inherited component/task flags;
- previous installation data;
- `/COMPONENTS=`, `/TASKS=`, and `/MERGETASKS=`;
- INF values;
- user choices and Pascal Script changes.

The final selected set is the input to entry filtering. A command-line string by itself is not proof that an entry runs.

## `Check`, `BeforeInstall`, and `AfterInstall`

Entries can refer to Pascal Script functions and procedures:

```iss
[Files]
Source: "tool.exe"; DestDir: "{app}"; Check: ShouldInstallTool; \
  BeforeInstall: PrepareTool; AfterInstall: FinishTool
```

`Check` is evaluated after component, task, and language filters. A false result skips the entry. `BeforeInstall` and `AfterInstall` run around the associated operation. These attributes store callable expressions, not their eventual return values or side effects.

The expression grammar permits parameterized calls and Boolean combinations in contexts supported by the compiler. The compiler validates names and signatures against the script program, but target-machine state remains unknown until execution.

## Pascal Script bytecode

The `[Code]` section is compiled with the RemObjects Pascal Script-derived engine shipped in Inno Setup. `CompiledCodeText` is stored as an `AnsiString` even in Unicode Inno versions because it is a bytecode blob, not user text.

At runtime Setup creates a script runner, registers built-in functions, classes, constants, types, and event signatures, then loads the blob. The host API covers much more than wizard customization:

- file and directory reads, writes, copies, deletions, and searches;
- registry and INI reads and writes;
- process execution, shell execution, and process waiting;
- DLL loading and exported-function calls;
- service, COM, type-library, font, and GAC-related helpers;
- environment, OS, architecture, privilege, and command-line inspection;
- download and extraction facilities in versions that support them;
- wizard pages, controls, messages, selections, and progress;
- previous-data and uninstall behavior.

Static setup records remain authoritative for declarative behavior, but they are not a complete model when compiled code is present.

Dumplings uses the format catalog to locate `CompiledCodeText`. It is absent from official structures before 4.0, but appears in the earlier My Inno Setup Extensions structure. Ordinary `Get-InnoInfo` validates the bounded `IFPS` header and returns its counts. It decodes the full program on demand when a manifest-relevant header value contains `{code:...}` or an ARP directive contains a dynamic check. `Get-InnoInfo -IncludePascalScriptAnalysis` requests the same analysis explicitly. `Get-InnoPascalScriptInfo` is the script-only entry point.

The decoder uses the MIT-licensed [IFPSTools.NET IFPSLib](https://github.com/Wack0/IFPSTools.NET). Its result includes the type and global tables, function signatures, direct call edges, immediate strings, external DLL/class/COM/internal declarations, and calls grouped by registry, process, silent-mode, privilege, restart, network, and filesystem effects. `-IncludeDisassembly` adds bounded instruction text.

The constant evaluator propagates primitive values through assignments, arithmetic, comparisons, unary operations, and direct jumps. Unknown conditional jumps fork isolated path states. Exploration is limited to 16 paths, eight branch levels, and bounded per-path and aggregate instruction budgets. A function is constant only when every terminal path completes and returns the same value. Divergent returns, truncated paths, calls, exception flow, pointers, indexed operands, and unknown opcodes remain unresolved.

Proven string returns expand matching `{code:Function}` header constants and appear in `ResolvedPascalCodeConstants`. Proven Boolean returns can resolve `not`, `and`, and `or` expressions used by directive checks such as `CreateUninstallRegKey` and `Uninstallable`. The result includes explored-path, fork, predicate, and truncation evidence. These fields explain why a value was accepted without presenting the evaluator as a general Pascal Script runtime.

IFPSLib currently supports bytecode versions 12 through 23. Its upstream reader interprets `Extended` constants as x86 80-bit values. A non-x86 Pascal Script runtime can use a 64-bit representation, so the evidence includes a warning when the type table contains `Extended`. The parser does not execute bytecode, infer external DLL side effects, or turn disassembly into guessed source statements.

## Setup event lifecycle

Common setup events include:

| Stage | Event | Effect |
| --- | --- | --- |
| earliest initialization | `InitializeSetup` | Returns false to terminate before the wizard. |
| password validation | `CheckPassword` | Accepts or rejects a supplied password. |
| wizard construction | `InitializeWizard` | Adds pages or changes controls and defaults. |
| page navigation | `ShouldSkipPage`, `NextButtonClick`, `BackButtonClick`, `CurPageChanged` | Changes or blocks wizard flow. |
| pre-install preparation | `PrepareToInstall` | Returns an error message and can request restart handling. |
| install progress | `CurStepChanged`, `CurInstallProgressChanged` | Runs code around installation phases. |
| restart decision | `NeedRestart` | Adds a script-defined restart requirement. |
| process exit | `GetCustomSetupExitCode`, `DeinitializeSetup` | Changes the result or performs final work. |
| ARP state | `RegisterPreviousData` | Writes additional values under the built-in uninstall key. |

Exceptions are handled according to the event. Some are fatal, some abort a step, and others are logged while Setup continues. The caller in the setup source is the authority for each event.

## Uninstall events

When compiled code exists, Setup stores it and associated expanded state in the uninstall log. The generated uninstaller loads the matching bytecode version and can invoke:

- `InitializeUninstall`;
- `ShouldSkipPage` and uninstall-page events;
- `CurUninstallStepChanged`;
- `UninstallNeedRestart`;
- `DeinitializeUninstall`.

The uninstaller also exposes a restricted setup state reconstructed from the log, including expanded application directory, group, language, messages, and install-mode flags. Code written for setup must not assume every setup-only function remains meaningful under uninstall mode.

## Why `{code:...}` cannot be reduced to a string

A code constant calls a compiled function each time its value is expanded. The function can inspect the machine, mutate state, or return different values across calls. It can also call an external DLL whose implementation is absent from the installer records.

Consequently:

- a literal value is directly recoverable;
- a built-in path constant can often be represented symbolically until scope and architecture are known;
- a registry/environment constant is conditional on the target machine;
- a code constant remains unresolved unless its complete bytecode path proves one constant return;
- an external call needs separate static inspection or VM evidence.

## Source references

- [Compiler.ScriptCompiler.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Compiler.ScriptCompiler.pas)
- [Setup.ScriptRunner.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.ScriptRunner.pas)
- [Setup.ScriptFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.ScriptFunc.pas)
- [Setup.MainFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.MainFunc.pas)
- [Setup.Install.HelperFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.Install.HelperFunc.pas)
- [IFPSTools.NET / IFPSLib](https://github.com/Wack0/IFPSTools.NET)
- [Inno Setup constants](https://jrsoftware.org/ishelp/topic_consts.htm)
