# Omaha internals

[Back to Chromium Setup parser internals](overview.md).

## Binary structure

```text
Omaha metainstaller PE
+-- B resource ID 102
|   `-- LZMA -> BCJ2 -> TAR
|       +-- offline manifest
|       `-- configured EXE payload
`-- certificate table              optional Omaha tag
```

```text
Omaha UTF-8 tag in certificate table
Offset  Size       Field
------  ---------  --------------------------------
0x00    12         ASCII "Gact2.0Omaha"
0x0C    2          TagLength, uint16 BE
0x0E    TagLength  query string, UTF-8
```

## Parsing behavior

Read only resource ID `102`, decode the bounded LZMA and BCJ2 streams, then enumerate the TAR catalog. Select the executable configured by the decoded package metadata rather than scanning the entire installer for an arbitrary EXE.

## Metadata projection

The certificate tag identifies the updater application and request parameters. It is not ARP ProductCode evidence. Analyze the selected nested executable to obtain target application metadata and switch behavior.

## Limits and gaps

Validate resource bounds, tag length, decompressed sizes, BCJ2 ranges, TAR entries, and safe output paths. Online Omaha packages without a target payload require network or VM evidence and must not project the outer updater version as the target version.
