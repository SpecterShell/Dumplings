# Kachina internals

This reference describes the Kachina installer structures and runtime behavior consumed by Dumplings. Use the [Kachina workflow](../../families/kachina/workflow.md) for package analysis and WinGet authoring.

The upstream Kachina repository had no declared license when this implementation was written. These pages record independently observed structures and source-backed behavior. The PackageModule parser is independently implemented under Apache-2.0.

## Mental model

Kachina is a PE followed by a TLV record stream. Configuration JSON establishes application identity and host policy. Release metadata maps installed paths to individually compressed content-hash records. An optional compact index cross-checks the early records, but sequential TLV parsing remains authoritative because runtime installers can be appended outside the index.

```text
Kachina setup
+-- PE host
|   +-- optional DOS pre-index
|   `-- Tauri or native runtime
`-- TLV stream
    +-- configuration JSON
    +-- optional image
    +-- optional compact index
    +-- optional release metadata JSON
    +-- Zstandard application records
    +-- HDiff patch records
    `-- raw prerequisite installers

runtime projection
+-- select source and target path
+-- derive elevation from target writability and uacStrategy
+-- install or update payload files
+-- install configured prerequisites
+-- reconstruct updater and uninstaller
`-- write HKLM or HKCU ARP state according to actual elevation
```

The same container spans Tauri and native hosts. Structural generation, host implementation, and packaged application version are separate facts.

## Reading path

1. [Architecture](architecture.md) explains the builder, host, evidence layers, scope, and trust boundary.
2. [Format history](format-history.md) records legacy, early indexed, current indexed, and config-only generations.
3. [Binary format](binary-format.md) defines the pre-index, TLV framing, compact index, payload records, and generated executables.
4. [Metadata model](metadata-model.md) covers configuration, release metadata, identity, sources, runtimes, and system effects.
5. [Setup runtime](setup-runtime.md) describes switches, elevation, source selection, updates, prerequisites, and finalization.
6. [Uninstaller and ARP](uninstaller-and-arp.md) documents registry values, hives, generated uninstall behavior, and matching.
7. [Parser implementation](parser-implementation.md) records detection, extraction, diagnostics, limits, and performance.
8. [Coverage](coverage.md) lists fixtures and unresolved boundaries.

## Structural routes

| Route | Record order | Intended use |
| --- | --- | --- |
| `LegacyScan` | `.config.json`, optional `.image`, `.metadata.json`, payload records | early sequential `!INS` media |
| `EarlyIndexed` | `\0INDEX` before `\0CONFIG` and metadata | first indexed generation with original pre-index ordering |
| `Indexed` | `\0CONFIG`, optional image, `\0INDEX`, `\0META`, payloads | current embedded media |
| `ConfigOnly` | configuration and optional image, no metadata or payload | online installer or updater |

## Source references

- [Kachina repository](https://github.com/YuehaiTeam/kachina-installer)
- [Kachina configuration example](https://github.com/YuehaiTeam/kachina-installer/blob/main/README.md)
- [Kachina builder](https://github.com/YuehaiTeam/kachina-installer/tree/main/src-tauri/src/builder)
- [Kachina argument parser](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/cli/arg.rs)
- [Kachina registry implementation](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/installer/registry.rs)
- [Kachina update and finalization flow](https://github.com/YuehaiTeam/kachina-installer/blob/main/src/App.vue)
