# TigerSetup Internals

## Coverage And Provenance

TigerSetup embeds compiled project metadata. The engine plans from this tree, not the original TOML. This reference uses the MIT-licensed [official source history](https://github.com/rkozlowski/TigerSetup/commits/main/) and published 0.12.0, 0.13.0 and 0.14.0 installers. The parser also supports the checked-in pre-release formats from 0.5.2 onward. Builder, package, file-format and schema versions are independent evidence. Select a physical profile from its footer, not from the packaged application's version or an engine-version string.

| Source generation | Physical profile | Footer bytes | Metadata schema | Metadata encoding | Payload |
| --- | --- | --- | --- | --- | --- |
| 0.5.2-0.7.1 | EngineZip1 | 128 | 1 | Raw Protobuf | ZIP: Store/Deflate |
| 0.8.0 | SplitSolid2 | 256 | 1 | Raw Protobuf | Solid Zstandard |
| 0.9.0 onward | CompressedMetadata3 | 320 | 2 | Zstandard(Protobuf) | Solid Zstandard |

Upstream says formats 1/2 and schema 1 were not published as releases. Their coverage is grounded in source commits and non-executable synthetic fixtures; no historical production artifact or VM validation is claimed. Schema-1 fields are additive across 0.5.2-0.8.0: 0.6.0 adds choices, predicates, shell/environment effects and embedded dependencies, 0.7.0 adds actions, and 0.7.1 adds explicit registry roots. Schema 2 makes the file-batch partition mandatory. Absent later fields stay empty. The reader does not synthesize batches for schema 1.

## Physical Layout

```text
Absolute offsets; adjacent blocks
0             EngineOffset     PayloadOffset    MetadataOffset     FooterOffset
| PE loader  | Zstd engine    | Zstd payload   | Zstd metadata     | footer[320] |
| resources  | executable     | solid regions | Protobuf schema 2 |             |
                                                                         optional
                                                                         certificate
```

This map shows format 3. Format 2 has the same block order with raw metadata. Format 1 instead embeds the engine in the outer PE and puts raw metadata before its ZIP:

```text
Format 1, absolute offsets
0                  MetadataOffset        PayloadOffset            FooterOffset
| PE engine       | schema-1 Protobuf   | ZIP local/central data  | footer[128] |

Format 2, absolute offsets
0          EngineOffset       PayloadOffset       MetadataOffset   FooterOffset
| loader  | Zstd engine      | solid Zstd payload | raw Protobuf   | footer[256] |
```

The engine or loader boundary must be beyond all PE headers/sections. Blocks must be adjacent in the profile's physical order and end at its footer. Engine/metadata are nonempty. An uninstaller has an empty solid payload in formats 2/3, or a valid empty ZIP in format 1. The logical end is EOF or the PE security-directory file offset. Detection checks only the three known footer lengths at that ending, validates the major/length pairing and CRC, and never scans arbitrary trailing markers. Security directory index 4 is a file offset, not an RVA. Its range and eight-byte alignment must be valid.

## Footer

Offsets below are footer-relative; block pointers are absolute. Integers are unsigned little-endian and lengths count bytes. Hashes are raw 32-byte SHA-256 values. Each footer starts with the same magic, major/minor and declared length, and ends with CRC32 plus trailing magic; different majors cannot borrow another profile's size or offsets.

```text
Format 1: 128 bytes
Offset  Size  Field
------  ----  --------------------------------------------------
0x000     16  TIGERSTP[8], major:u16=1, minor:u16, length:u32=128
0x010      8  raw metadata offset
0x018      8  raw metadata length
0x020      8  ZIP payload offset
0x028      8  ZIP payload length
0x030     32  raw metadata SHA-256
0x050     32  complete ZIP SHA-256
0x070      4  reserved
0x074      4  CRC32 over [0,116)
0x078      8  PTSREGIT

Format 2: 256 bytes
Offset  Size  Field
------  ----  --------------------------------------------------
0x000     16  TIGERSTP[8], major:u16=2, minor:u16, length:u32=256
0x010     24  engine offset, compressed length, expanded length: u64
0x028     16  raw metadata offset and length: u64
0x038     24  payload offset, compressed length, expanded length: u64
0x050     32  compressed engine SHA-256
0x070     32  expanded engine SHA-256
0x090     32  raw metadata SHA-256
0x0B0     32  compressed solid payload SHA-256
0x0D0     36  reserved
0x0F4      4  CRC32 over [0,244)
0x0F8      8  PTSREGIT

Format 3: 320 bytes
```

```text
Offset  Size  Field
------  ----  --------------------------------------------------
0x000      8  54 49 47 45 52 53 54 50 = "TIGERSTP"
0x008      2  major = 3
0x00A      2  minor = 0
0x00C      4  footer length = 320
0x010      8  engine offset
0x018      8  compressed engine length
0x020      8  expanded engine length
0x028      8  payload offset
0x030      8  compressed payload length
0x038      8  expanded payload length
0x040      8  metadata offset
0x048      8  compressed metadata length
0x050      8  expanded metadata length
0x058     32  compressed engine SHA-256
0x078     32  expanded engine executable SHA-256
0x098     32  compressed payload SHA-256
0x0B8     32  compressed metadata SHA-256
0x0D8     32  expanded metadata SHA-256
0x0F8     60  reserved; encoder writes zero
0x134      4  IEEE CRC32 of bytes [0,308)
0x138      8  50 54 53 52 45 47 49 54 = "PTSREGIT"
```

Use subtraction-based bounds before allocation/addition. Half-empty payloads, overlaps, incorrect CRC, unknown major and wrong footer length are invalid. A compatible nonzero minor retains a diagnostic. Metadata hashes are checked during analysis; payload/engine hashes are checked when extracted. Hash consistency detects corruption but does not authenticate a publisher.

## Compression And Payload Catalog

Format 1 uses ordinary ZIP local headers, central directory and EOCD records, with stored or Deflate entries and per-entry CRC32. Entry offsets are ZIP-relative, and its footer hashes the complete archive. Metadata analysis reads the bounded central directory without expanding files. Extraction verifies the archive SHA-256 and each inflated entry's CRC/size. Declared files and embedded programs must name exact entries of the expected length. ZIP has no solid-stream index or authoritative per-file SHA-256 in metadata; absent hashes remain null rather than being invented.

Formats 2/3 use Zstandard streams with magic `28 B5 2F FD` for engine and payload. Only format 3 also compresses metadata. Release compression uses level 19, long-distance matching and window log 27; fast builds use level 3. Decoding caps the window at 128 MiB. The footer bounds the compressed stream and exact expanded size. There is no encryption layer.

```text
Expanded payload
+------------------+ offset 0
| region 0         | metadata.payload[0].length
+------------------+ previous offset + length
| region 1         | application / prerequisite / action bytes
+------------------+
| ...              |
+------------------+ footer payload expanded length

PayloadEntry Protobuf fields
1 entry:string | 2 offset:uint64 | 3 length:uint64
4 crc32:fixed32 LE | 5 sha256:lowercase hex string
```

Stream order is authoritative. Regions must be contiguous, unique by name and cover the expanded stream exactly. Files name an entry and the same size. Embedded dependencies and actions additionally declare hashes. `.tigersetup/dependencies/` and `.tigersetup/actions/` separate programs run by the installer from installed files. Extraction that selects payload files verifies the complete compressed block and every region before publication; CRC32 and SHA-256 share one sequential region read. Metadata-only and unmatched selectors do not decode unrelated payload/engine blocks and do not claim those blocks were verified. Large decoded streams spill to disk rather than becoming byte-object arrays.

File batches partition files into consecutive runs with exact byte totals. They drive journaling/recovery. The builder normally closes a batch at 256 files or 32 MiB and puts an oversized file in its own batch. Readers validate the declared partition instead of reproducing builder grouping rules.

## Metadata Wire Format

A tag varint contains `(field number << 3) | wire type`. Wire 0 is a varint, wire 1 eight bytes, wire 2 a length-varint followed by bytes, and wire 5 four-byte fixed32. Strings are strict UTF-8; declared message types determine nested decoding. Numeric repeated values may be packed. Binary messages can happen to be valid UTF-8, so text-first guessing is unsafe. Unknown fields retain paths in diagnostic evidence. Unknown semantics are not inferred.

Singular scalar repetitions use the last value, including an explicitly encoded default. Singular message repetitions merge recursively without resetting absent fields. Repeated values append; encoded label maps resolve duplicate keys with the last value. The reader retains `PresentFields` on each message, distinguishing an absent optional launch working directory from an explicitly empty one. Declared uint32/int32 values use the low 32 bits of the decoded varint, as the engine's generated Protobuf reader does; a negative int32 may occupy ten wire bytes. Uint64/int64 values retain all 64 bits. Malformed or overflowing wire varints are rejected before these conversions.

```text
Metadata fields
 1 schema               10 shortcuts             19 app_paths
 2 package              11 path_entries          20 context_menu_verbs
 3 install              12 registry_values       21 firewall_rules
 4 files                13 registration          22 actions
 5 directories          14 legacy                23 payload
 6 engine               15 dependencies          24 quiescence
 7 role                 16 environment_variables 25 file_batches
 8 uninstaller_scope    17 file_associations      26 launch
 9 options              18 url_protocols
```

Package stores identity, publisher, description, copyright, license identity/text, website/support/help URLs, icon and optional Windows file version. Install stores ordered scopes (1 user, 2 machine), roots, minimum Windows build (0 means 17763), architecture, estimated size and existing-scope policy. Engine stores builder version and original/branded engine/loader identities. Registration overrides key/name/version/icon; publisher still comes from Package.

Options are Boolean or named choices. Predicates are one option equality, with no expressions, negation or combinations. The older resource `option` field means equality to `true`; an explicit predicate with an empty option falls back to that field. Option-name lookup is case-insensitive. CLI Boolean aliases and choice values normalize to canonical text, but the engine compares compiled predicate `equals` literally and case-sensitively. For example, CLI `ON` becomes `true`, while raw compiled `equals="ON"` does not match it even though structural validation accepts that spelling. Explicit CLI/wizard choices and remembered upgrade choices can differ from defaults. Conditions stay attached to metadata even when association evidence is projected for selected defaults.

Before ARP projection, validation checks identity limits, directory declarations and parents, file/directory collisions, reserved payload paths, option kinds/labels/choices, predicates on inactive resources, shortcut destinations, ProgIDs, extensions, protected URL schemes, App Paths, context-menu identities, environment names, firewall enums/port ranges, registry keys/types/hive-scope compatibility, registration and legacy keys, dependency detectors/acquisition requirements, action phases/program kinds/operations and quiescence contracts. Completion launch must name a declared EXE and a declared working directory when one is specified. The container separately checks payload backing, lengths, hashes and batch partitions. Unknown fields remain unresolved evidence. Known invalid resources do not silently become matching metadata.

System effects include registry strings/expand strings/DWORDs, shortcuts, PATH/environment changes, file/URL handlers with capability registration, App Paths, Explorer verbs and firewall rules. Unelevated runs can skip machine firewall rules. Dependencies contain detectors and WinGet hints, fixed URL/hash or embedded installers, plus arguments and return-code interpretation. Static parsing never acquires them.

Actions describe EXE/PowerShell/CMD programs, phase/operations, arguments, working directory, timeout and failure policy. Their external effects are not rolled back. Quiescence stops/resumes applications around Restart Manager. Completion-page launch runs as the interactive user and is absent from quiet installation. Static evidence exposes these envelopes and flags opaque program effects.

## Scope And Installed State

State database/uninstaller directories are `%LOCALAPPDATA%\TigerSetup\<package.id>` and `%PROGRAMDATA%\TigerSetup\<package.id>`. Application roots are compiled templates or absolute CLI overrides. `--install-root` exists in the earliest checked-in 0.5.2 CLI. It is not a newer-format feature. Virtual command-line parsing accepts separated and attached scope/root values and two-valued `--option`, rejects missing/repeated singleton arguments, and applies a valid absolute root to fresh-install ARP and registry data. Installed-state handling requires separate evidence: a same-version run without option changes or new license acceptance returns `already_installed`, retaining its recorded root even if the caller supplies a different root. Reconciliation paths can reject root conflicts. The first scope is the fresh-install default; existing-scope policy preserves another installation by default, allows parallel installs or rejects conflicts. Two existing scopes require explicit selection. Machine installation elevates itself; user installation to a writable private root works without elevation, while an unwritable root/state directory can require relaunch.

Registry data expands only `%INSTALLROOT%` and `%VERSION%`, matching the runtime. Preserve its other text, including URL separators and literal environment-variable names. Filesystem-template normalization is a separate operation and must not rewrite arbitrary registry strings.

ARP is written last in native 64-bit HKCU/HKLM under `Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>`. Values include display metadata, location with trailing backslash, quoted uninstall path, quiet command, NoModify/NoRepair, UTC InstallDate, ceiling(size/1024) EstimatedSize, first-two-component VersionMajor/Minor, optional icon and website/help URLs. Custom registry rows can add visibility flags or independent entries. Hidden rows remain evidence but are excluded from visible identity projection.

On 2026-10-02, 0.14.0 passed install/uninstall in both scopes in the shared Windows 11 VM using `--option path off`. All 13 deterministic ARP values matched the parser after VM known-folder substitution. All four operations returned 0. Final snapshots showed zero ARP, protocol, file-extension and PATH changes from baseline. UAC prompting, optional associations, network dependencies, custom actions and existing-state conflicts were not dynamically exercised.

A separate 0.14.0 builder-generated fixture then covered custom install roots, dual-scope `allow-parallel`, visible custom ARP plus a hidden built-in machine row, file/URL associations and exact open commands, PATH/environment writes, App Paths, a Start Menu shortcut, an embedded harmless prerequisite, and a no-op action. All four ARP rows and their deterministic values matched static projection; user/machine installs and both Dumplings-reconstructed uninstallers returned 0. An unqualified install with both scopes present returned 2. A same-version conflicting-root request returned 0 without changing the original location. A genuinely limited-token user install/uninstall also returned 0. The captured ARP, associations, PATH, environment and application roots returned to baseline after explicitly removing the fixture's prerequisite marker. Logs retain successful prerequisite/action execution. The shared VM was not restarted or restored. Interactive machine UAC consent, Inno migration, network acquisition and arbitrary external-program effects remain artifact-specific checks.

## Generated Uninstaller

Reconstruction retains the source profile: format 1 copies the PE engine, raw role-2 metadata and an empty ZIP; format 2 copies loader/compressed engine and raw role-2 metadata with zero-length solid payload; format 3 uses compressed role-2 metadata. Footer lengths, pointers, hashes and CRC remain generation-specific. Schema and unknown metadata bytes are preserved while role/scope and payload index are changed.

Format-3 stored metadata uses Zstd magic, descriptor 0xE0, eight-byte content size and raw blocks of at most 128 KiB. A three-byte block header stores size in bits 3 onward and the last-block flag in bit 0. Reconstructed output is unsigned and clears a stale PE security directory/checksum. It is not claimed byte-identical to the runtime copy. Round-trip parsing is covered for every profile. Format-3 reconstructed uninstallers were executed successfully in both scopes and under a limited user token. Historical format-1/2 runtime execution remains unvalidated because only source-backed synthetic prototypes are available.

## Bounds And Implementation

Metadata is capped at 64 MiB, 200,000 wire values, 65,536 repeated values and nesting depth 32. Catalog output paths reject traversal and case-insensitive duplicates. Extraction defaults to a 16 GiB decoded-payload limit; engine decoding is capped at 512 MiB. A schema/format mismatch and unknown major are rejected. Source-history formats 1/2 are supported without claiming a published artifact. Custom programs, ambient known-folder redirection and existing-state decisions remain runtime evidence requirements.

Extraction preserves declared empty directories and zero-byte files. Selected files are staged on the destination volume, then all collision decisions are resolved before publication. A decode, checksum, staged-copy or cancelled collision decision leaves existing files intact. Publication uses atomic per-file moves. This is not an all-files transaction if the filesystem fails during publication. Existing junctions/symlinks in output ancestors are rejected and staging is removed in `finally`. A solid payload needs a decoded spill plus staged selected files; budget disk space for both.

The 128 MiB zero-filled controlled fixture measured 4.88 ms warm metadata analysis, about 1.04 MiB managed allocation per analysis, and 580 ms extraction in a clean PowerShell child process. Working set was 290 MiB after import/warm-up and peaked at 356 MiB; sampled additional disk peaked at 256 MiB for spill plus staging. The small official 0.14.0 installer measured 8.04 ms warm analysis and 206 ms extraction. These local observations have no CI timing threshold and do not predict incompressible payload throughput.

`Libraries/Installers/TigerSetupFormatCatalog.psd1` records physical order, footer fields, compression and schema/batch requirements. `TigerSetup.psm1` owns scope/ARP projection and extraction. `Assets/Source/TigerSetup/MetadataReader.cs` decodes the additive schema-1/2 fields, verifies regions and composes payload-free metadata/frames; `MetadataValidation.cs` validates resource declarations. Existing PE, Binary, FileSystem and Archive helpers supply bounds, hashes, collision handling, ZIP and Zstd. The analyzer routes the raw parser; WinGetAnalysis produces schema-valid suggestions and scope variants. Durable controlled media lives under `Builders/TigerSetup/0.14.0/Rich` and VM evidence under `Research/TigerSetup/PriorityGaps-20261002` in the sibling fixture cache.

Historical references: [initial 0.5.2 footer](https://github.com/rkozlowski/TigerSetup/blob/a83bdd8/crates/tigersetup-format/src/footer.rs), [initial CLI](https://github.com/rkozlowski/TigerSetup/blob/a83bdd8/crates/tigersetup-setup/src/main.rs), [0.8.0 split footer](https://github.com/rkozlowski/TigerSetup/blob/e264bea/crates/tigersetup-format/src/footer.rs), [0.9.0 compressed metadata](https://github.com/rkozlowski/TigerSetup/blob/ac77e6a/crates/tigersetup-format/src/footer.rs).

Sources: [footer](https://github.com/rkozlowski/TigerSetup/blob/v0.14.0/crates/tigersetup-format/src/footer.rs), [schema](https://github.com/rkozlowski/TigerSetup/blob/v0.14.0/proto/tigersetup.proto), [composition](https://github.com/rkozlowski/TigerSetup/blob/v0.14.0/crates/tigersetup-format/src/compose.rs), [identity](https://github.com/rkozlowski/TigerSetup/blob/v0.14.0/crates/tigersetup-format/src/identity.rs), [ARP](https://github.com/rkozlowski/TigerSetup/blob/v0.14.0/crates/tigersetup-engine/src/resource/registration.rs), [CLI](https://github.com/rkozlowski/TigerSetup/blob/v0.14.0/crates/tigersetup-setup/src/main.rs), [WinGet writer](https://github.com/rkozlowski/TigerSetup/blob/v0.14.0/crates/tigersetup-build/src/winget.rs).
