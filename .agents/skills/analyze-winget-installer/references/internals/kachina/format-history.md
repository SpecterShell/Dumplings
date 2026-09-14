# Kachina format history

Kachina release numbers are not stored as an authoritative builder version in the container. The parser reports structural generations and a source-backed compatibility range.

| Structural generation | Known release boundary | Control-record order | Index state |
| --- | --- | --- | --- |
| `LegacyScan` | 0.0.1 through 0.0.17 | `.config.json`, optional `.image`, `.metadata.json`, payloads | no compact index or pre-index routing |
| `EarlyIndexed` | 0.0.18 | `\0INDEX`, `\0CONFIG`, optional `\0IMAGE`, `\0META` | original pre-index order; first field can include the historical INDEX-header double count |
| `Indexed` | 0.0.19 and later embedded media | `\0CONFIG`, optional `\0IMAGE`, `\0INDEX`, `\0META` | corrected order and validated boundaries |
| `ConfigOnly` | observed from 0.0.25 | `\0CONFIG`, optional image; metadata and payload absent | five pre-index lengths are zero and target data comes from the configured source |

## Host transitions

The tagged Tauri releases and the later native branch can both use `Indexed` or `ConfigOnly` media. The host rewrite does not define a new payload format. Detection must therefore use structured TLV and JSON evidence rather than Tauri strings, WebView2 imports, or UI resources.

## Metadata hash transitions

Legacy metadata uses `md5` record identities. Current metadata can use `xxh`, interpreted as XXH3-128 according to the builder/runtime source and fixture verification. The parser chooses the field present on each metadata item and verifies decompressed bytes with that algorithm. An unknown hash label remains unsupported; it is not guessed from its width.

## Index compatibility

The compact index is advisory cross-check evidence. Sequential TLV parsing is authoritative because runtime packages may be appended after the indexed records. Every indexed tuple must resolve to an actual sequential TLV boundary. A malformed index does not authorize seeking to arbitrary file ranges.

## Runtime feature stability

The proven `-S`, `-I`, `-D`, `-O`, and `-U` command-line forms span the supported generated media. Configuration source catalogs, runtime package arrays, mirror/update fields, and metadata deletion lists were added over time but remain ordinary JSON fields. Unknown fields are preserved in `Configuration` or `Metadata` and do not change parser routes.

