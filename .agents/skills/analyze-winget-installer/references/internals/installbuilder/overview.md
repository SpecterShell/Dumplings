# InstallBuilder parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [InstallBuilder workflow](../../families/installbuilder/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured InstallBuilder variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

InstallBuilder embeds project data in a TclKit/Metakit VFS and payload files in CookFS. Dumplings parses these byte records directly; it does not load Tcl or execute project scripts.

```text
PE/TclKit launcher
+-- Metakit VFS
|   `-- zlib-compressed project.xml
`-- CookFS
    +-- stored file pages
    +-- page-size table             PageCount * uint32 BE
    +-- compressed file index       starts with "CFS2.200"
    +-- 16-byte footer fields
    `-- 43 46 53 30 30 30 32       "CFS0002"
```

```text
Base                  Offset  Size  Field
--------------------  ------  ----  --------------------------------------
[before CFS0002 end]  -0x10   4     Stored index size, uint32 BE
[before CFS0002 end]  -0x0C   4     PageCount, uint32 BE
[before CFS0002 end]  -0x08   1     Index compression identifier
[index]               0x00    8     Magic: "CFS2.200"
[index node]          varies  ...   names, child counts, block lists, BE
```

A stored CookFS record begins with a compression ID: `0`/`1` stored/Deflate, `2` BZip2, and `255` custom. InstallBuilder's supported custom `lzmadec` form carries an LZMA-alone header; encrypted/custom alternatives are rejected. Index and page counts, sizes, recursion, cache bytes, output, and safe paths are bounded. `___bitrockBigFileN` entries are physical segments reassembled into one logical file.

## Detection invariants

Accept the family only when the surrounding headers, ranges, counts, and relationships described above validate. Treat an isolated marker as a routing hint and preserve conditional values as unresolved evidence.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/InstallBuilder.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [InstallBuilder loader research](https://gist.github.com/mickael9/0b902da7c13207d1b86e)
