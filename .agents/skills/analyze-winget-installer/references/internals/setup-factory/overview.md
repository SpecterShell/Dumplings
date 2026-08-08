# Setup Factory parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Setup Factory workflow](../../families/setup-factory/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Setup Factory variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Setup Factory appends a versioned file table to the PE overlay. The embedded runtime is lightly transformed, while each catalog entry has its own compressed payload and CRC.

```text
PE setup stub
`-- overlay
    +-- v7 or v8/9 signature
    +-- transformed irsetup.exe runtime
    +-- optional lua5.1.dll (v8/9)
    +-- EntryCount, uint32 LE
    `-- repeated file records
        +-- fixed UTF-8/NUL name field
        +-- PackedSize
        +-- CRC32
        +-- optional padding
        `-- LZMA/LZMA2/PKWARE-compressed data
```

```text
Variant  Initial fields after signature
-------  -------------------------------------------------------------
7        skip 9 bytes; RuntimeSize uint32 LE; names are 260 bytes;
         PackedSize uint32 LE
8/9      skip 26 bytes; RuntimeSize int64 LE; optional Lua length/data;
         names are 264 bytes; PackedSize int64 LE; 4 observed pad bytes
```

Version 7 magic is `E0 E1 E2 E3 E4 E5 E6 E7`; versions 8/9 use `E0 E0 E1 E1 E2 E2 E3 E3 E4 E4 E5 E5 E6 E6 E7 E7`. Only the first 2,000 runtime bytes are XORed with `0x07`. `irsetup.dat` contains structured session variables, uninstall configuration, and Lua actions. Entry count, names, sizes, CRC32, compression output, PKWARE back-references/end marker, variable recursion, and extraction paths are bounded.

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

- Modules/PackageModule/Libraries/Installers/SetupFactory.psm1
- Modules/InstallerParsers/Libraries/Installers/SetupFactory.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [sfextract](https://github.com/CybercentreCanada/sfextract)
- [SFUnpacker](https://github.com/Puyodead1/SFUnpacker)
- [defactory](https://codeberg.org/CYBERDEV/defactory)
- [zlib](https://github.com/madler/zlib)
