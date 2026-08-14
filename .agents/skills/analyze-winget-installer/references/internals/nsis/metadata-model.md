# NSIS metadata model

[Back to NSIS internals](overview.md).

NSIS metadata is executable configuration plus script data. There is no product record equivalent to MSI's `Property` table or Inno Setup's setup header. A reader must distinguish runtime configuration from effects produced by commands.

## Common header

The common header describes the compiled runtime route. Depending on build features, it can contain:

- runtime flags for details, progress, silent mode, auto-close, and directory UI;
- block descriptors;
- `InstallDirRegKey` root, key, and value pointers;
- language-table record size;
- callback addresses;
- installation-type masks;
- initial installation-directory and auto-append string offsets;
- uninstaller command strings and move-on-reboot data.

Some fields are omitted when a stub feature is disabled. Their physical offset therefore belongs to a complete header schema, not a release-number threshold.

`InstallDir` is initial state. The script can later assign `$INSTDIR`, accept `/D=`, restore a previous path from the registry, or change it through a plug-in.

## Pages

A page record describes one step in the built-in wizard. Relevant fields include:

- dialog and window identifiers;
- page flags and caption/string offsets;
- pre, show, and leave callback addresses;
- page-specific parameters such as license text or directory variables.

Modern UI and custom-page macros configure these records and callbacks. Custom pages can call plug-ins and cannot be reconstructed from the page record alone.

## Sections

A section record contains:

- localized or literal name;
- flags such as selected, read-only, bold, or section group;
- installation-type membership;
- estimated size;
- command-table start and length.

Uninstall sections use the same command representation. Silent installation runs selected sections; it does not mean every section is selected.

## Functions and callbacks

Functions are command ranges reached through `EW_CALL`. Labels become jump addresses. Callback addresses are stored in the common header or page records. There is no serialized function-name table required at runtime after references have been resolved.

Decompiler-style names can sometimes be reconstructed from surrounding strings or generator patterns, but they are not authoritative runtime metadata.

## Command operands

Each opcode defines the meaning of its operands. Common operand domains are:

| Domain | Examples |
| --- | --- |
| String offset | Registry key, file path, process command, comparison operand |
| Variable index | Assignment target, stack output, API result |
| Command address | Jump, call, comparison true/false destination |
| Data offset | Compressed file or generated uninstaller data |
| Immediate integer | Registry root, flags, show mode, operation selector |
| Packed field | Shortcut attributes, registry type/view, message-box outcomes |

The same integer is meaningless without the selected opcode route. Reading every operand as a string offset produces plausible but false metadata.

## String expressions

NSIS does not serialize a general expression tree. It stores strings with inline control codes. Runtime expansion can insert:

- `$0` through `$9` and `$R0` through `$R9`;
- predefined variables such as `$INSTDIR`, `$OUTDIR`, `$EXEDIR`, `$LANGUAGE`, `$TEMP`, and `$PLUGINSDIR`;
- shell-folder values such as Program Files, AppData, Desktop, or Start Menu;
- language strings;
- escaped control characters.

Instructions such as `StrCpy`, `ReadRegStr`, `ReadEnvStr`, `IntOp`, and plug-in calls assign values used by later strings. A final path can therefore depend on control flow and target state.

## Variable layout generations

The stable public prefix is followed by predefined and compiler-private slots. Historical layouts differ:

```text
Common prefix: $0..$9, $R0..$R9, $CMDLINE, $INSTDIR, $OUTDIR,
               $EXEDIR, $LANGUAGE, $TEMP, $PLUGINSDIR

NSIS <= 2.03:  $HWNDPARENT=27, $_CLICK=28, private base=29
NSIS 2.04-2.25:$HWNDPARENT=27, $_CLICK=28, $_OUTDIR=29, private base=30
Current:       $EXEPATH=27, $EXEFILE=28, $HWNDPARENT=29,
               $_CLICK=30, $_OUTDIR=31, private base=32
```

The private `$_OUTDIR` slot is used by compiler-generated save/restore sequences. Applying current indexes to an old command stream corrupts path and plug-in register interpretation.

## Language model

The language block contains one fixed-size table per compiled language. A table holds a Windows language identifier, font/dialog data, built-in strings, and script-defined language string offsets.

The same registry command can resolve to a different `DisplayName` for each language. These are alternatives from one command path, not several simultaneous ARP entries. Static tools can expose every literal alternative and preserve the language identifier.

ANSI outputs require a code page to convert bytes to Unicode. The byte stream does not always carry a complete encoding declaration. Language ID and compiler settings are evidence, but guessing the host code page is unsafe.

## Payload metadata

`EW_EXTRACTFILE` is the payload catalog used by the runtime. It identifies:

- output-name expression;
- data-block-relative offset;
- file timestamps;
- overwrite and error policy;
- in NSISBI, wide offsets and per-file CRC.

`SetOutPath` is compiled as `EW_CREATEDIR` with an update-output-directory flag. The effective extraction path is the current `$OUTDIR` plus the file operand. The same data offset may have several output aliases.

## Registry and installed-state metadata

Registry commands store root, key, name, data, type, and view flags. The runtime does not classify a write as ARP, protocol, or file association. Those meanings come from the target key:

- uninstall keys establish Apps & Features candidates;
- `Software\Classes` keys can establish protocols and file associations;
- application-specific keys remain raw registry evidence.

The script can also delete, enumerate, and read registry values. Reads can make later writes conditional on target-machine state.

## Nested execution metadata

`Exec`, `ExecWait`, and `ShellExec` carry a command or file plus arguments. The outer NSIS script can extract and launch an MSI, another EXE, a service helper, or the application itself. The command proves configured execution, but the child owns any effects not explicitly performed by NSIS.

## Generator evidence

electron-builder, Tauri, CPack, and other generators leave recognizable command sequences, defines expanded into literals, payload names, and plug-in calls. That evidence describes the source template, not a separate binary format. Generator classification should remain independent from edition and serialized ABI.

## Source references

- [NSIS serialized metadata structures](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.h)
- [NSIS command emission](https://github.com/NSIS-Dev/nsis/blob/master/Source/script.cpp)
- [NSIS runtime command interpreter](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/exec.c)
- [NSIS variables](https://nsis.sourceforge.io/Docs/Chapter4.html#variables)
- [NSIS language support](https://nsis.sourceforge.io/Docs/Chapter4.html#langstring)
