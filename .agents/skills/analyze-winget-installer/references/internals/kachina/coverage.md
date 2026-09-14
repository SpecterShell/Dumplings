# Kachina coverage

## Supported capabilities

| Capability | `LegacyScan` | `EarlyIndexed` | `Indexed` | `ConfigOnly` |
| --- | --- | --- | --- | --- |
| structural detection | yes | yes | yes | yes |
| configuration metadata | yes | yes | yes | yes |
| release metadata | yes when present | yes when present | yes when present | no |
| compact-index validation | not applicable | yes, including historical offset defect | yes | cleared pre-index only |
| payload catalog and extraction | yes | yes | yes | no embedded payload |
| MD5 and XXH3-128 verification | according to metadata | according to metadata | yes | not applicable |
| updater/uninstaller reconstruction | yes | yes | yes | yes from control prefix |
| ARP identity and scope variants | yes | yes | yes | identity known; version waits for source metadata |
| runtime package catalog | appended records | appended records | yes | online/configuration evidence only |
| HDiff patch application | no | no | no | no |

## Persistent fixtures

| Fixture | Route | Regression purpose |
| --- | --- | --- |
| AkashaNavigator 1.4.0 | current `Indexed` | MD5/XXH3 payload mapping, main PE analysis, two configured runtime packages, patches, reconstruction, and WinGet projection |
| BetterGI 0.40.0 | current `Indexed` | earlier production metadata with 229 payload paths and no configured runtime packages |
| BetterGI 0.63.0 | current `Indexed` | 1,628 payload paths plus embedded/downloadable .NET and VC runtime evidence |

Synthetic fixtures cover all four structural generations, both pre-index field orders, invalid offsets, config-only records, source catalogs, each UAC strategy, missing source URIs, runtime records omitted from the compact index, duplicate paths, traversal, collisions, decompression size mismatch, and hash mismatch.

All three production fixtures return no unresolved metadata fields. Their informational scope and prerequisite diagnostics describe supported runtime alternatives rather than missing parser output.

## Known boundaries

| Boundary | Current handling | Evidence needed to extend it |
| --- | --- | --- |
| HDiff patches | catalog old/new hash and patch record | independently licensed HDiff provider plus source-backed patch fixtures |
| config-only target data | return source and unresolved target fields | caller retrieves exact source metadata and payloads outside parser |
| source failover and hidden selection | preserve ordered source records | runtime network evidence |
| downloaded prerequisites | report configured package identifiers | exact downloaded artifacts and child-parser evidence |
| target directory state | return all UAC routes | VM evidence for selected `-D` path |
| first-run application effects | outside installer projection | after-first-run installed-state snapshot |
| exact builder release | report structural compatibility range | explicit structured release identity |

These limits should remain until a package requires the route and supplies deterministic source or fixture evidence. Implementing an updater, network client, or arbitrary prerequisite runner inside the parser would cross the static-analysis boundary.
