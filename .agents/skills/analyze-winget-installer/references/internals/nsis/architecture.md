# NSIS architecture

[Back to NSIS internals](overview.md).

NSIS is a compiler and a small installer operating system. MakeNSIS converts a
script into data tables and instructions, attaches them to a precompiled runtime
stub, and writes one executable. The runtime later interprets those instructions
against Windows.

## Main components

```text
Authoring installation
+-- makensis.exe / makensisw.exe
+-- Include/*.nsh macros and language files
+-- Plugins/<architecture>/*.dll
+-- Stubs/<target>/*.exe
`-- compressor implementations

Shipped installer
+-- selected executable stub
+-- customized PE resources
`-- serialized archive and payload

Target machine
+-- NSIS runtime process
+-- extracted plug-ins in $PLUGINSDIR
+-- generated uninstaller
`-- files, registry entries, shortcuts, INI state, and child processes
```

MakeNSIS owns compilation. The stub owns command-line handling, user interface,
decompression, instruction execution, plug-in loading, and uninstaller startup.
The installed application is not part of the NSIS runtime unless the script
launches it.

## Compiler targets and stubs

Current official source defines four target families:

| Target | Character mode | Runtime process |
| --- | --- | --- |
| `x86-ansi` | ANSI | 32-bit x86 |
| `x86-unicode` | UTF-16LE | 32-bit x86 |
| `amd64-unicode` | UTF-16LE | 64-bit x64 |
| `arm64-unicode` | UTF-16LE | 64-bit ARM64 |

The compiler loads the matching stub and compiles strings and plug-ins for that
target. Older official releases normally used x86 stubs. Jim Park's fork added a
Unicode line before Unicode became part of official NSIS. NSISBI changes file
and command widths to support larger payloads and optional external media.

A script may still install binaries for another architecture. `$PROGRAMFILES64`,
`RunningX64`, `IsNativeARM64`, `SetRegView`, System plug-in calls, and generator-
specific macros can select payloads independently from the stub's PE machine.

## Stub configuration is part of the ABI

`Source/exehead/config.h` controls runtime features. Many command enumeration and
header fields are guarded by compile-time definitions. Official release stubs
use known configurations, but a custom-built stub can:

- omit command families and therefore shift later opcode numbers;
- omit pages, background-font data, callbacks, uninstall support, or logging;
- include logging or fork-specific commands;
- change the target pointer width;
- reorder opcodes deliberately, as permitted by `fileform.h`.

This means a release number alone cannot select every custom layout. A reader
must validate command arity, block boundaries, string controls, and record
consumption after choosing a profile.

## Runtime state

The executable runtime maintains one process-wide state containing:

- the loaded common header and block pointers;
- predefined variables and user registers;
- the string stack used by functions and plug-ins;
- execution flags such as silent mode, errors, registry view, and shell context;
- the active page, section, callback, and instruction position;
- handles for the executable data block and, in NSISBI, external data;
- progress, logging, reboot, and quit state.

The instruction engine in `exec.c` reads one fixed-width command record at a
time. Operands are integers whose meaning depends on the opcode: string-table
offset, variable index, one-based jump address, data-block offset, packed flag,
registry root, or immediate value.

## Pages, callbacks, and sections

Pages define the user-interface route. A page record can reference pre, show,
and leave callbacks. The common header references lifecycle callbacks such as
`.onInit`, `.onInstSuccess`, `.onInstFailed`, and `.onUserAbort` when the stub was
built with callback support.

Sections contain code start and length values. The install thread executes the
selected sections in order. Silent mode removes the standard UI but still runs
callbacks and selected section code. A script or plug-in can therefore remain
interactive even when `/S` is present.

## Plug-in architecture

Plug-ins are native DLLs compiled for the stub architecture. The script compiler
emits operations that initialize `$PLUGINSDIR`, extract a DLL, and call an
export. Plug-ins receive an NSIS API structure, variable storage, and the string
stack. They can call Windows APIs or change installer state without a dedicated
NSIS opcode.

Common include files such as LogicLib compile to ordinary jumps and comparisons.
System, UserInfo, nsExec, UAC, MultiUser helpers that call native DLLs cross the
plug-in boundary. Static analysis can emulate a proven subset, but arbitrary
exports remain native code.

## Installer and uninstaller relationship

Installer and uninstaller use the same runtime architecture. During compilation,
MakeNSIS builds a separate uninstall command/header/data set and stores it in the
installer data block. `WriteUninstaller` asks the runtime to combine the prepared
uninstaller stub and data into a new executable.

The uninstaller can copy itself to a temporary location before removal. The
internal `_?=` argument preserves the original installation directory across
that restart. The uninstall program still executes compiled NSIS commands; it
does not replay a general transaction log.

## Process and privilege topology

NSIS itself does not impose one package scope. The PE requested-execution-level,
MultiUser logic, UserInfo/System calls, shell context, registry roots, and target
paths determine the result.

```text
asInvoker stub
+-- user path + HKCU writes -> user installation
`-- script may request or invoke elevation through a plug-in

requireAdministrator stub
`-- elevated process, normally machine paths and HKLM writes

highestAvailable stub
`-- behavior depends on token and consent
```

An x86 process can write the 32-bit or 64-bit registry view. Registry view does
not establish payload architecture.

## Source references

- [NSIS compiler targets](https://github.com/NSIS-Dev/nsis/blob/master/Source/build.h)
- [NSIS compiler output](https://github.com/NSIS-Dev/nsis/blob/master/Source/build.cpp)
- [NSIS runtime structures](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.h)
- [NSIS runtime entry point](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/Main.c)
- [NSIS plug-in runtime](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/plugin.c)
