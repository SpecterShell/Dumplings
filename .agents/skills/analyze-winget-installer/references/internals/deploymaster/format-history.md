# DeployMaster format history

## Structural generations

| Route | Observed releases | Defining structure | Current status |
| --- | --- | --- | --- |
| `ClassicBZip2` | 2.5.3 through 2.5.5 | `BZh9` runtime member, `FFFFFFFF` boundary, length-prefixed zlib records, classic catalog and behavior streams | metadata, extraction, install tree, registry, associations, and 2.5.3 ARP implemented; prerequisites and completion remain unresolved |
| Unclassified | 3.x through 5.x | no durable artifact | rejected rather than assigned another generation's grammar |
| `Header66` | 6.0.1 through 6.1.2 | locator at `0x80`, 66-byte control header, legacy file table, delimited registry route, form-feed associations | implemented |
| `Header70` | 6.5.1 through 7.1.1 | 70-byte control header, Windows 10 bounds, opcode registry route, form-feed associations | implemented |
| `Header74` | 7.2.0 through controlled 7.7 output | 74-byte control header, Windows 11 bounds, package settings, current file table, conditional uninstall quoting | implemented |

Observed release ranges describe fixtures and do not select parser code. A package enters a route only when the corresponding offsets, runtime tuples, metadata boundaries, and catalog relationships validate without ambiguity.

## Classic transition

Classic media has no package locator, expected logical file size, or raw-LZMA property block. The complete overlay is discovered from the PE image end, a bounded BZip2 runtime member, and a contiguous zlib record chain. The later locator family is therefore a new physical grammar rather than a small header revision.

Classic identity fields 7 through 10 mean display icon, readme, license, and x86 support DLL. Locator identity fields at the same positions mean readme, marked license, x86 support DLL, and x64 support DLL. Passing classic text to the locator decoder silently shifts metadata and is forbidden.

## Locator header transitions

`Header66`, `Header70`, and `Header74` share normalized semantics but place scope, core tuples, language offset, and expiration fields at shifted positions. The catalog stores `Shift=-8`, `-4`, and `0` respectively. Windows 10 bounds appear in `Header70`; Windows 11 bounds and package settings appear in `Header74`.

Registry and association framing also evolved. Header66 uses a legacy delimited registry representation. Header70 and Header74 use the recursive opcode grammar. Archived 6.0 through 7.2 associations use form-feed-terminated Windows-1252 text, while current output uses length-prefixed UTF-8 and an explicit default-selection byte. Header74 can contain either association route, so the first bounded record selects the grammar rather than the header size alone.

## Runtime behavior boundaries

Header66 and Header70 construct uninstall commands with an unquoted executable path and a quoted log path. Header74 quotes each path only when that path contains a space. The route boundary is structural at Header74, not inferred from a version string.

`/userall` is present in verified dual-scope Header70 and Header74 media and absent from Header66. `/noadmin` is present in inspected Header70 and Header74 cores and absent from Header66, whose relaunch path uses `/elevate /silent`. `/portable` was introduced in 7.5, but the parser reports it only when both the package settings and the bounded runtime token establish support.

## Evidence discipline

The catalog records only layouts backed by archived or controlled media. Intermediate or future releases can use a known route when all structural invariants pass. An unknown header, a partially matching core tuple, or a conflicting catalog interpretation is rejected rather than assigned the nearest release.
