# install4j Windows format history

[Back to install4j internals](overview.md).

The useful format identity is the serialized Windows media generation. A PE version resource or packaged application version does not select record layouts.

## Generation matrix

| Generation | Launcher route | Startup framing | Content route | Configuration route |
| --- | --- | --- | --- | --- |
| 3.x | Direct legacy maps | `int32 LE` length plus XOR-88 | inline `content.zip` | `Legacy3Xml` |
| 4.x | Direct legacy maps | `int64 LE` length plus XOR-88 | ContentCollector `.000` LZMA-to-ZIP | `Legacy4Xml` |
| 5.x | CRC-bounded modern overlay | `int64 LE` length plus XOR-88 | ContentCollector `0.dat` | `ModernXml` |
| 6.x-9.x | Modern overlay | same modern framing | LZMA-to-ZIP, optional Pack200 members | `ModernXml` |
| 10.x-13.x | Modern overlay | same modern framing | LZMA-to-ZIP, no Pack200 requirement | `ModernXml` |

## Marker history

Observed generation markers include:

| Generation | Marker family |
| --- | --- |
| 3 | `L-INGO#<digits>-` |
| 4 | `L-EJ_TECHNOLOGIES#<digits>-` and compatible `M4` forms |
| 5-13 | `[LS]-M<major>-<vendor>#<digits>-` |

Vendor builder and package media use tokens such as `EJT`, `PORTSWIGGER_LTD`, `OWASP_ZAP`, and `QOPPA_SOFTWARE_LLC`. The token is not the application publisher field.

The marker is optional in modern application media. A controlled install4j 11.0.5 Windows x64 setup has a valid modern CRC-bounded launcher and complete `i4jparams.conf` but no parameter-2000 marker. In this route, the configuration's explicit builder version selects the generation after launcher validation.

## Character and integer encodings

Legacy and modern parameter maps use UTF-8 and UTF-16LE values with little-endian framing. ContentCollector records retain Java `DataInput` big-endian integers and modified UTF-8 names across generations.

## Runtime packing transitions

Install4j 3 stores an ordinary ZIP startup payload. Later generations use LZMA for the application archive. Pack200 can appear in generations 4 through 9. Generation 10 and later aligns with Java releases where Pack200 is no longer a required reconstruction path. Modern media can target ARM64 as well as x86 and x64.

## Edition attribution

The commercial Windows and Multi-Platform editions share generated Windows media. The license controls builder capabilities and does not add a reliable edition field to the output. Edition attribution from setup bytes is therefore not available.

## Future generations

A future marker can tentatively reuse the newest modern route only when the launcher CRC, counts, ranges, startup records, content table, and stream boundaries all validate. Markerless future media also needs an explicit builder generation in decoded configuration. A nearest-version guess without these checks is unsafe.
