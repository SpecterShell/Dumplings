# Google Updater internals

[Back to Chromium Setup parser internals](overview.md).

## Binary structure

Current Google Updater packages use the [Chromium Updater](chromium-updater.md) packed-resource, offline-bundle, and certificate-tag layout. Older Google Update packages use the [Omaha](omaha.md) metainstaller layout.

## Parsing behavior

Classify the container before interpreting updater metadata. For the current format, match the protocol application identity to its offline manifest and configured target installer. Route legacy resource ID `102` payloads through the Omaha decoder.

## Metadata projection

Keep updater identity and version separate from the target application's version and visible ARP entry. The parser does not project ProductCode from Google Updater, its application identity, or its target payload.

## Limits and gaps

An online bootstrapper may expose only updater metadata. Preserve existing target fields and emit unresolved evidence when no bounded offline target package is available.
