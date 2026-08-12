# Inno compiler and output assembly

The setup compiler performs more work than serializing the visible `.iss` text. It expands preprocessor input, validates directives, enumerates source files, computes versions and hashes, compiles Pascal Script, builds runtime records, compresses file chunks, prepares PE resources, and signs the final output.

## Source processing stages

```text
.iss entry script
        |
        v
preprocessor
+-- #include and conditional compilation
+-- macros and functions
`-- source-location tracking
        |
        v
section parser
+-- [Setup] directives
+-- declarative entry sections
+-- language and custom-message files
`-- [Code] source
        |
        v
semantic preparation
+-- expand compile-time constants and source wildcards
+-- validate flags and cross-field constraints
+-- add default setup types when required
+-- compute file versions, sizes, timestamps, hashes, and signatures
+-- assign file-location entries
`-- compile Pascal Script
        |
        v
output assembly
+-- serialize setup-0
+-- compress payload chunks
+-- embed setup engine and data in SetupLdr
+-- update PE manifest, icon, version, and style resources
`-- Authenticode-sign the finished setup, if configured
```

Preprocessor expressions disappear before the setup script parser runs. They do not exist in the compiled installer. Runtime constants and `Check` functions remain in serialized records.

## Section-to-record mapping

The compiler maps sections to shared runtime records:

| Script section | Compiled structure |
| --- | --- |
| `[Setup]` | `TSetupHeader` plus compiler/output settings |
| `[Languages]` | `TSetupLanguageEntry[]` |
| `[CustomMessages]` | `TSetupCustomMessageEntry[]` |
| permission strings | deduplicated `TSetupPermissionEntry[]` referenced by index |
| `[Types]` | `TSetupTypeEntry[]` |
| `[Components]` | `TSetupComponentEntry[]` |
| `[Tasks]` | `TSetupTaskEntry[]` |
| `[Dirs]` | `TSetupDirEntry[]` |
| signature keys | `TSetupISSigKeyEntry[]` |
| `[Files]` | `TSetupFileEntry[]` plus `TSetupFileLocationEntry[]` |
| `[Icons]` | `TSetupIconEntry[]` |
| `[INI]` | `TSetupIniEntry[]` |
| `[Registry]` | `TSetupRegistryEntry[]` |
| `[InstallDelete]` | `TSetupDeleteEntry[]` |
| `[UninstallDelete]` | `TSetupDeleteEntry[]` |
| `[Run]` | `TSetupRunEntry[]` |
| `[UninstallRun]` | `TSetupRunEntry[]` |
| `[Code]` | compiled Pascal Script byte string in `TSetupHeader.CompiledCodeText` |

Some source directives affect compiler-only behavior and do not become header fields. Examples include output paths, signing tools, disk slicing, reserve bytes, and the choice of SetupLdr architecture.

## Defaults and normalization

The compiler supplies defaults before serialization. Current examples include:

- `PrivilegesRequired=admin` unless another value is specified;
- `CreateUninstallRegKey=yes` and `Uninstallable=yes`;
- a default architecture expression selected from the setup engine/loader architecture when the script omits one;
- default setup types when components exist but no `[Types]` entries are present;
- selected internal and payload compression methods and levels;
- default `AppId` behavior derived from application identity when the script omits it.

Historical defaults differ. A format reader should decode persisted fields first and use version-specific compiler defaults only when the field was not stored in that structure.

## File expansion and location records

A single `[Files]` line can create many file entries. The compiler handles source wildcards, recursive directories, exclusions, external files, downloads, archive extraction, and destination-name rules.

For embedded source files, it creates or reuses a `TSetupFileLocationEntry`. The file record keeps logical installation behavior. The location record keeps physical archive coordinates and integrity data.

```text
TSetupFileEntry
+-- source and destination expressions
+-- component/task/language/check selectors
+-- callbacks and flags
`-- LocationEntry index
             |
             v
TSetupFileLocationEntry
+-- slice range
+-- chunk offset and decompressed suboffset
+-- original and chunk sizes
+-- digest, timestamp, version
`-- compression/encryption/transform flags
```

Several logical entries can reference the same source bytes. Solid compression also lets multiple locations share one compression chunk while retaining distinct decompressed suboffsets.

## Compression planning

The setup header records the selected payload compression method. The compiler chooses a compressor per chunk:

- Stored
- Zlib/Zip
- BZip2
- LZMA
- LZMA2

