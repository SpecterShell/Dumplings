# Paquet Builder metadata model

## Metadata precedence

Installed-package fields use explicit ownership evidence in this order: a script-selected or route-owned nested MSI, one literal uninstall registry row, one `UNINSTKEY` paired with `UNINSTALLINFO`, one literal modern uninstall-key suffix, then launcher identity for display fields only. Missing ProductCode is left unresolved.

## GINFOS program

Versions 2.7 through 2.9 store a Windows-1252 text program named `GINFOS`. The parser preserves the full text and every non-comment command with its line number. It projects literal `SET name TO "value"` assignments, `EXEC`, `EXECUTE`, and `EXECWAIT`, `CALLDLL ...*PBExecMSI`, `WRITEREG`, shortcuts, basic file operations, and uninstaller operations. Unknown expressions remain in `Expression`; they are not evaluated as strings.

```text
SET DESTPATH TO "%PROGFILESDIR%\Paquet Builder"
SET UNINSTFNAME TO "%DESTPATH%\Uninst.exe"
SET UNINSTKEY TO "PaquetBuilderSetup89"
WRITEREG 4, "Software\Microsoft\Windows\CurrentVersion\Uninstall\PaquetBuilderSetup89", "DisplayName", "Paquet Builder 2.9", 0
UNINSTALLINFO
```

The comma splitter preserves quoted commas and doubled quote characters. Parsed execution records retain `RawArguments`, because flattening quote delimiters can otherwise hide the exact child command line. A `PBExecMSI` reference becomes nested-installer evidence only when its `%DESTPATH%`-relative path matches the sole MSI in the validated payload archive.

## Registry operations

Observed GINFOS root codes map as follows: `0` writes classes under HKCR, `2` writes HKCU, and `4` writes HKLM. Value type `0` is a string and `1` is a DWORD in verified programs. Unknown codes remain in `RootCode` or `TypeCode` and keep `WRITEREG` in the unsupported-command evidence.

The parser exposes all literal writes, including writes inside conditional blocks. ARP inference requires one unique uninstall-key suffix. Association projection recognizes literal extension, ProgID, command, icon, and protocol records through the shared registry-evidence model. The 2.9.5 and 2.9.6 fixtures therefore return `pbd`, `pbp`, and `pbr` file extensions.

## Deterministic variables

The resolver substitutes only one unique literal assignment and these source-backed directory values: `%PROGFILESDIR%` to `%ProgramFiles%`, `%LOCALAPPDATADIR%` to `%LOCALAPPDATA%`, `%APPDATADIR%` to `%APPDATA%`, and `%PBINSTALLSCOPEDIR%` when one scope is known. `%DESTPATH%` resolves only after one source-backed final destination is available. Cycles, conflicting assignments, dialog values, registry reads, and unknown percent variables return no resolved value.

`PBINSTALLSCOPE=0` is user scope and `PBINSTALLSCOPE=1` is machine scope in controlled modern builder output. Both literal values indicate a conditional or dual-scope package. A literal `DESTPATH` is converted to a manifest-safe path only when every variable is known.

## Classic controller metadata

The first Classic controller record carries setup title, application names, version text, uninstall display name, record counts, and text sizes. Later records provide complete installed destinations, shortcuts, registry writes, auxiliary paths, and execution commands. Registry roots use native Win32 handle constants `0x80000000` for HKCR, `0x80000001` for HKCU, and `0x80000002` for HKLM.

Classic `{app}` destinations are emitted relative to the extraction root. Other roots are preserved under `_destinations/<root>`. The controller does not store one source-backed absolute `{app}` value in the verified package, so `DefaultInstallLocation` remains unresolved even though every installed file can be mapped.

## Modern runtime metadata

The native scanner resolves imports or delay imports of `PBCore.dll`, `PBCore64.dll`, or `PBCoreA64.dll` and searches executable sections for literal `SetVar(name, value)` calls. It understands the verified x64 RCX/RDX call shape and x86 stack argument shape, bounded UTF-16 strings, direct and indirect IAT calls, simple register copies, and selected conditional moves. UPX-packed 3.0 and 3.2 launchers are reconstructed into the same mapped-PE input after bounded LZMA decoding, executable-call unfiltering, and relocation restoration; their assignment output is byte-for-byte equivalent to scanning an externally unpacked reference during development.

The scanner also searches mapped PE data for one exact UTF-16 `Software\Microsoft\Windows\CurrentVersion\Uninstall\<suffix>` string. The suffix must contain no slash, backslash, variable, or control character. Arbitrary pointer arithmetic, dynamically assembled strings, external DLL results, and unsupported branch shapes remain outside the model.

## Runtime catalogs

`pbfprop.dat` is exposed as repeated five-line property records. The parser deliberately labels two columns `ObservedField1` and `ObservedField2` because their complete semantics have not been proven across builder generations. `ComponentVariable` and decimal `Flags` are retained. A non-divisible line count is malformed rather than partially guessed.

`pblng.dat` supplies language names and LCIDs. `pbdlg.dat` supplies dialog identifiers. `pbremove.dat` proves that uninstaller machinery is packaged, but it does not prove a visible ARP row without an uninstall identity.
