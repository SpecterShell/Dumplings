# NSIS coverage and remaining work

[Back to NSIS internals](overview.md).

NSIS coverage is compositional. Recognizing a first header does not prove the
command layout, decoding a command table does not prove every runtime effect,
and recovering ARP writes does not prove that every payload can be extracted.
The table records these layers separately.

## Implementation parity

| Layer or capability | Upstream behavior | Current Dumplings support | Status and remaining work |
| --- | --- | --- | --- |
| PE and archive discovery | The NSIS archive normally follows a PE stub at an aligned position, but wrappers and embedded stubs can change the outer placement. | Scans aligned candidates, validates nearby PE structure, accepts embedded PE/resource layouts, and rejects orphan signatures and invalid ranges. | **Implemented.** Add a fixture only when a new source-backed placement rule is observed. |
| Standard first header | Flags, `DEADBEEF + NullsoftInst`, logical-header length, and archive length define the bounded archive. | Parses and validates the 28-byte source layout with size limits. | **Implemented.** |
| NSISBI first header | Extends the first header to 36 bytes. Pre-3.04.1, legacy flagged, and compact 3.12 releases assign different meanings to flags and trailing words. | Separates all three NSISBI routes. The unmarked 3.03 route is selected only when stock framing at `+0x1C` is invalid and valid fork framing begins at `+0x24`; controlled all-in-one and external fixtures cover it. | **Implemented for observed NSISBI 3.03, legacy, and 3.12 ABIs.** |
| Logical header and blocks | The decompressed header contains the common header and block descriptors for pages, sections, commands, strings, languages, and control data. | Parses 32-bit and 64-bit block offsets, validates ranges and counts, and keeps blocks as byte arrays for bounded access. | **Implemented for catalogued stock layouts.** Feature-stripped custom headers need explicit profiles rather than nearest-version guesses. |
| Official editions | Official NSIS 1/2/3 differ in string controls and predefined-variable layouts; NSIS 3 can be ANSI or Unicode. | Catalogues early 1.x-2.03, 2.04-2.25, 2.26-2.51, NSIS 3 ANSI, and NSIS 3 Unicode ABIs. | **Implemented at ABI-range level.** Exact compiler release often cannot be recovered by design. |
| Jim Park Unicode edition | Park1, Park2, and Park3 use fork-specific controls and shifted opcodes. Park3 normally enables the log command, which shifts the later table again. Historical code mentions an incompletely checked ANSI possibility. | Catalogues all three Unicode command routes, scores log and non-log variants, and applies the source-defined invalid all-zero `FindProc` invariant. Official 2.33, 2.46.2, and 2.46.3 installers cover Park1, Park2, and log-enabled Park3 respectively. | **Implemented for Unicode Park output.** Do not enable Park ANSI without trustworthy source and fixture evidence. |
| NSISBI command records | NSISBI widens each command to 36 bytes and shifts payload timestamp and CRC operands. NSISBI 3.03 widens operands without inserting the two later external-file opcodes. | Parses both command-numbering routes, wide extraction offsets, expanded registry/uninstaller operands, and per-file CRC. | **Implemented for controlled 3.03 and current catalog routes.** |
| Log-enabled commands | `NSIS_CONFIG_LOG` inserts `EW_LOG` and shifts later command numbers. | Scores both layouts and uses source-defined `LogSet`/`LogText`, `FindProc`, and later-command operand invariants to resolve otherwise legal ties. Controlled official 2.46 log output and the Park3 compiler installer exercise both routes. | **Implemented with real compiler output.** |
| Arbitrary custom command layouts | Build flags can remove command families, and custom source can reorder opcodes. | Candidate scoring rejects source-opcode and arity violations. Equally scored known layouts are compared by the canonical meaning assigned to every used opcode; simulation stops when those meanings differ. | **Fail-closed for ambiguity among known profiles.** An arbitrary equal-arity source reorder can be indistinguishable from stock output and needs its own source-backed profile and fixture. |
| Stored, Deflate, zlib, BZip2, and LZMA | Stock stubs support configured header and payload compression, including raw NSIS BZip2 framing and optional x86 BCJ transforms. | Performs bounded decoding and selected extraction for solid and non-solid archives. Real regressions cover LZMA, raw BZip2, and vendor LZMA2. | **Implemented for observed stock and vendor routes.** Keep vendor LZMA2 separate from official NSIS capabilities. |
| NSISBI MTW | Payload is divided into independently compressed records; builders can use zlib, BZip2, LZMA, or LZ4. Current LZ4 records add a second `uint16`-framed stream inside each MTW record and carry a 65,535-byte dictionary across its inner blocks. | Streams all four routes with bounded output and extracts selected files across record boundaries. Controlled NSISBI 3.12.3 output covers the builder's zlib, BZip2, LZMA, and LZ4 choices; the zlib choice serializes raw DEFLATE records in this release. | **Implemented for the source-backed 3.12.3 MTW routes.** Add a fixture only when another release changes the framing or codec parameters. |
| NSISBI external data | Pre-3.04.1 and later legacy releases use `<installer>.nsisbin`; 3.12 uses `setup1.bin`, `setup2.bin`, and so on. The latter files form one logical seekable data stream. | Resolves either naming route or explicit paths, validates declared segment counts, reads split files without concatenating them, and extracts external and embedded-stub records separately. Controlled 3.03 output covers `.nsisbin`; controlled 3.12.3 output crosses four `setupN.bin` segments. | **Implemented for known 3.03, legacy, and 3.12 routes.** |
| Integrity checks | Stock archives append CRC32 unless `FH_FLAGS_NO_CRC` is set; coverage starts 512 bytes after the owning stub and ends before the checksum. NSISBI 3.03 checks extracted file bytes, while compact 3.12 checks the serialized stored or compressed body followed by the original packed-size field. | Verifies stock archive CRC before metadata projection and applies the selected NSISBI ABI checksum route during extraction. A failed output is deleted. | **Implemented for stock and controlled NSISBI 3.03 and 3.12 output.** Additional fork checksum variants require their own source route. |
| String controls | Strings combine literals, escapes, variables, shell folders, and language references. | Resolves official NSIS 2/3 and Park controls, language alternatives, known folders, symbolic variables, bounded recursion, and source-code-page ANSI literal runs. | **Implemented for catalogued controls.** Automatic ANSI code-page choice is language-derived and can be overridden; ambiguous vendor output remains explicit. |
| Variables and shell folders | Variable indexes changed in early NSIS; shell constants depend on scope, architecture, and Windows state. | Selects three variable layouts, supplies symbolic target paths, and maps stable installer-related known folders without borrowing parser-host paths. | **Implemented for source-backed stable constants.** Target-dependent or code-generated paths remain symbolic or unresolved. |
| Command interpreter | `exec.c` implements the canonical VM over variables, stack, flags, control flow, files, registry, INI files, shortcuts, processes, UI, and plug-ins. | Handles metadata-relevant control flow, execution flags, selected-section behavior, install types, virtual file handles and searches, file time/version queries, copy/rename/delete operations, INI and registry state, and decoded shortcut records. Unknown file, flag, string, and integer predicates use bounded fork-and-merge execution. Silent `MessageBox` follows a compiled `/SD` response. Presentation-only commands remain neutral. | **Partial by design.** Interactive UI, arbitrary native calls, and child code remain opaque; another opcode should be added only when it controls recoverable package evidence. |
| Target environment | Runtime reads environment variables, files, registry, OS state, account privileges, process state, and command-line values from the target machine. | Accepts target architecture, scope, environment, command line, and filesystem facts. Target paths are symbolic and never borrowed from the parser host. Unknown file predicates explore present and absent paths under strict bounds; common effects remain deterministic and alternatives retain provenance. | **Implemented for exposed scenario inputs.** Caller-supplied process, registry, and INI snapshots remain future work. |
| Native plug-ins | Plug-ins can execute arbitrary code and mutate stack, variables, registry, files, UI, or child processes. | Models bounded, source-backed System and UserInfo patterns, plus the documented `nsProcess` stack contract used by process-running guards. Other plug-in calls remain evidence. | **Intentionally partial.** Native side effects remain opaque unless a specific ABI contract is implemented. VM validation remains necessary. |
| Apps & Features projection | Scripts manually write uninstall keys and can localize, hide, or branch those writes. | Recovers literal and simulated writes, groups localized values, handles `SystemComponent`, resolves architecture/scope identities, and merges structural format warnings into `Get-NSISInfo`. | **Implemented for supported effects.** Opaque plug-ins and first-run registration still require VM evidence. |
| Protocol and extension associations | Scripts may write class and protocol keys; applications can defer registration to first run. | Projects literal registry associations and warns when an extension lacks a resolvable ProgID. | **Implemented for explicit writes.** First-run and opaque plug-in registrations are runtime-only. |
| Portable launchers | An NSIS executable can unpack and launch without installing or writing ARP. | Detects observed PortableApps/electron-builder-style portable behavior and warns instead of inventing ARP ownership. | **Partial.** Add generator-independent rules only when grounded in command effects, not product strings. |
| Nested installers | NSIS can extract and execute MSI, WiX, or custom EXE payloads that own ARP and silent behavior. | Reports extracted and executed payload evidence and warns when the outer setup lacks visible uninstall writes. | **Implemented as delegation evidence.** Child behavior requires nested parsing or VM validation. |
| Generator recognition | electron-builder, Tauri, CPack, PortableApps.com, and vendor templates emit recognizable command sequences. | Has source-backed paths for electron-builder and Tauri plus selected observed patterns. | **Partial by design.** Generator recognition must not override structural NSIS edition or command evidence. |
| Bounds and performance | Runtime trusts compiler output more than an adversarial parser can. | Uses bounded streams, header/output limits, path safety, collision policy, recursion and step watchdogs, and a large-NSISBI simulation shortcut after deterministic ARP recovery. Current MTW LZ4 truncation and four-part split-media truncation are explicit regressions. | **Implemented with ongoing hardening.** Add fuzzing for string cycles, branch explosion, malformed aliases, and further decompression boundaries. |

