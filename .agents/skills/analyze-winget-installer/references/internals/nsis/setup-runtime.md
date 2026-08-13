# NSIS setup runtime

[Back to NSIS internals](overview.md).

The shipped executable contains the setup engine. It does not start a separate
generic installer service. Startup, UI, decompression, command execution, and
uninstaller generation happen in the selected NSIS stub process unless the
script explicitly launches or delegates to another process.

## Process startup

`NSISWinMainNOCRT` initializes process state, reads the complete command line,
sets predefined executable variables, and applies runtime hardening and Windows
compatibility behavior compiled into the stub.

The runtime distinguishes installer and uninstaller archives through first-
header flags. Uninstallers can restart from a temporary location so the original
uninstaller and installation directory can be removed safely.

## Command-line processing

Stock runtime switches include:

| Switch | Runtime effect |
| --- | --- |
| `/S` | Enables silent mode. It is case-sensitive. |
| `/NCRC` | Skips a non-forced archive CRC check. |
| `/D=<path>` | Overrides `$INSTDIR`; it must be the last command-line argument. |
| `_?=<path>` | Internal uninstaller original-directory handoff. |

The rest of the command line remains available through `$CMDLINE`. Scripts and
plug-ins can parse arbitrary private switches. `/S` suppresses stock pages; it
does not neutralize `MessageBox` without `/SD`, custom plug-in windows, child
process UI, or script logic that intentionally changes silent state.

`GetParameters`-style macros usually remove the executable token before parsing
private options. The runtime applies a trailing `/D=` value before `.onInit`, so
callbacks and sections see the overridden `$INSTDIR` rather than the compiled
default.

## Archive discovery and loading

The runtime locates its first header after the executable image, validates the
signature and lengths, and establishes the archive and data-block ranges. It
then applies the selected CRC policy and decompresses the logical header.

`loadHeaders` converts serialized block offsets to memory pointers and exposes
the pages, sections, entries, strings, languages, and data block to the rest of
the runtime. A malformed offset can otherwise become an arbitrary pointer, so a
static reader must validate every range before reproducing this relocation.

## Language initialization

The runtime selects one compiled language table using command-line, previous,
system, or language-selection behavior configured by the script. It initializes
caption, button, error, page, and script-defined strings from that table.

ANSI stubs interpret string bytes through their configured or system code-page
behavior. Unicode stubs use UTF-16LE. The selected language table affects every
negative string operand and can change ARP values written by the same command.

## Predefined state

Before script callbacks run, the runtime establishes values such as:

- `$EXEPATH`, `$EXEFILE`, and `$EXEDIR` where supported by the variable layout;
- `$CMDLINE`, `$LANGUAGE`, and `$TEMP`;
- initial `$INSTDIR` from the common header and `/D=`;
- shell-folder context and registry view;
- silent, error, reboot, and UI flags.

`InstallDirRegKey` can replace the initial installation path with a value from a
previous installation. This target-machine lookup is dynamic even though its
root, key, and value-name pointers are serialized.

## Callback lifecycle

The exact callback set depends on stub features. A normal installer can run:

```text
startup
`-- .onInit
    +-- .onGUIInit
    +-- page pre/show/leave callbacks
    +-- .onVerifyInstDir
    +-- section code
    +-- .onInstSuccess or .onInstFailed
    `-- .onGUIEnd
```

User cancellation can invoke `.onUserAbort`. Component selection can invoke
`.onSelChange`, and reboot failure can invoke `.onRebootFailed` when those
features are compiled into the stub.

Silent mode skips normal page navigation but does not skip initialization or
selected sections. Callback code can exit, abort, alter section flags, change
scope, or invoke native code.

## Page runtime

`Ui.c` creates standard dialogs from compiled resources and page records. For
each page, the runtime can run a pre-callback, create/show the page, then run a
leave callback. A callback return value can skip a page or block navigation.

Custom pages are usually implemented through nsDialogs or older InstallOptions
plug-ins. Their controls and event behavior are native plug-in effects, not a
complete declarative page schema in the NSIS archive.

## Section selection and installation

Sections carry flags and installation-type membership. The install thread walks
selected section records and executes each command range when component-page
support is compiled into the stub. Feature-stripped stubs compile that guard out
and execute every section. Commands can change the current install type or later
section flags, so initial selection is not always final.

The interpreter uses one-based command addresses for calls and jumps. It shares
variables, stack, flags, registry view, shell context, and file handles across
commands. A call returns when `EW_RET` is reached; abort, quit, and errors follow
opcode-specific runtime rules.

## File extraction

`EW_CREATEDIR` can create a directory and update `$OUTDIR`. `EW_EXTRACTFILE`
opens the selected data record, applies overwrite and timestamp policy, decodes
it, and writes the destination relative to current output state.

Solid archives must be decoded in stream order. Non-solid archives can seek to
individual framed records. NSISBI can read an external data file or a sequence
of independently compressed multithread blocks.

The extraction command may ignore selected errors or continue after prompting.
Static extraction should instead return deterministic integrity and bounds
errors; it must not reproduce interactive ignore behavior.

## Registry, files, and shell effects

Core opcodes can create/delete files and directories, copy or rename files,
write/read/delete/enumerate registry entries, write/read INI files, and create
shortcuts. Registry and shell context flags select user versus machine roots and
32-bit versus 64-bit views.

`ReadEnvStr` compiles its name as `%NAME%`, expands it, and reports an error with
an empty destination when the token remains unchanged. `ExpandEnvStrings` uses
the same opcode but preserves unknown tokens in surrounding text. Missing or
incompatible registry values and missing INI values also clear the destination
and increment `exec_error`, so a following `IfErrors` can change execution.

The runtime does not journal every action for automatic rollback. Script authors
write explicit uninstall commands, often alongside install commands or in
separate uninstall sections.

## Native plug-ins and child processes

The runtime extracts a plug-in DLL to `$PLUGINSDIR`, pushes arguments on the NSIS
stack, calls an export, and receives results through stack and variable state.
System.dll can invoke arbitrary native APIs. UAC and MultiUser implementations
can start another process or coordinate elevated and unelevated instances.

The common `nsProcess` plug-in pops a process name and pushes a numeric result.
`_FindProcess` returns `0` for a match and `603` when no process matches. Installers
often place this call in a retry loop before replacing application files.

`Exec`, `ExecWait`, and `ShellExec` can transfer responsibility to another
installer. The outer runtime knows the command and, for waiting calls, an exit
status. It does not know the child's registry or filesystem effects.

## Reboot and exit state

The script can request reboot, set an exit code, abort a code segment, or quit.
File operations can schedule work for reboot. Runtime and plug-in errors affect
the error flag and can alter branch behavior.

The final process exit code is script- and path-dependent. A parser cannot infer
every success code from installer type alone when `SetErrorLevel`, child process
results, or native plug-ins participate.

## Source references

- [NSIS runtime startup](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/Main.c)
- [NSIS archive loading](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.c)
- [NSIS command interpreter](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/exec.c)
- [NSIS user-interface runtime](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/Ui.c)
- [NSIS command-line usage](https://nsis.sourceforge.io/Docs/Chapter3.html)
- [NSIS silent installation](https://nsis.sourceforge.io/Docs/Chapter4.html#silent)
