# NSIS internals

This directory explains how NSIS turns an `.nsi` script and source files into a Windows executable, how the executable locates and decodes its archive, how the compiled command stream runs, and how scripts create an uninstaller and Apps & Features registration.

The emphasis is the NSIS compiler, serialized format, and runtime. Details of the Dumplings reader are kept in [parser implementation notes](parser-implementation.md) and [coverage](coverage.md).

Use the [NSIS package workflow](../../families/nsis/workflow.md) when the immediate goal is a WinGet manifest.

## Reading path

1. [Architecture](architecture.md) introduces MakeNSIS, the executable stub, archive, command engine, plug-ins, and generated uninstaller.
2. [Compiler and output assembly](compiler-and-output.md) follows source text through preprocessing, command emission, string and language tables, payload compression, PE customization, and final output.
3. [Binary format](binary-format.md) documents archive discovery, first headers, logical blocks, command records, payload framing, compression, and integrity.
4. [Metadata model](metadata-model.md) describes the common header, pages, sections, strings, language tables, variables, and command operands.
5. [Setup runtime](setup-runtime.md) follows command-line handling, archive loading, callbacks, pages, section execution, extraction, and exit behavior.
6. [Scripting, strings, and plug-ins](scripting-and-expressions.md) explains the compile-time preprocessor, command-address model, encoded strings, stack, variables, macros, and native plug-in boundary.
7. [Uninstaller and ARP](uninstaller-and-arp.md) covers `WriteUninstaller`, uninstall registry writes, scope, localization, maintenance, and removal.
8. [Format history and editions](format-history.md) separates official NSIS, Jim Park NSIS, NSISBI, custom stubs, and script generators.
9. [Parser implementation notes](parser-implementation.md) maps the runtime to a bounded static reader and emulator.
10. [Coverage and remaining work](coverage.md) records implementation parity, known defects, unsupported routes, and the fixture matrix.

## One installer contains a runtime and a program

NSIS does not serialize a declarative package manifest. It compiles most script statements into a compact instruction table interpreted by a purpose-built Windows executable. Product identity, scope, architecture selection, payload names, and uninstall behavior are therefore program effects.

```text
Compiled installer.exe
+-- PE executable stub
|   +-- Windows entry point and NSIS runtime
|   +-- dialogs, icons, manifest, and version resources
|   `-- optional custom or vendor resources
`-- NSIS archive
    +-- first header and archive bounds
    +-- compressed logical header
    |   +-- common header
    |   +-- block descriptors
    |   +-- pages and sections
    |   +-- compiled commands
    |   +-- strings and language tables
    |   `-- colors, fonts, and data-block descriptor
    +-- compressed or stored payload data
    `-- optional archive CRC
```

The stub is selected at build time. Current official source can target x86 ANSI, x86 Unicode, AMD64 Unicode, or ARM64 Unicode. Its PE machine identifies the runtime process, not necessarily the installed application. Script code can select different payloads for different Windows architectures.

## Build-time and run-time models

NSIS has distinct evaluation layers:

```text
Compile time
+-- preprocessor directives, includes, macros, and defines
+-- script tokenization and validation
+-- labels and function/section address resolution
+-- source-file enumeration and payload compression
`-- PE resource and archive assembly

Runtime initialization
+-- command-line switches and uninstaller marker handling
+-- first-header, range, compression, and CRC processing
+-- common-header and language-table initialization
+-- predefined variables and shell-folder state
`-- .onInit, page, and other callbacks

Installation
+-- page callbacks or silent route
+-- selected section command ranges
+-- file, registry, shortcut, INI, process, and plug-in operations
+-- generated uninstaller creation
`-- script-authored Apps & Features registration

First application run
`-- outside NSIS; the application may add more associations or state
```

Macros such as LogicLib and MultiUser disappear during compilation. Their output is ordinary command records and jumps. Native plug-ins do not disappear: the archive contains the plug-in DLL and commands that extract and invoke it.

## Identity domains

Several values are easily confused:

| Identity | Meaning |
| --- | --- |
| NSIS compiler release | The MakeNSIS release used to compile the script. It is not reliably serialized in every output. |
| Serialized ABI profile | String controls, variable indexes, command numbering, record width, and fork-specific framing that a reader can prove. |
| Executable-stub architecture | PE machine of the NSIS runtime process. |
| Application architecture | Payload and runtime path selected by the compiled script. |
| Script generator | electron-builder, Tauri, CPack, PortableApps.com, or another system that emits NSIS source. |
| Package version | Application version chosen by the publisher and usually written through script commands. |

The serialized ABI profile is the useful format identity. An exact compiler release must remain unknown when the binary does not preserve it.

## Static and dynamic evidence

The archive proves command operands, literal strings, language alternatives, payload records, and explicit registry writes. It does not prove the result of an arbitrary native plug-in, a target-machine registry query, a downloaded child installer, or application first-run behavior.

Static analysis should preserve that boundary. For example, a literal `WriteRegStr` to an uninstall key is direct ARP evidence. A path assembled from an opaque plug-in return value is conditional evidence. A registry key created by the installed application does not belong to the NSIS runtime at all.

## Important source units

The official source is the primary specification for current NSIS output.

| Area | Source |
| --- | --- |
| Serialized structures and command enumeration | `Source/exehead/fileform.h` |
| Compiler state and target selection | `Source/build.h`, `Source/build.cpp` |
| Script parser and command emission | `Source/script.cpp`, `Source/tokens.cpp` |
| String controls and block serialization | `Source/fileform.cpp`, `Source/build.cpp` |
| Runtime startup and command line | `Source/exehead/Main.c` |
| Archive loading and decompression | `Source/exehead/fileform.c` |
| Command interpreter | `Source/exehead/exec.c` |
| Page and section lifecycle | `Source/exehead/Ui.c` |
| Plug-in ABI | `Source/exehead/plugin.c`, `Source/exehead/api.h` |
| Historical format detection | 7-Zip `CPP/7zip/Archive/Nsis` |

## Source references

- [Official NSIS source](https://github.com/NSIS-Dev/nsis)
- [Official NSIS documentation](https://nsis.sourceforge.io/Docs/)
- [7-Zip NSIS reader](https://github.com/ip7z/7zip/tree/main/CPP/7zip/Archive/Nsis)
- [Jim Park Unicode NSIS](https://sourceforge.net/projects/nsisu/)
- [NSISBI](https://sourceforge.net/projects/nsisbi/)
