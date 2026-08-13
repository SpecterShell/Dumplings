# NSIS uninstaller and Apps & Features registration

[Back to NSIS internals](overview.md).

NSIS supplies the mechanism that builds and writes an uninstaller, but it does
not automatically create a Windows uninstall registry entry. The script or a
script generator chooses the key, values, registry root, view, and visibility.
For static analysis, those explicit commands are the authoritative source of
Apps & Features evidence.

## Installer and uninstaller programs

MakeNSIS compiles installer and uninstaller code into separate logical programs.
Uninstaller functions use the `un.` namespace, and an uninstall section belongs
to the uninstaller program. The compiler maintains separate pages, sections,
entries, strings, language tables, and header state for these programs.

`WriteUninstaller` emits an `EW_WRITEUNINSTALLER` command in installer code. At
build time, MakeNSIS also constructs the uninstaller image and appends it to the
installer data block. The runtime command writes that prepared image to the
script-selected path. It does not compile an uninstaller on the target machine.

```text
Installer archive
+-- installer common header and command stream
+-- ordinary payload records
`-- prepared uninstaller image
    +-- copied and resource-adjusted NSIS PE stub
    +-- first header with FH_FLAGS_UNINSTALL
    +-- uninstaller common header and command stream
    `-- uninstaller payload and optional CRC
```

If uninstaller code exists but `WriteUninstaller` is never used, MakeNSIS warns
that no uninstaller will be created. If `WriteUninstaller` is used without an
uninstall section, compilation fails.

## Uninstaller startup

The uninstaller first header has `FH_FLAGS_UNINSTALL` set. At startup, the same
NSIS runtime recognizes this flag and enters uninstaller mode. The generated
header contains strings equivalent to:

```text
child path: $TEMP\Un.exe
child command: "$TEMP\Un.exe" $0 _?=$INSTDIR\
```

The initial process can copy itself to a temporary path and start the child so
the installed uninstaller and installation directory can be removed. `_?=` is
an internal handoff that supplies the original installation directory and must
not be confused with a public unattended-uninstall switch.

`/S` enables the stock silent route for an uninstaller too. Script code and
native plug-ins can still show UI, reject silent operation, or require custom
parameters.

## Apps & Features key ownership

NSIS has no built-in product database comparable to MSI. A typical script writes
to one of these locations:

```text
HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>
HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>
```

The `<key>` is the practical ProductCode used for WinGet matching. It may be a
GUID, an application name, a generator-defined identifier, or a value assembled
at runtime. NSIS does not require a GUID and does not append a fixed suffix.

Common values include:

| Value | Meaning |
| --- | --- |
| `DisplayName` | Displayed application name. It may resolve differently by language. |
| `DisplayVersion` | Displayed version, which can differ from the package or PE version. |
| `Publisher` | Displayed publisher. |
| `InstallLocation` | Installed directory when the script chooses to publish it. |
| `UninstallString` | Interactive uninstall command. |
| `QuietUninstallString` | Unattended uninstall command when the publisher supplies one. |
| `DisplayIcon` | Icon command or path. |
| `SystemComponent` | A DWORD value of `1` hides the entry from normal Apps & Features enumeration. |
| `WindowsInstaller` | A value of `1` makes Windows and WinGet treat the entry as MSI-owned; normal NSIS entries omit it. |

Other values such as `NoModify`, `NoRepair`, estimated size, URLs, comments, and
install date are conventional shell metadata. They do not change the identity
of the uninstall key.

## Registry roots and views

`SetShellVarContext current` or `all` controls the `SHCTX` pseudo-root and shell
folders. At runtime, `SHCTX` resolves to HKCU or HKLM. `SetRegView 32|64` changes
the registry view used by compatible operations. Explicit `HKCU`, `HKLM`,
`HKCU32`, `HKCU64`, `HKLM32`, or `HKLM64` operands bypass part of that context.

This distinction matters:

- HKCU versus HKLM is scope evidence.
- The 32-bit versus 64-bit registry view is not application-architecture
  evidence. A 32-bit stub can install 64-bit payloads and write the 64-bit view.
- A script can write more than one uninstall key, including architecture- or
  scope-specific alternatives.

The parser must therefore evaluate shell context, registry view, architecture
branches, and scope branches together rather than assigning every write to the
stub's PE architecture.

## Localized values

An uninstall command can reference a language string. The command record stays
the same while `DisplayName`, `Publisher`, or another value resolves differently
for each language table.

```text
EW_WRITEREG
`-- data operand -> language string reference
    +-- English: Product Name
    +-- Chinese: 产品名称
    `-- German: Produktname
```

These alternatives describe one registry write under different runtime
languages. They should be preserved as localized evidence, not collapsed to an
arbitrary first string and not treated as several unconditional ARP entries.

## Visibility and delegated ownership

A visible ARP entry requires a reachable uninstall-key path and useful display
values, without a reachable `SystemComponent=1` assignment for that same entry.
Scripts can hide one key and publish another. They can also extract and execute
an MSI or another EXE that owns the visible entry.

The presence of `WriteUninstaller` alone does not prove that the outer NSIS
installer writes ARP. Conversely, an NSIS installer can write an ARP entry even
when it does not write an NSIS uninstaller. Static analysis should correlate the
registry key, values, visibility, and execution path.

## Upgrade and maintenance behavior

NSIS does not prescribe upgrade semantics. Common script strategies are:

- reuse the same uninstall key and overwrite its values;
- run the previous uninstaller before installing;
- install side by side under a versioned key;
- let a generator or application-specific updater handle replacement;
- delegate installation and maintenance to a nested MSI or EXE.

An uninstall key is therefore identity evidence, not proof of in-place upgrade
support. `UpgradeBehavior` still needs script, feed, or VM evidence.

## Protocols and file extensions

Scripts commonly register protocols and file extensions through `WriteRegStr`,
using HKCR or `Software\Classes` under HKCU/HKLM. Literal class, ProgID, command,
and icon writes can be projected statically. A bare extension key without a
literal ProgID is incomplete evidence because application code may finish the
association on first run.

## Static-analysis boundary

Direct `EW_WRITEREG` commands with resolvable strings are strong evidence.
Values obtained from registry reads, command-line parsing, native plug-ins,
downloaded files, child processes, or application first run remain conditional
or opaque. The runtime does not expose a declarative list of final registry
state.

## Source references

- [NSIS compiler and uninstaller generation](https://github.com/NSIS-Dev/nsis/blob/master/Source/build.cpp)
- [NSIS serialized command definitions](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.h)
- [NSIS runtime command interpreter](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/exec.c)
- [NSIS runtime startup](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/Main.c)
- [NSIS registry documentation](https://nsis.sourceforge.io/Docs/Chapter4.html#registry)
- [NSIS uninstaller documentation](https://nsis.sourceforge.io/Docs/Chapter4.html#uninstaller)
