# Paquet Builder format history

## Classic 2.6

The oldest complete cached media uses named PE resources, a GPacker/LZHUF overlay control block, and a following ZIP. The ZIP contains a packed native setup controller and a GAF stream. The controller's zlib records provide package metadata, ordered installed-file descriptors, shortcuts, registry writes, auxiliary paths, and nested executions. Each file descriptor maps by index to one GAF member.

One older Wayback capture preserves enough structure to classify the route and verify the GPacker CRC but does not contain a complete ZIP central directory. It is retained as a truncation regression rather than treated as a second format.

## Cabinet 2.7

Version 2.7 introduces `RCDATA/ISFX`, whose absolute offsets separate encoded configuration from a Microsoft Cabinet. The configuration is transformed with a 16-bit state cipher, begins with `@GDG`, and expands through the historical LZHUF decoder into named resources. `GINFOS` is a Windows-1252 package program. Verified fixtures include both a non-MSI wrapper and a cabinet carrying an MSI plus its external cabinet.

## Legacy 2.8

Version 2.8 keeps `ISFX` but replaces the `@GDG` compressed configuration with a safe `AP32` frame around an aPLib bitstream. The expanded object is the same named-resource table and exposes the same `GINFOS` language. The application payload moves to a standard 7z archive, while `RCDATA/ENG` remains a complete PE runtime.

## Resource 2.9

Version 2.9 compresses `RCDATA/ENG` itself. The outer `GP` header describes a raw-LZMA runtime PE and the size of a separately encoded package configuration. Applying the same package transform to that trailing range reveals an inner `GP`/LZMA frame whose output is the established named-resource table. Fixtures for 2.9.1, 2.9.5, and 2.9.6 share this framing.

The 2.9.1 builder installer invokes a packaged `Setup1.msi` through `PBExecMSI`, so that MSI owns ARP identity. The 2.9.5 and 2.9.6 installers instead define `UNINSTKEY=PaquetBuilderSetup89`, write a complete literal ARP row, register three file extensions, and generate their own uninstaller.

## Split archives, 3.x through current

Version 3 and later append independent 7z archives for application files and runtime support. Runtime data files describe payload records, dialogs, languages, and the generated-uninstaller template. Package logic is native rather than stored as GINFOS text. The parser recovers bounded literal `SetVar` calls and uninstall-key strings from mapped PE code and data.

The cached 3.0 and 3.2 launchers wrap that native image with UPX version 13, Win32 format 9, UPX-style LZMA method 14, and executable filter `0x26`. The parser validates the UPX header and Adler-32 checksums, converts the two-byte LZMA properties, restores filtered calls and delta-coded relocations, rebuilds file-backed sections in memory, and then uses the same `SetVar` scanner as unpacked and later media. Both archived launchers resolve `UNINSTKEY=GDGSoftPB300` and `DESTPATH=%PROGFILESDIR%\Paquet Builder 3` without executing the UPX stub. Versions 3.6, 20.1, 21.0, and current media expose the mapped PE directly. Current builder media contains both user and machine scope paths, so a single `Scope` or `DefaultInstallLocation` is intentionally left unresolved.

## Capture quality

Two historical responses are exactly 1,048,576 bytes and do not contain a complete supported package structure. The parser rejects them instead of weakening detection. Capture timestamps identify archived files, not builder versions, and duplicate captures with identical content do not create new format generations.
