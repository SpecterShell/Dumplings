# Wise parser coverage

## Validated artifacts

| Artifact | Route | Validated behavior |
| --- | --- | --- |
| Texas Instruments TI Connect 4.0.0.218 | `WiseSection/Msi` | exact `.WISE` MSI range and CRC32, ProductCode, UpgradeCode, machine scope, Wise MSI builder, `INSTALLDIR`, MSI ARP ownership, and `.8xp` association |
| [Francotyp-Postalia NavigatorPlus 1.42 x86](https://www.fpmailing.co.uk/support/navigatorplus-support) | `ResourceLauncher/WiseScript` | nested PE at resource offset, Wise 9.02 source metadata, four payload records, exact nested x86 MSI, product metadata, required elevation, and interactive-only wrapper behavior |
| [Francotyp-Postalia NavigatorPlus 1.42 x64](https://www.fpmailing.co.uk/support/navigatorplus-support) | `ResourceLauncher/WiseScript` | same route with a distinct x64 MSI payload and checksum |
| Archived Wise 7.01 builder setup | `NewExecutable/WiseScript` | NE overlay location, extended header, script state, 577 payload records, variables, execution records, and candidate custom ARP row |
| Archived Wise 5 builder setup | `NewExecutable/WiseScript` | NE overlay, legacy header, Deflate framing, output size, and CRC32; state dialect unresolved |
| Archived Wise 6 builder setup | `NewExecutable/WiseScript` | NE overlay, legacy header, Deflate framing, output size, and CRC32; state dialect unresolved |

The Navigator x86 outer file SHA256 is `CD1DF5C8CC990548D1E4C8EC5FD0DB12597C11C8D7F4E760287B08F5FA0716E7`; its extracted MSI SHA256 is `A479C35EBCE11739BFB56E2A4E68C4D2199AEA698390E648EAF9219769D25DF0`. The Navigator x64 outer file SHA256 is `7D740E864BCE3984E74FD5FC816B09EDB4A25700428551CD98B890F6200EE1CC`; its extracted MSI SHA256 is `6DE58160CCA1612E7158B2644505929E1A0CEB99BCC7B4F240ACCD30EDF8C936`.

## Supported capabilities

The current parser supports structural family detection, route and profile classification, PE and NE containers, version-dependent WiseScript headers, raw-Deflate and CRC validation, Wise 7 and 9 state projection, WSE global metadata, variables, payload catalogs, registry and execution evidence, custom ARP candidates, nested Wise MSI selection, direct `.WISE` MSI extraction, MSI-owned metadata, scope, architecture, associations, and scenario-aware diagnostics.

## Known limits

Wise 5 and 6 state-machine action framing is not decoded by the pinned reader. Their container identity and checksummed script member are supported, but ProductCode, ARP values, and file catalogs remain unresolved.

The parser does not evaluate the complete WiseScript control-flow graph. Custom ARP rows remain candidates until VM evidence establishes active branches. External DLL effects, runtime environment values, downloads, generated uninstallers, and nested process side effects remain opaque.

Pure WiseScript extraction currently exposes catalog and exact-record mechanics internally, while the public extractor exports the authoritative embedded MSI for supported MSI-owned routes. General installed-file extraction should not be advertised until destination mapping and condition handling are exposed through the public API.

Builder packages for Wise 8, 8.12, 8.14, 9, 9.01, and 9.02 are available as research media, but a builder's own installer is not necessarily representative of media emitted by that version. Add generated application fixtures before claiming a new format profile or behavior boundary.

## Next evidence priorities

The highest-value remaining work is a source-backed Wise 5/6 state decoder, controlled Wise 8 and 9 application media, VM comparison for a pure WiseScript custom ARP package, and public all-file extraction with explicit handling for condition-dependent duplicate destinations. These gaps must not be filled by product-string guessing.