## Highest-priority correctness work

1. Add an explicit command-layout profile only when source and a fixture expose
   a feature-stripped or reordered custom stub that cannot use a stock route.
2. Extend branch assumptions only for metadata-relevant target-state commands
   whose source semantics and virtual inputs can be represented deterministically.
3. Add fuzz/property tests for command-table ambiguity, string cycles, malformed
   current MTW records, split-media boundaries, aliases, and branch limits.

## Format work still needed

- Investigate Park ANSI separately only if source and real output become available.
- Preserve the semantic-ambiguity rejection for feature-stripped or reordered
  stubs; add a new route only when its exact command table is source-backed.
- Determine whether legacy external-media verification records expose enough
  information to select a sidecar automatically when several candidates exist.

## Emulator work still needed

File existence, file handles, wildcard enumeration, file time/version queries,
section and install-type mutation, command-line parsing, and the stock trailing
`/D=` override are implemented. Unknown `IfFileExists`, `IfFlag`, `StrCmp`, and
`IntCmp` predicates use isolated execution states with a 16-path, eight-level,
aggregate-step bound. Values and effects common to every terminal path remain
deterministic; divergent variables and flags become unknown, while conditional
registry, INI, shortcut, payload, and extraction evidence retains provenance.
When a limit is reached, the executor records truncation and follows the
fresh-install-compatible edge rather than expanding without bound.