`SolidCompression=yes` allows consecutive eligible files to remain in one compressor context. A new chunk is forced when compression state changes, encryption state changes, a solid break is requested, or media constraints require it.

For compressed x86/x64 executables, the compiler can preprocess relative CALL instructions before compression. The location flags record that transform so Setup restores the original bytes before writing and checking the file.

Metadata uses the compiler's internal compression settings, which are separate from the package payload compression setting. Modern setup-0 metadata is LZMA-compressed even when the package payload uses another method.

## Setup-0 construction

The compiler's `WriteSetup0` operation writes:

```text
SetupID[64]
EncryptionHeaderCRC
TSetupEncryptionHeader
Compressed block 1
+-- TSetupHeader
+-- every logical entry table in fixed order
+-- wizard image streams
+-- dynamic-dark image variants
+-- Zlib/BZip2 decompressor DLL data when needed
`-- 7-Zip DLL data when needed
Compressed block 2
`-- TSetupFileLocationEntry[]
```

Before writing, the compiler fills every `Num*Entries` field and places license/info text and compiled Pascal Script into the setup header.

The file-location table is written in a separate block because Setup needs a compact physical index for extraction. With disk spanning enabled, this block is stored without metadata compression so its size remains fixed while media offsets are recalculated.

## Setup engine preparation

The compiler maintains a setup-engine image in memory, called `SetupMemoryFile` in current source. It updates that PE with package resources and setup-engine options before embedding it.

The normal loader route performs these steps:

1. Copy `SetupLdr.e32` or `SetupLdr.e64` to the output `.exe`.
2. Update loader icons, style resources, PE compatibility fields, and manifest protections.
3. Append setup-0 metadata and remember `Offset0`.
4. Append the compressed setup-engine image and remember `OffsetEXE`, its original size, and CRC.
5. Set `TotalSize` to the minimum complete loader+metadata+engine size.
6. Set `Offset1` to the payload location for single-file output, or zero for disk spanning.
7. Calculate the offset-table CRC and overwrite RCDATA resource `#11111` in the loader.
8. Update the outer PE version resource.
9. Sign the final executable when signing tools are configured.

The compiler can write payload data before the appended setup-0/engine region. This is why `Offset1` is not necessarily greater than `Offset0`.

## Single-file layout assembled by the compiler

Current normal output is conceptually:

```text
[ SetupLdr PE and any payload written into its tail ]
^                                            ^
0                                            Offset1

[ setup-0 metadata ]                         at Offset0
[ compressed Setup.e32/e64 ]                 at OffsetEXE
^                                            ^
Offset0                                      OffsetEXE
```

Physical ordering depends on whether payload compression was performed before the loader was reopened and appended. Always use offset-table fields rather than assuming a fixed overlay order.

## PE customization

The compiler can alter:

- application and installer icons;
- dark-style icon variants and VCL style resources;
- requested execution level and compatibility manifest behavior;
- DEP, ASLR, terminal-services, and OS-version fields;
- version-resource company, product, description, file, copyright, and original filename;
- Authenticode signatures.

These outer PE fields describe the prepared loader. They may repeat package identity, but the setup header remains the runtime source for `AppName`, `AppVersion`, `AppPublisher`, `AppId`, and uninstall directives.

## Encryption construction

Current Inno supports `None`, `Files`, and `Full` encryption modes. The compiler creates:

- a KDF salt and iteration count;
- an encryption key derived from the setup password;
- a base nonce with per-stream context separation;
- a password-test value;
- a CRC-protected encryption header.

Files-only mode leaves setup metadata readable and encrypts payload chunks. Full mode also encrypts the two compressed setup-0 blocks. The header itself remains readable so Setup can derive and test the key.

## Disk spanning and external files

With disk spanning, the compiler writes disk slice headers and payload data to `Setup-*.bin`. It may recalculate offsets after the final outer executable size is known, then rewrite setup-0 while requiring its size to remain unchanged.

An entry marked external is not copied into setup media. Setup resolves it relative to the source at runtime. Download entries similarly carry URL, credential, hash/signature, and extraction metadata rather than an ordinary embedded location.

## Source references

- [Compiler.SetupCompiler.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Compiler.SetupCompiler.pas)
- [Compiler.CompressionHandler.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Compiler.CompressionHandler.pas)
- [Shared.SetupEntFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.SetupEntFunc.pas)
- [Shared.SetupSectionDirectives.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.SetupSectionDirectives.pas)
