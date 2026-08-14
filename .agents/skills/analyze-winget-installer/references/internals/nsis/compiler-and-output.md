# NSIS compiler and output assembly

[Back to NSIS internals](overview.md).

MakeNSIS is a source compiler. It does not place the `.nsi` text in the output as the installation program. It preprocesses and parses the text, emits command and metadata records, compresses payload data, and appends the resulting archive to a selected executable stub.

## Source processing stages

```text
.nsi source and included .nsh files
        |
        v
preprocessor
  !define, !include, !macro, !insertmacro, conditionals,
  compile-time file operations, !system, !packhdr, !finalize
        |
        v
token parser
  attributes, pages, sections, functions, labels, commands
        |
        v
intermediate build state
  headers, pages, sections, entries, strings, languages,
  installer payload, uninstaller payload, PE resources
        |
        v
address resolution and optimization
        |
        v
stub customization + archive assembly
```

Preprocessor effects do not survive as runtime instructions. A macro invocation survives only through the commands, strings, and files it emitted.

## Command emission

Each runtime command becomes one `entry` record. The first integer is an opcode; the remaining integers are opcode-specific operands. The compiler interns text in a shared string table and writes offsets into entries. Immediate integers are also represented through the compiler's integer-string encoding where the runtime expects a string expression.

Labels, functions, callbacks, page handlers, and section code are first recorded symbolically. `resolve_coderefs` converts them to one-based instruction addresses before headers are serialized. Runtime jump value zero means fall through; nonzero values are converted back to a zero-based table position by subtracting one.

Conditional include libraries do not add a second bytecode language. LogicLib, Sections.nsh, MultiUser.nsh, x64.nsh, and similar helpers emit ordinary NSIS commands and plug-in calls.

## Strings and language data

The compiler deduplicates strings where allowed and encodes variables, shell folders, language references, and escaped characters as control sequences. ANSI and Unicode targets use different code-unit widths. NSIS 2, official NSIS 3, and Jim Park Unicode use different control values and packed-number rules.

Localized strings are placed in per-language tables. A negative command string offset identifies a language-table slot instead of the global string block. Language files also provide built-in runtime text used by standard pages and errors.

## Page and section construction

Page declarations produce page records with dialog IDs, flags, captions, and callback addresses. PageEx and Modern UI macros configure the same underlying records and resources.

Section declarations produce section records containing the section name, selected flags, installation-type masks, size, command start, and command count. Functions are command ranges referenced by call operands and callback fields; they do not have a separate serialized instruction format.

## Payload catalog and deduplication

`File` commands enumerate source files at compile time. Each emitted extraction entry stores the destination string, data-block offset, timestamps, overwrite policy, and related flags. Multiple extraction commands may refer to the same compressed data offset when the compiler deduplicates payload bytes.

The active compressor determines physical framing:

- non-solid output stores independently framed items;
- solid output compresses the logical header and data block as one stream;
- stored output copies bytes without a codec;
- NSISBI can use wider offsets, multithread-wrapper blocks, or external data.

The standard compressor choices are zlib, BZip2, and LZMA. Current NSIS source also contains target- and branch-specific additions; a reader must identify the actual framing rather than infer it from a script string.

## Common-header construction

`PrepareHeaders` serializes the current build state in block order:

```text
common header
+-- block descriptors
+-- pages
+-- sections
+-- entries
+-- strings
+-- language tables
+-- control colors
+-- optional background font
`-- data-block descriptor
```

Block descriptors are serialized as offsets plus counts or byte sizes. The runtime later adds the decompressed-header base to convert serialized offsets into memory pointers. Pointer width follows the selected executable target.

## Executable-stub preparation

Before writing output, the compiler loads the target stub and applies authored PE settings. These can include:

- installer and uninstaller icons;
- requested execution level and compatibility manifest;
- version resources;
- standard and custom dialogs;
- bitmaps and fonts;
- checksums, subsystem, and security-related PE fields;
- a post-build header transform requested through `!packhdr`.

`!packhdr` allows an author to transform the stub after compilation. The runtime still needs to locate its archive, but a transformed or outer-packed PE can make the nearby-stub layout differ from stock output.

## Uninstaller construction

Installer and uninstaller compilation states are separate. Uninstall sections, functions, callbacks, strings, and payload form a second logical archive. The compiler prepares an uninstaller stub and stores the generated bytes in the installer data block. The runtime `WriteUninstaller` command writes those bytes to the requested target path.

The application uninstall key is not generated by this build step. The script must emit registry commands that create it.

## Final file assembly

For standard single-file output, assembly is approximately:

```text
customized executable stub
firstheader
packed logical header
payload data block
optional CRC32
```

The archive start is normally padded to a 512-byte boundary. Embedded and outer-wrapper arrangements can place a complete NSIS PE inside a resource or another file. Archive discovery therefore validates the surrounding PE and all declared ranges instead of searching for `NullsoftInst` alone.

## What compilation removes

The output usually cannot recover:

- comments and original source formatting;
- macro names and include boundaries;
- original labels after address resolution;
- symbolic expressions that compiled to immediate operations;
- source paths for payload files;
- an exact compiler release when ABI-compatible releases emitted the same data;
- behavior hidden inside native plug-ins.

Static analysis reconstructs the runtime program, not the original `.nsi` file.

## Source references

- [NSIS script parser](https://github.com/NSIS-Dev/nsis/blob/master/Source/script.cpp)
- [NSIS build implementation](https://github.com/NSIS-Dev/nsis/blob/master/Source/build.cpp)
- [NSIS serialized writer](https://github.com/NSIS-Dev/nsis/blob/master/Source/fileform.cpp)
- [NSIS compiler commands](https://nsis.sourceforge.io/Docs/Chapter4.html)
- [NSIS preprocessor](https://nsis.sourceforge.io/Docs/Chapter5.html)
