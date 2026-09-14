# Kachina architecture

## Producer and host

Kachina packs one application release into a Windows PE. Tagged releases through 0.5.1 use a Tauri host with a web UI. The later `refactor/native` branch replaces that host with native Win32 and WebView2 code while preserving the pre-index, TLV, metadata, index, and per-file Zstandard container. Host generation and container generation are independent evidence.

The builder starts from a host executable, patches the DOS-area pre-index when that generation uses one, and appends configuration, image, index, metadata, payload, patch, and optional prerequisite records. Installed updater and uninstaller files are reconstructed from the executable prefix rather than stored as ordinary payload records.

## Evidence layers

| Layer | Establishes | Does not establish |
| --- | --- | --- |
| PE host | native architecture, requested execution context, reconstruction prefix | payload architecture or exact builder release |
| DOS pre-index | record start and declared control-record lengths | sequential record validity by itself |
| TLV sequence | physical records, offsets, lengths, control JSON, payload bytes | installed paths without metadata |
| compact index | expected record boundaries | records appended after the indexed set |
| configuration JSON | identity, path defaults, UAC strategy, runtime packages, updater/uninstaller names | release version |
| metadata JSON | version, installed paths, sizes, hashes, patches, deletions | final target-machine state |
| runtime state | selected source, target directory writability, elevation, current version | facts unavailable to static parsing |

## Identity domains

`regName` is the built-in uninstall key name and therefore the ProductCode evidence. `appName` supplies the ARP display name. `tag_name` in release metadata supplies DisplayVersion. Payload record names are content hashes and do not identify installed paths; one hash can back several metadata paths.

The PE version resource can belong to the host or packaged release. It is not used as the format generation. `FormatGeneration` comes from the control-record order and pre-index state.

## Installation paths and scope

The default target is Program Files plus `programFilesPath`, which requires elevation and writes HKLM ARP state. `uacStrategy` controls whether another `-D` target can remain unelevated:

| Strategy | Private target | Writable shared target | Unwritable target |
| --- | --- | --- | --- |
| `force` | elevate | elevate | elevate |
| `prefer-admin` | stay unelevated | elevate | elevate |
| `prefer-user` | stay unelevated | stay unelevated | elevate |

The runtime chooses HKLM when elevated and HKCU otherwise. The parser reports the default machine route and complete supported-scope alternatives. It does not infer user scope merely because the host process used for analysis is unelevated.

## Trust boundary

The repository source had no declared license when the parser was implemented. The Apache-2.0 parser is independently written from format and behavior observations. It may parse JSON, validate hashes, decompress Zstandard records, reconstruct host prefixes, and inspect extracted PE files. It does not execute the installer, fetch online metadata, run prerequisites, apply HDiff patches, or infer dynamic target-directory state.

