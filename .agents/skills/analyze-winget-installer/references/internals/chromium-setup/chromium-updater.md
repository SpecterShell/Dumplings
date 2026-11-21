# Chromium Updater internals

[Back to Chromium Setup parser internals](overview.md).

## Binary structure

```text
Chromium Updater PE
+-- B7 updater.packed.7z
|   `-- updater.7z
|       +-- bin/updater.exe
|       `-- bin/Offline/{bundle-guid}
|           +-- OfflineManifest.gup or {app-id}.gup
|           `-- {app-id}/target installer
`-- certificate table              optional framed updater tag
```

The source-defined certificate tag uses bounded UTF-16LE start and end markers, `Gact2.0Omaha` and `ahamO0.2tcaG`. Microsoft Edge uses the bounded `MSEDGE_` and `_EGDESM` framing.

## Parsing behavior

Open the `B7` resource named `updater.packed.7z`, select `updater.7z`, and inspect the bounded offline bundle. Match the tag's application identity to the corresponding offline manifest before selecting the configured target installer.

## Metadata projection

Treat the updater `appguid` as update-protocol identity, never as the target application's ARP `ProductCode`. Project target version and executed payload only after the matching offline manifest and installer validate. Leave ProductCode unresolved even when a nested target is available.

## Limits and gaps

Tagged online bootstrappers do not contain authoritative target metadata. Return no target version when the matching offline bundle is absent. ProductCode is always unresolved. Bound certificate-table reads, nested archive sizes, manifest selection, and extracted payload paths.