Interactive `MessageBox` responses, window/process discovery beyond the
documented `nsProcess` contract, and arbitrary Win32 or native plug-in calls
remain runtime-dependent. `SearchPath` uses the supplied virtual files but does
not yet reproduce Windows PATH search order, extension probing, or filesystem
case canonicalization. Unknown process, registry, INI, environment, and native
call results do not yet have caller-supplied snapshot or alternative-value
models. These gaps should be filled only when they affect package metadata that
static analysis can verify.

Every new handler needs defined behavior for unknown operands. It should state
which virtual state it reads and writes, whether failure changes the NSIS error
flag, and how unresolved results affect branch exploration.

## Fixture parity

| Profile or behavior | Synthetic coverage | Real coverage | Important addition |
| --- | --- | --- | --- |
| Official 1.x-2.03 ANSI | Variable and command-route tests | Official NSIS 2.03 installer | Official 1.x output and a controlled non-ASCII script. |
| Official 2.04-2.25 ANSI | Variable-layout tests | Official NSIS 2.04 and 2.25 installers | Controlled non-ASCII compiler output. |
| Official 2.26-2.51 ANSI | Candidate and opcode tests | Official NSIS 2.26, 2.46, and 2.51 installers | Controlled scripts that exercise the boundary-specific variable table. |
| Official NSIS 3 ANSI | Catalog and string tests | Indirect vendor coverage | Controlled ANSI output; log-enabled numbering is covered with official NSIS 2.46. |
| Official NSIS 3 Unicode | Extensive command, ARP, scope, architecture, extraction, and generator tests | AList, BongoCat, RedPanda C++, BitComet, DBeaver, WorkBuddy, TranslatorX, CCFLink, Tencent Meeting, GoTo, and others | Add only a structurally different generator or feature set. |
| Jim Park Park1 | String and opcode tests | Unicode NSIS 2.33 installer | None for Park1 unless ANSI evidence is found. |
| Jim Park Park2 | Opcode normalization | Unicode NSIS 2.46.2 installer | None unless another structural variant appears. |
| Jim Park Park3 | Opcode normalization | Unicode NSIS 2.46.3 installer | None unless another structural variant appears. |
| NSISBI current | Legacy/compact headers, 36-byte commands, all MTW decoders, payload crossing, split logical streams, CRC enforcement, ARP operands, truncated LZ4 framing, and truncated split-media rejection | Controlled NSISBI 3.12.3 output using zlib/raw DEFLATE, BZip2, LZMA, and LZ4; a separate fixture crosses four `setupN.bin` segments | Add another fixture only for a structurally different current ABI. |
| NSISBI 3.03 | Legacy first-header, unshifted wide commands, 32-bit packed records, ARP operands, and extraction | Controlled all-in-one EXE and paired EXE plus `.nsisbin` built with the official 3.03.1 SDK | None unless an earlier ABI differs. |
| NSISBI external sidecar | Legacy/current naming, segment-count validation, logical streaming, external extraction, and malformed CRC tests | Controlled 3.03.1 `.nsisbin` pair and controlled 3.12.3 four-segment `setupN.bin` output | Add another fixture only if segment naming or header semantics change. |
| Log-enabled commands | Candidate and semantic operand tests | Controlled output built with official `nsis-2.46-log.zip` | Add another fixture only if a later build moves the insertion point. |
| Raw BZip2 | Decoder and extraction limits | Exr-IO and libjpeg-turbo VC/GCC | None unless another framing variant appears. |
| Vendor LZMA2 | Header and extraction tests | NetEase UU Remote | Keep classified as vendor behavior, not stock NSIS. |
| Embedded/resource NSIS | Alignment and PE-resource tests | Package-specific fixture | Add only when a new outer placement differs structurally. |

Downloaded fixtures belong under the persistent sibling
`Dumplings-TestFixtures` cache. Historical official installers currently use the
`InstallerParsers\NSISHistorical` area. Synthetic fixtures remain preferable for
malformed paths because they make the violated invariant explicit.

## Sources

- [Official NSIS source](https://github.com/NSIS-Dev/nsis)
- [Official NSIS documentation](https://nsis.sourceforge.io/Docs/)
- [7-Zip NSIS reader](https://github.com/ip7z/7zip/tree/main/CPP/7zip/Archive/Nsis)
- [Jim Park Unicode NSIS](https://sourceforge.net/projects/nsisu/)
- [NSISBI](https://sourceforge.net/projects/nsisbi/)
- [electron-builder NSIS templates](https://github.com/electron-userland/electron-builder/tree/master/packages/app-builder-lib/templates/nsis)
- [Tauri NSIS templates](https://github.com/tauri-apps/tauri/tree/dev/crates/tauri-bundler/src/bundle/windows/nsis)
- [nsProcess plug-in contract](https://nsis.sourceforge.io/NsProcess_plugin)
