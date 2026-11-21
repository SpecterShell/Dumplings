# install4j coverage and remaining work

[Back to install4j internals](overview.md).

Coverage is measured by physical route and runtime evidence. Recognizing an install4j string or builder version does not make an unsupported payload route readable.

## Implementation parity

| Capability | install4j behavior | Current implementation | Status and next work |
| --- | --- | --- | --- |
| Generation catalog | Windows media generations use distinct launcher, startup, content, and configuration routes. | One complete descriptor exists for generations 3 through 13. | **Implemented.** Add a descriptor only for a source-backed structural change. |
| Legacy launchers | Generation 3 uses 32-bit startup lengths; generation 4 uses 64-bit lengths. | Both parameter-map and startup-file routes are bounded and decoded. | **Implemented with official media.** |
| Modern marker-backed launchers | Generations 5-13 use a CRC-bounded overlay and often record a parameter-2000 marker. | CRC, maps, nested maps, startup order, and complete consumption are validated. | **Implemented with official and package media.** |
| Modern markerless launchers | Generated application media can omit parameter 2000 while retaining a complete modern block and versioned `i4jparams.conf`. | A CRC-valid, fully consumed launcher with one bounded configuration entry can select a same-route descriptor from explicit builder-version evidence. | **Implemented with controlled install4j 11 media.** |
| ContentCollector | Java-style descriptors map names to contiguous payload ranges. | Big-endian counts, modified UTF-8 names, lengths, and cumulative ranges are validated. | **Implemented.** |
| Configuration schemas | Generation 3, generation 4, and modern XML have different representations. | Three schema routes recover application metadata, selected actions, privilege settings, and associations. | **Implemented for observed standard objects.** Custom classes remain opaque. |
| ARP and scope | Registration and privilege actions determine visible identity and possible registry roots. | Application ID, standard registration, and privilege-dependent scope are projected with evidence. Machine-only and user-fallback action settings are covered by controlled media. | **Implemented for standard actions.** Runtime conditions and custom code require VM validation. |
| Generation-3 payload | `content.zip` is an XOR-transformed startup file. | Selective safe ZIP extraction is supported. | **Implemented with official media.** |
| Generation-4 payload | A catalogued `.000` LZMA stream expands to ZIP. | Bounded LZMA and selective ZIP extraction are supported. | **Implemented with official media.** |
| Modern payload | `0.dat` normally expands through LZMA to ZIP. | Bounded decoding, entry limits, traversal rejection, and collision handling are supported. | **Implemented with install4j 9, package media, and paired install4j 11 runtime media.** |
| Pack200 members | Older Java payloads can contain Pack200 data. | Packed members can be exported but are not reconstructed. | **Not required for current metadata analysis.** |
| External/downloaded data | A setup can omit files acquired at installation time. | Local launcher and configuration metadata remain available. | **Partial by design.** Missing remote content cannot be reconstructed. |
| Architecture | Media can target x86, x64, and later ARM64. ARM64 configuration still records `bitness="64"`. | PE machine and configuration bitness are combined, so PE evidence distinguishes x64 from ARM64. | **Implemented and validated with controlled install4j 11 x86, x64, and ARM64 media.** |
| Bundled runtime evidence | Media can include a private runtime or require an installed Java release. | `general@jreVersion`, `general@minJavaVersion`, and the startup-file catalog are combined into explicit bundled-runtime evidence. Contradictions produce warnings. | **Implemented with paired install4j 11 bundled and runtime-independent media.** |
| Unsupported media diagnostics | Structurally identifiable media should preserve route evidence and explain missing metadata. | Unsupported media reports descriptor-selection failure and lists metadata blocked by absent configuration. | **Implemented for structural table and launcher routes.** Add format-specific warnings when new unsupported routes are observed. |
| Pre-3.x and unidentified forks | No complete supported route is established. | Media remains structurally unsupported instead of using a nearest guess. | **Unsupported until reliable format evidence exists.** |
| Commercial edition | A license controls build capabilities rather than output structure. | No edition property is emitted. | **Not recoverable from media.** |

## Highest-priority correctness work

1. Add external/downloadable-data media when a local metadata route differs from the current launcher and configuration paths.

## Controlled-builder work

The next useful fixtures are generated application media rather than more builder installers:

- Paired bundled-runtime and runtime-independent x64 setups.
- x86 and ARM64 media when a future generation changes launcher or configuration behavior.
- Additional privilege or association actions only when their serialized class or defaults differ.
- Literal protocol actions when install4j introduces a standard protocol-specific bean.
- External/downloadable application-data media.

Builders and generated installers run only in the checkpointed Hyper-V VM. Generated fixtures are copied to the persistent sibling `Dumplings-TestFixtures` cache before host-side static analysis.

## Fixture parity

| Route | Real coverage | Important addition |
| --- | --- | --- |
| Generation 3 | Official install4j 3.2.5 builder media and inline payload extraction. | Controlled application media if an archived licensed builder becomes practical. |
| Generation 4 | Official 4.1 and 4.2.8 builder media and `.000` extraction. | No addition unless another framing variant appears. |
| Generation 5 | Official 5.0.11 and 5.1.15 builder media. | Package media only if its route differs. |
| Generations 6-8 | Official 6.1.6, 7.0.12, and 8.0.11 builder media. | No addition unless configuration or payload behavior differs. |
| Generation 9 | Official 9.0.7 media with metadata and selective payload extraction. | Controlled scope or association output from the available builder. |
| Generation 10 | Official 10.0.9, ZAP, and Qoppa PDF Studio. | Controlled ARM64 output if supported by the builder. |
| Generation 11 | Official 11.0.5 builder media; paired markerless x64 media with and without Java 21.0.12; controlled x86, ARM64, user-fallback scope, and file-association media. | Add variants only for distinct serialized evidence. |
| Generations 12-13 | Official 12.0.5 and 13.0.2 builder media; PortSwigger covers generation 12 package behavior. | Add application media only for a new route. |

## Sources

- [install4j documentation](https://www.ej-technologies.com/resources/install4j/help/doc/)
- [install4j change log](https://www.ej-technologies.com/install4j/changelog)
- [install4j media files](https://www.ej-technologies.com/resources/install4j/help/doc/concepts/mediaFiles.html)
- [install4j launchers](https://www.ej-technologies.com/resources/install4j/help/doc/concepts/launchers.html)
