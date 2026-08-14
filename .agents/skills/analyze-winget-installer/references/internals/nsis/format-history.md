# NSIS format history and editions

[Back to NSIS internals](overview.md).

NSIS output does not carry one universal compiler-version field. A reader should identify a serialized ABI from structures that survive compilation: string controls, variable indexes, command numbering, command width, first-header shape, compression framing, and fork-specific flags. Several compiler releases can produce the same ABI.

## Version domains

Keep these identities separate:

| Identity | What it describes |
| --- | --- |
| Compiler release | Marketing or source release used to run MakeNSIS. Often absent from output. |
| Edition | Official NSIS, Jim Park Unicode NSIS, NSISBI, or another maintained fork. |
| ABI profile | Serialized command, string, header, and payload rules proved by the file. |
| Stub target | x86 ANSI, x86 Unicode, AMD64 Unicode, or ARM64 Unicode runtime. |
| Generator | electron-builder, Tauri, CPack, PortableApps.com, or another source producer. |

A generator is not an NSIS edition. It can move to another template, compiler, fork, target, or compression setting without changing its own name.

## Official NSIS 1 and early NSIS 2

Historical ANSI installers use the original one-byte string-control family and 28-byte command records. The variable table changed within NSIS 2:

| ABI range | Relevant predefined variables |
| --- | --- |
| NSIS 1.x through 2.03 | `$HWNDPARENT=27`, `$CLICK=28`, custom variables from 29 |
| NSIS 2.04 through 2.25 | adds saved output directory at 29; custom variables from 30 |
| NSIS 2.26 through 2.51 | `$EXEPATH=27`, `$EXEFILE=28`, `$HWNDPARENT=29`, `$CLICK=30`, saved output directory at 31; custom variables from 32 |

These shifts affect every encoded variable reference. Treating an early stream as current can turn a window handle or click string into a path variable while the command records still appear structurally valid.

## Official NSIS 3

NSIS 3 introduced a new string-control encoding and supports ANSI and Unicode targets. Current official source supplies x86 ANSI, x86 Unicode, AMD64 Unicode, and ARM64 Unicode stubs. The executable target affects pointer size and PE machine; the serialized command record remains the standard 28-byte form.

The NSIS 3 control codes are:

| Code | Meaning |
| --- | --- |
| `0x0001` | Language-string reference |
| `0x0002` | Shell-folder reference |
| `0x0003` | Variable reference |
| `0x0004` | Escaped literal/control skip |

ANSI mode stores byte strings. Unicode mode stores UTF-16LE code units. The same logical controls are interpreted in the selected character width.

## Jim Park Unicode NSIS

Jim Park's Unicode fork predates official Unicode NSIS. Its wide strings use a separate control range:

| Code | Meaning |
| --- | --- |
| `0xE000` | Escaped literal/control skip |
| `0xE001` | Variable reference |
| `0xE002` | Shell-folder reference |
| `0xE003` | Language-string reference |

Historical readers distinguish three command-numbering generations:

| Profile | Release range | Structural distinction |
| --- | --- | --- |
| Park1 | through 2.46.1 | Initial Unicode fork opcode layout. |
| Park2 | 2.46.2 | Transitional opcode insertions shift later command IDs. |
| Park3 | 2.46.3 and later | Final fork layout used before official Unicode adoption. |

Park output uses standard first headers and 28-byte command records. Edition detection therefore depends on string controls and command-layout consistency, not a unique archive signature. Historical 7-Zip code also recognizes a possible ANSI Park route but notes that it was not fully checked; that route must be grounded with real output before a parser publishes it as supported.

## NSISBI

NSISBI extends NSIS for large archives and multithreaded compression. Important serialized changes include:

- a 36-byte first header with 64-bit data-block information and fork flags;
- 36-byte command records with two extra 32-bit operands;
- widened payload offsets and shifted timestamp/checksum operands;
- optional external payload data;
- independently compressed multithread-wrapper records;
- per-file CRC fields.

NSISBI through 3.03 predates the fork marker in the first-header flags. It still uses a 36-byte header: the two trailing words are zero for all-in-one output, or store a 63-bit external-data length with the high bit marking `.nsisbin` output. Its commands already occupy 36 bytes and use wide payload offsets, but compressed records retain a 32-bit packed-size word and its opcode enumeration does not yet contain the two later external-file commands. These independent boundaries must be routed separately. Controlled output from the official 3.03.1 SDK covers both the all-in-one and paired `.nsisbin` forms.

