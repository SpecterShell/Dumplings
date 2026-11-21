# QSetup format history

QSetup changed its overlay preamble, footer, action layout, and media options while retaining length-prefixed zlib records and a compiled `Setup.txt` instruction stream.

| Reported generation | Verified releases | Preamble | Footer | Execution layout |
| --- | --- | --- | --- | --- |
| `Legacy1-2` | 1.0 and 2.0 | records begin directly at the PE overlay | `Compact12` | `LegacyFourCommand` |
| `Legacy3-6` | 3.0 through 5.0 | version plus literal `||` and UTF-8 preamble | `Legacy74` | `LegacyFourCommand` |
| `Legacy3-6` | 6.0 | version plus literal `||` and UTF-8 preamble | `Legacy74` | `TransitionalFourCommand` |
| `Legacy7-11` | 7.0 through 11.0 | version, compression byte, and UTF-8 preamble | `Legacy74` | `ModernSixCommand` |
| `Modern12` | 12.0 | versioned preamble | `Modern74` with marker 1234 | `ModernSixCommand` |

## Verified transition evidence

Archived builder media establish direct records through 2.0, the double-pipe preamble from 3.0 through 6.0, and the versioned preamble from 7.0 onward. QSetup 6.0 keeps the earlier container but introduces a 67-field Execution Engine record with modern condition descriptors, four command slots, shifted argument arrays, and seven observed tail fields. QSetup 9.1.0.6, 10.0.2.1, and 11.0.0.0 retain the legacy 74-byte terminal record and six-command Execution Engine layout, so the structural generation is `Legacy7-11` rather than the former `Legacy7-8` label.

QSetup 12 introduces the marker-bearing 74-byte footer and verified split-kernel and companion media. Spanned concatenation and external non-SFX payloads are independent media routes rather than version labels.

## Uninstaller naming history

Explicit `SET_UNINSTALL_EXE_NAME` and exact compiled shortcut targets are authoritative in every generation. When both are absent, controlled evidence supports `UnInstall_<stamp>.exe` through QSetup 7 and `<media>_<stamp>.exe` in QSetup 12. The builder installers for 8.1, 9.1, 10.0, and 11.0 use explicit names, so they do not establish the blank-name rule for 8 through 11.

## Compatibility policy

`FormatGeneration` describes the validated combination of preamble and terminal structure. `SET_COMPOSER_BUILD` and PE version resources are release evidence only. A later release may use an older structural route, and a wrapper can contain another QSetup package. The parser follows the bytes and reports nested routes independently.
