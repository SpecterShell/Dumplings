# install4j parser implementation notes

[Back to install4j internals](overview.md).

This page maps the shipped structures to Dumplings. User-facing parser commands and WinGet decisions belong in the [install4j package workflow](../../families/install4j/workflow.md).

## Catalog routing

`Install4jFormatCatalog.psd1` assigns each generation a launcher, startup-file, content-table, payload, and configuration route. Readers dispatch through route maps rather than checking version thresholds while decoding records.

Markers select a descriptor when present. A complete markerless modern launcher is retained as structural evidence; the parser then decodes its bounded `i4jparams.conf` startup entry and resolves the generation from explicit `install4jVersion` data. The selected descriptor must use the already validated launcher route.

## Analysis context

One top-level parse opens the installer once and builds this context:

```text
resolved source
+-- PE layout and version resource
+-- launcher probe and parameter maps
+-- startup-file ranges
+-- catalog descriptor
+-- ContentCollector table
+-- decoded configuration XML
+-- bounded fallback strings
`-- warnings and format evidence
```

Metadata projection and extraction consume that context. Format-independent PE, binary, CRC, LZMA, ZIP, path, and collision behavior stays in shared infrastructure.

## Detection order

1. Accept a complete standalone install4j configuration document.
2. Parse the PE overlay with modern and legacy launcher routes.
3. Resolve a marker-backed descriptor when possible.
4. Parse catalog records and startup-file ranges.
5. Decode `i4jparams.conf`; use its explicit version for a markerless route.
6. Use bounded strings only to identify structurally incomplete media.

PE version strings do not select a generation. A ContentCollector table alone can identify install4j media but does not establish a payload decoder.

## Metadata projection

Product identity comes from `applicationId`. ARP ownership comes from `RegisterAddRemoveAction` or the catalogued legacy behavior. Scope is projected from privilege-action properties with confidence and supporting evidence. Associations come from explicit standard actions.

Missing dynamic values remain unresolved. PE product metadata is a fallback for display fields, not ProductCode or builder generation.

## Bounds and malformed input

The parser bounds parameter counts and strings, startup-file lengths, modern data ranges, CRC input, ContentCollector entries, cumulative payload sizes, LZMA output, ZIP entries, extraction paths, and collision handling. Caller-owned streams retain position and ownership.

A future descriptor is accepted only after complete structural validation. An unsupported but identifiable result must explain the missing route and list metadata that could not be recovered.

## Performance considerations

Large payloads remain bounded streams. Only the decoded nested archive is materialized when SharpCompress requires seeking. Configuration XML and startup metadata are read once. Selective extraction avoids expanding unrelated files.

The catalog refactor reduced warm parsing of the 96,658,232-byte install4j 9.0.7 builder from a 437.16 ms median and 28,107,024 managed bytes to 373.36 ms and 19,637,816 managed bytes in the recorded local benchmark. These values are diagnostic, not CI thresholds.
