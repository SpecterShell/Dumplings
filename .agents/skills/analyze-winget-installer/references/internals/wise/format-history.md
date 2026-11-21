# Wise format history

## Verified generations

| Builder media | Host | Overlay profile | State-machine status | Evidence |
| --- | --- | --- | --- | --- |
| Wise 5 | NE | `LegacyOverlay` | Header and checksummed WiseScript member supported; state records unresolved | archived `WISE5.EXE`, SHA256 `E54AEA1FD14C4DDFA6DD3B5E0BF0F34BC9207769DAA026C2E5D407B5D3975B31` |
| Wise 6 | NE | `LegacyOverlay` | Header and checksummed WiseScript member supported; state records unresolved | archived `WISE6.EXE`, SHA256 `B3D6D1007351C0BF0FDEDD9235E428E2BEE066BCF8774B0C4EBF3A0E6BBCEFDE` |
| Wise 7.01 | NE | `ExtendedOverlay` | State records, file catalog, variables, registry actions, and execution actions supported | archived `WISE701.EXE`, SHA256 `33C395771CFBDDF220D5BEF5E05F327171033B9DCE982648E26A7FA06B7EDABF` |
| Wise 9.02 | PE or nested PE | `SourceOverlay` | State records and embedded WSE global data supported | both [NavigatorPlus 1.42 installers](https://www.fpmailing.co.uk/support/navigatorplus-support) |
| Wise for Windows Installer | PE `.WISE` section | `WiseSectionMsi` | Exact MSI and trailing CRC32 supported | Texas Instruments TI Connect 4.0.0.218 |

The archived Wise 8 and 9 builder installers are not themselves proof of the setup format emitted by those builders. Their outer packaging may use a different bootstrapper. Generated application media or a distributed application installer is required before adding a route.

## Header evolution

`LegacyOverlay` ends after the declared EOF DWORD. The next bytes are the first Deflate member. `ExtendedOverlay` adds DIB sizes and an endianness marker. `SourceOverlay` also carries the compressed WSE source-listing member and character-set information. The parser selects these tails by bounds and known markers instead of a guessed version number.

## Later products

Wise Package Studio and Symantec-branded tooling continued to produce MSI-oriented packages after the classic WiseScript releases. A package builder string in an MSI is metadata evidence, not proof that its outer executable uses the classic overlay. Route each artifact from its bytes.

## Unsupported history

Wise 5 and Wise 6 state-machine action framing is structurally different from the currently decoded record set. The parser validates the launcher, overlay header, compressed member sizes, output size, and CRC32, then returns `Wise.Metadata.ScriptModelUnsupported`. It does not scan arbitrary strings to fill ProductCode or AppsAndFeaturesEntries.
