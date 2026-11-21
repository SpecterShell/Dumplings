# Setup Factory format history

## Product generations

Setup Factory release identity and archive format are separate facts. A project can replace the outer launcher's version resource, and releases 8 through 10 use the same observed doubled-signature container. Parser dispatch therefore uses structural profiles; trusted PE version information is supplemental release evidence.

| Profile | Observed releases | Outer header | Outer extraction | `irsetup.dat` metadata |
| --- | --- | --- | --- | --- |
| `MultiFile31` | 3.1.0 | 16-bit MZ/NE launcher plus Crusher ARQ archive and companion streams | Supported | Product and installed-file records supported; version, publisher, scope, and Windows ARP are absent from the verified record |
| `Classic4` | 4.x and one early 5.x runtime | Seven-byte magic; byte 7 is the entry count | Supported | Global settings, built-in uninstall, registry, and files supported; absent product fields remain unresolved |
| `Legacy5` | 5.x | Eight-byte magic; `uint32` entry count; 16-byte names | Supported | Product, built-in uninstall, registry framing, and condition framing supported; runtime-dependent conditions remain unresolved |
| `Legacy6` | 6.x | Eight-byte magic; `uint32` entry count; 260-byte names | Supported | Product and built-in uninstall supported; custom actions partial |
| `Modern7` | 7.x | Eight-byte magic; optional extra byte; transformed runtime; 260-byte names | Supported | Supported |
| `Modern8Plus` | 8.x through 10.x | Doubled magic; transformed runtime; optional Lua runtime; 264-byte names | Supported | Supported |

Setup Factory 3.1 is distributed as multi-file media rather than the later single-file PE overlay. The archived `suf310.zip` contains `SETUP.EXE`, `IRDATA.IRD`, `W31ENG.*`, compressed builder files, and support DLLs. The parser accepts `SETUP.EXE` with its sibling media or `IRDATA.IRD` directly, validates the Crusher catalog, decodes `IRDATA.DAT`, and maps its installed-file records to the companion streams.

## Embedded runtime release identity

Every supported single-file generation contains one outer-catalog entry named `irsetup.exe`. Decoding the catalog record, reversing the 2,000-byte XOR transform where applicable, and reading that PE's version resource provides stronger release evidence than the outer launcher because projects can replace the launcher's product identity. Release evidence remains subordinate to structural dispatch: a trusted runtime that conflicts with the validated overlay profile produces a diagnostic and never changes the record reader.

| Release media | Embedded product name | Embedded original filename | Observed embedded version |
| --- | --- | --- | --- |
| 4.0 | `Indigo Rose Corporation Setup` | `irsetup.exe` or `setup.exe` | 4.0.0.1 and 4.0.0.8 |
| 5.0 | `Setup Factory 5.0 Runtime Module setup32` | `setup32.exe` | 5.0.0.3 and 5.0.1.6 |
| 6.0 | `Setup Factory 6.0 Runtime Module` | `SUF60Runtime.exe` | 6.0.1.2 and 6.0.1.4 |
| 7.0 | `Setup Factory 7.0 Runtime` | `suf70_rt.exe` | 7.0.1.0 through 7.0.6.1 |
| 8.0 | `Setup Factory 8.0 Runtime` | `suf80_rt.exe` | 8.1.1008.0 |
| 9.x | `Setup Factory Runtime` | `suf_rt.exe` | 9.0.3.0 through 9.5.3.0 |
| 10.x | `Setup Factory Runtime` | `suf_rt.exe` | 10.2.0.0 |

The parser requires a numeric four-part runtime version and a compatible product-name/original-filename pair from the format catalog before treating the embedded identity as trusted. Missing or customized version resources remain nonblocking release-evidence diagnostics because the catalog can still prove the installer family and structural route.
