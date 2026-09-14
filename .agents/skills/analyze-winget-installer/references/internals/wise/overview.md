# Wise installer internals

This reference describes the Wise Installation System structures and runtime behavior consumed by Dumplings. Use the [Wise workflow](../../families/wise/workflow.md) when analyzing a package or authoring a WinGet manifest.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Mental model

"Wise Installer" names several related products and output formats. Classic WiseScript media is a native executable followed by a versioned overlay. The overlay begins with runtime and member sizes, then contains raw-Deflate members, a WiseScript state machine, and compressed file records. Wise for Windows Installer uses a PE `.WISE` section that contains a complete MSI database and a trailing CRC32. A vendor can also place a complete WiseScript setup inside another launcher's PE resources.

```text
distributed executable
+-- DOS MZ stub
+-- NE host, PE host, or vendor PE launcher
+-- optional PE resources and Authenticode certificate
`-- selected Wise route
    +-- WiseScript overlay
    |   +-- versioned overlay header
    |   +-- compressed runtime members
    |   +-- compressed WiseScript state machine
    |   +-- optional embedded WSE source listing
    |   `-- compressed InstallFile records
    `-- .WISE section
        +-- Wise runtime metadata
        +-- MSI CFB database
        `-- CRC32 trailer
```

Container identity, script effects, and installed-product identity are separate. A WiseScript wrapper can extract and execute a nested Wise MSI launcher. In that route the nested MSI supplies ProductCode and UpgradeCode, while the outer script controls elevation and whether command-line options reach the MSI.

## Evidence vocabulary

| Evidence | Establishes | Does not establish |
| --- | --- | --- |
| Valid NE or PE structure plus a bounded Wise overlay header | WiseScript container route | Product identity or active script branches |
| Raw-Deflate member with matching trailer CRC32 | Physical member boundary and content integrity | Runtime execution of that member |
| Decoded WiseScript state record | A compiled operation and its operands | Whether a conditional branch runs on the target machine |
| Literal uninstall-key action | Candidate ARP identity and values | Visibility without condition and VM evidence |
| Valid `.WISE` MSI record with MSI root CLSID and CRC32 | Exact nested MSI bytes | Outer-wrapper switch forwarding |
| Parsed MSI tables | MSI ProductCode, UpgradeCode, package architecture, associations, and explicit scope | Behavior added or suppressed by the outer WiseScript runtime |
| VM installed-state comparison | Active ARP row, installed files, scope, and switch behavior for that fixture | A rule for unrelated Wise generations |

## Reading path

1. [Architecture](architecture.md) explains the producer families, runtime layers, and identity ownership.
2. [Format history](format-history.md) records the verified Wise 5 through 9 routes and later MSI-oriented products.
3. [Binary format](binary-format.md) defines the NE, PE, overlay, Deflate, WiseScript, and `.WISE` MSI framing.
4. [Metadata model](metadata-model.md) covers variables, state records, file catalogs, nested execution, and unresolved expressions.
5. [Setup runtime](setup-runtime.md) covers switches, elevation, nested MSI launch behavior, and architecture.
6. [Uninstaller and ARP](uninstaller-and-arp.md) explains custom WiseScript keys and MSI-owned ARP rows.
7. [Parser implementation](parser-implementation.md) records detection, bounded parsing, extraction, diagnostics, and performance constraints.
8. [Coverage](coverage.md) lists validated fixtures and remaining gaps.

## Current structural routes

| Route | Physical structure | Current support |
| --- | --- | --- |
| `NewExecutable/WiseScript` | 16-bit NE host plus WiseScript overlay | Wise 7.01 state records are decoded; Wise 5 and 6 headers and members are validated but their state-machine records remain partial |
| `WiseScript/Overlay` | PE host plus WiseScript overlay | Header, state records, file catalog, registry actions, execution actions, and nested Wise MSI selection |
| `ResourceLauncher/WiseScript` | vendor PE resource range containing a complete WiseScript PE | Outer and nested PE bounds, WiseScript records, exact payload extraction, and nested Wise MSI selection |
| `WiseSection/Msi` | PE `.WISE` section containing one complete MSI and CRC32 | Exact MSI range, checksum, metadata, associations, architecture, scope, and install-location property |

`FormatProfile` distinguishes `LegacyOverlay`, `ExtendedOverlay`, `SourceOverlay`, and `WiseSectionMsi`. The profile is derived from physical header fields and does not depend on PE version strings.

## Source references

- [WiseUnpacker](https://github.com/mnadareski/WiseUnpacker), an MIT-licensed Wise container research tool maintained by Matt Nadareski
- [SabreTools.Serialization](https://github.com/SabreTools/SabreTools.Serialization), whose MIT-licensed NE and WiseScript readers are used by the parser
- [Wise Installation System archive](https://archive.org/details/wise-installer), used for Wise 5 through 9.02 builder media and runtime comparisons
- [Wise Installation System at WinWorld](https://winworldpc.com/product/wise-installmaster/9x), used to cross-check product chronology
- [Archived Wise download host](https://web.archive.org/web/*/http://209.104.132.210/*), used to locate historical vendor media
- [NavigatorPlus support](https://www.fpmailing.co.uk/support/navigatorplus-support), the vendor support page that publishes the supplied 1.42 x86 and x64 installers