The MTW transport can frame zlib, BZip2, LZMA, or LZ4 data according to the builder configuration. Dumplings implements all four bounded record decoders. Controlled output from the official NSISBI 3.12.3 SDK covers every choice and a four-segment external build. In this release the zlib choice serializes raw DEFLATE records. LZ4 records contain a nested `uint16`-framed raw-block stream whose dictionary carries across its inner blocks. Those routes are enabled only after the extended first header and command record establish NSISBI; generic Deflate or LZ4-like bytes are not edition evidence.

Checksum semantics also changed. Controlled 3.03 output checks the extracted file bytes. Compact 3.12 checks the serialized record body followed by its original packed-size field, so the reader must select the checksum route from the established ABI rather than from the codec.

## Log-enabled opcode layouts

`NSIS_CONFIG_LOG` inserts logging support into the compiled runtime and command enumeration. Commands at and after the insertion point shift. A parser must normalize the serialized opcode through a log-enabled route before interpreting its operands.

Arity alone can leave both command tables valid. `EW_LOG` provides stronger evidence: operand zero selects `LogText` or `LogSet`, its remaining operands use their source-defined string/state shape, and later fields are zero. Dumplings uses that evidence to break ties and validates it against controlled output from the official NSIS 2.46 log compiler.

This is another reason the version resource or a guessed compiler release is insufficient: two stubs from the same release can serialize different command numbers.

## Feature-stripped and custom stubs

The official build system conditionally compiles command families and runtime features. Source comments permit opcode reordering to reduce executable size. Vendors can also patch resources, startup code, or archive handling.

Safe support requires an explicit route or a validated normalization profile. Choosing the closest stock release can produce plausible but incorrect registry or execution commands. A profile candidate should be accepted only when command IDs, arity, operand domains, block bounds, and control-flow targets validate as a whole.

## Current structural profiles

The Dumplings catalog groups releases that share a serialized ABI:

| Profile | Edition | Character mode | Command record | Version range represented |
| --- | --- | --- | --- | --- |
| `official-legacy-200-ansi` | Official | ANSI | standard 28-byte | 1.x-2.03 |
| `official-legacy-225-ansi` | Official | ANSI | standard 28-byte | 2.04-2.25 |
| `official-nsis2-ansi` | Official | ANSI | standard 28-byte | 2.26-2.51 |
| `park-2461-unicode` | Jim Park | Unicode | standard 28-byte | through 2.46.1 |
| `park-2462-unicode` | Jim Park | Unicode | standard 28-byte | 2.46.2 |
| `park-2463-unicode` | Jim Park | Unicode | standard 28-byte | 2.46.3 and later |
| `official-nsis3-ansi` | Official | ANSI | standard 28-byte | 3.x |
| `official-nsis3-unicode` | Official | Unicode | standard 28-byte | 3.x |
| `nsisbi-nsis3-ansi` | NSISBI | ANSI | extended 36-byte | NSISBI 3.x |
| `nsisbi-nsis3-unicode` | NSISBI | Unicode | extended 36-byte | NSISBI 3.x |

This table describes parser routes, not proof that every codec, external-media mode, or opcode effect within each row is complete. See [coverage](coverage.md) for those independent dimensions.

## Future and unknown formats

Unknown output should not be assigned to the newest profile solely because its strings are Unicode or its stub is 64-bit. A compatible fallback needs matching edition, character mode, first-header family, command width, and a complete validation pass. Otherwise the reader should report the structural evidence and stop before projecting metadata.

Exact compiler release recovery remains impossible when the compiler did not serialize distinguishing evidence. The correct result in that case is an ABI range such as `2.26-2.51`, not a fabricated patch release.

## Source references

- [Official NSIS source](https://github.com/NSIS-Dev/nsis)
- [NSIS serialized format definitions](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.h)
- [NSIS target configuration](https://github.com/NSIS-Dev/nsis/blob/master/Source/build.h)
- [7-Zip NSIS format history](https://github.com/ip7z/7zip/tree/main/CPP/7zip/Archive/Nsis)
- [Jim Park Unicode NSIS](https://sourceforge.net/projects/nsisu/)
- [NSISBI](https://sourceforge.net/projects/nsisbi/)
