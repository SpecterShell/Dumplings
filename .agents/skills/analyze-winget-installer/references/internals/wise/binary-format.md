# Wise binary format

## Container dispatch

```text
offset 0x00
+------------------------------+
| MZ                           |
+------------------------------+
| e_lfanew at DOS+0x3C         | uint32 LE
+------------------------------+
| NE or PE\0\0                 | selected host format
+------------------------------+
| host segments/sections       |
+------------------------------+
| Wise route                   | overlay, .WISE section, or nested resource PE
+------------------------------+
```

NE media uses the furthest segment/resource extent plus the runtime-owned trailer to locate the overlay. The parser uses the bounded SabreTools NE model for this calculation. PE media uses section raw extents and the Authenticode certificate boundary. A resource launcher is searched only inside the bounded `.rsrc` raw range, and each `MZ` candidate must parse as a nested PE with a valid WiseScript overlay.

## WiseScript overlay header

All integers below are little-endian. Offsets are relative to the start of the Wise overlay and move when `DllNameLength` is nonzero.

```text
Offset       Size  Field
-----------  ----  ------------------------------------------
0x00            1  DllNameLength
0x01            n  DllName, ANSI, present when n > 0
0x01+n          4  DllSize, present when n > 0
next            4  Flags
next           12  GraphicsData
next            4  WiseScriptExitEventOffset
next            4  WiseScriptCancelEventOffset
next            4  WiseScriptInflatedSize
next            4  WiseScriptDeflatedSize, includes CRC trailer
next            4  WiseDllDeflatedSize
next            4  Ctl3d32DeflatedSize
next            4  SomeData4DeflatedSize
next            4  RegToolDeflatedSize
next            4  ProgressDllDeflatedSize
next           16  SomeData7 through SomeData10 sizes
next            4  FinalFileDeflatedSize
next            4  FinalFileInflatedSize
next            4  DeclaredEof
```

The legacy header stops here. Later profiles continue:

```text
next            4  DibDeflatedSize
next            4  DibInflatedSize
next        0 or 4  InstallScriptDeflatedSize
next        0 or 4  CharacterSet
next            2  Endianness marker, 0x0008 or 0x0800
next            1  InitTextLength
next            n  InitText, ANSI
```

The candidate DIB size distinguishes the tails. If that DWORD exceeds the remaining bounded stream, it belongs to compressed data and the parser rewinds four bytes to the legacy boundary.

## Deflate member framing

Header members and InstallFile payloads use raw Deflate followed by CRC32.

```text
+------------------------------+  member offset
| raw Deflate bytes            | CompressedSize - 4
+------------------------------+
| CRC32 of inflated bytes      | uint32 LE
+------------------------------+  next member
```

The catalog supplies expected compressed and, where available, inflated sizes. Dumplings bounds the input stream, caps output, validates the exact inflated size, and compares the calculated CRC with both the trailer and the catalog CRC when present. A nominal header size that does not decode and checksum at the current position is treated as a repurposed slot. It does not advance the payload base.

## WiseScript InstallFile record

The decoded state machine stores one file action as:

```text
Offset  Size  Field
------  ----  ------------------------------------------
0x00       2  Flags
0x02       4  DeflateStart, payload-area relative
0x06       4  DeflateEnd, payload-area relative
0x0A       2  DOS date
0x0C       2  DOS time
0x0E       4  InflatedSize
0x12      20  operands or reserved data
0x26       4  CRC32 of inflated file
0x2A       n  destination pathname, NUL-terminated ANSI
next       n  language-dependent descriptions
next       n  source pathname, NUL-terminated ANSI
```

The absolute compressed range is `ContainerOffset + PayloadDataOffset + DeflateStart` through `DeflateEnd`. The final four bytes are the Deflate trailer CRC and are not part of the Deflate stream.

## `.WISE` MSI record

The supported Wise for Windows Installer route uses a PE section named `.WISE`.

```text
.WISE raw offset
+------------------------------+
| Wise runtime metadata        |
| +0x18 RecordLength uint32 LE |
+------------------------------+
| WIS metadata and padding     |
+------------------------------+
| D0 CF 11 E0 A1 B1 1A E1     | MSI CFB header
+------------------------------+
| complete MSI CFB             | RecordLength - 4 bytes
+------------------------------+
| CRC32 of complete MSI CFB    | uint32 LE
+------------------------------+
```

The parser searches at most the first MiB of the section for CFB candidates. A candidate is accepted only when its CFB root-storage CLSID is `{000C1084-0000-0000-C000-000000000046}`, its declared range stays inside `.WISE`, and the trailing CRC32 matches.

## Resource launcher route

NavigatorPlus contains an outer PE and a second complete PE beginning at absolute file offset 6144 inside `.rsrc` slack. The nested PE owns the WiseScript overlay. One WiseScript InstallFile record expands to another PE with a `.WISE` section, and that section contains the authoritative MSI. These are logical execution layers; their source bytes are not assumed to be adjacent after decompression.
