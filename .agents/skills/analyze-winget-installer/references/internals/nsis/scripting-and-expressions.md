# NSIS scripting, strings, and plug-ins

[Back to NSIS internals](overview.md).

NSIS source looks imperative, but several apparent language features are compile-time transformations. A reader should first decide whether behavior was resolved by MakeNSIS, encoded as a core command, or delegated to native code.

## Evaluation layers

```text
Preprocessor
  source inclusion, defines, macros, compile-time conditionals and commands

Compiler
  token parsing, file enumeration, string interning, command emission,
  label/function resolution, resource generation

Core runtime
  variables, stack, commands, jumps, callbacks, pages, sections

Plug-in runtime
  native DLL exports using the NSIS stack and API

Child processes and installed application
  outside the NSIS instruction model
```

Only the latter three can affect the target machine. Preprocessor and compiler behavior survives through emitted data, not through source-level names.

## Preprocessor

The preprocessor handles `!define`, `!include`, `!macro`, `!insertmacro`, conditional directives, compile-time file operations, and commands such as `!system`, `!packhdr`, and `!finalize`.

This layer can generate script fragments, inspect build-machine state, invoke external tools, or transform the final executable. Its decisions are already committed in the shipped binary. Reconstructing the original macro expansion is usually unnecessary and often impossible.

## Core instruction model

Runtime script is a flat command table. Functions, sections, callbacks, and labels refer to ranges or positions in that table.

```text
entry
+-- opcode
`-- six operands (stock) or eight operands (NSISBI)

control flow
+-- zero address: advance to next command
+-- nonzero address: one-based command destination
+-- call: execute destination until return
`-- abort/quit: terminate the affected path
```

Opcode numbering depends on stub configuration and edition. The command's arity and operand domains must validate after normalization.

## Compile-time macro languages

LogicLib conditionals, Sections helpers, FileFunc, WordFunc, StrFunc, x64.nsh, WinVer.nsh, and MultiUser.nsh are include libraries. They expand to core commands and plug-in calls. For example:

- `${If}` becomes comparisons and jumps;
- `${RunningX64}` commonly becomes a System call or architecture macro sequence;
- MultiUser mode becomes token, registry, path, and shell-context branches;
- electron-builder and Tauri templates become ordinary commands plus bundled helper plug-ins.

The serialized installer has no separate LogicLib or MultiUser bytecode.

## String control codes

Strings contain inline operators. The major routes are:

| Route | Language | Shell | Variable | Escaped literal |
| --- | ---: | ---: | ---: | ---: |
| NSIS 2 ANSI | `0xFF` | `0xFE` | `0xFD` | `0xFC` |
| NSIS 3 | `0x01` | `0x02` | `0x03` | `0x04` |
| Jim Park Unicode | `0xE003` | `0xE002` | `0xE001` | `0xE000` |

NSIS 2/3 ANSI payload numbers use two seven-bit bytes. Park uses a 15-bit value inside one UTF-16 code unit. A control can refer to a variable index, shell- folder encoding, or language-table index.

String expansion is recursive. Language strings can contain variables and shell folders; assigned variables can later appear in registry or path strings. A reader needs depth and cycle bounds for malformed input.

## Variables and registers

Public variables include `$0` through `$9`, `$R0` through `$R9`, and predefined paths/state. Compiler-private slots support generated sequences. All store text; integer commands parse and format text when needed.

State-changing commands include:

- `StrCpy`, `StrLen`, `StrCmp`;
- `IntOp`, `IntCmp`, `IntFmt`;
- `ReadRegStr`, `ReadEnvStr`, `ReadINIStr`;
- file and window query commands;
- `Pop`, `Push`, and `Exch`;
- plug-in returns.

Unknown values should propagate as unknown. Replacing an unresolved registry, environment, or plug-in result with an empty string can select a false branch.

## Stack and calls

The NSIS string stack serves script functions and plug-ins. Script code pushes arguments before a call and pops results afterward. System.dll also keeps private register state for `System::Store` and marshals native call operands.

The stack is global runtime state. Static interpretation must preserve it across nested function calls and bound recursive or looping control flow.

## Core conditions

Core comparisons can be simulated when both operands are known. Important details include:

- `StrCmp` can be case-sensitive or case-insensitive;
- `IntCmp` supports signed, unsigned, and 64-bit modes in current source;
- `IfFileExists` observes the target filesystem;
- flag tests read mutable silent, error, reboot, registry-view, and shell state;
- section tests observe mutable selection flags;
- window and process checks depend on runtime UI or external processes.

A condition based on unavailable target state has two reachable branches. A static reader should retain both effects or mark the result conditional.

## Registry and filesystem expressions

Registry roots can be literal HKCU/HKLM or shell-context-sensitive. Registry view is an execution flag. File paths can depend on `$INSTDIR`, `$OUTDIR`, shell folders, previous registry state, architecture checks, and plug-in output.

The command table records what the program will attempt. Whether a file already exists, a registry value is present, access is permitted, or a reboot operation succeeds belongs to target-machine state.

## Native plug-ins

The core plug-in call command identifies an extracted DLL and export. Arguments and return values use the stack and variables. Plug-ins can:

- call Windows APIs;
- create custom pages and windows;
- download files;
- launch processes or request elevation;
- read hardware, account, registry, or filesystem state;
- alter variables, flags, and control flow.

System.dll's call syntax describes native signatures and register bindings, so a small set of deterministic calls can be modeled. The same syntax can invoke any DLL, including an extracted vendor library. Static analysis must not equate a recognized System call string with safe or complete behavior.

## Architecture and scope macros

Architecture and scope support is generally compiled from macros rather than a single header field. Useful evidence includes:

- PE requested execution level;
- `SetShellVarContext` and `SetRegView` operations;
- Program Files and AppData shell variables;
- UserInfo account-type checks;
- System calls such as `IsWow64Process2` and known-folder APIs;
- MultiUser initialization and mode setters;
- separate user/machine registry writes and paths.

The loader PE machine alone does not establish package architecture or scope.

## Generator templates

electron-builder and Tauri publish source templates, which makes their compiled sequences suitable for source-backed recognition. A generator can still include custom macros and plug-ins. Detection should identify the standard template route and list deviations rather than assume every installer built by the same tool has identical scope, architecture, or silent behavior.

## Source references

- [NSIS script parser](https://github.com/NSIS-Dev/nsis/blob/master/Source/script.cpp)
- [NSIS command enumeration](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.h)
- [NSIS command interpreter](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/exec.c)
- [NSIS preprocessor](https://nsis.sourceforge.io/Docs/Chapter5.html)
- [NSIS variables and stack](https://nsis.sourceforge.io/Docs/Chapter4.html)
- [System plug-in](https://nsis.sourceforge.io/Docs/System/System.html)
- [electron-builder NSIS templates](https://github.com/electron-userland/electron-builder/tree/master/packages/app-builder-lib/templates/nsis)
- [Tauri NSIS templates](https://github.com/tauri-apps/tauri/tree/dev/crates/tauri-bundler/src/bundle/windows/nsis)
