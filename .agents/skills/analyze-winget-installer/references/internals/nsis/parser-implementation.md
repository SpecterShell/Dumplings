# Notes for implementing an NSIS format reader

[Back to NSIS internals](overview.md).

This page maps NSIS internals to a safe static reader. It is intentionally
shorter than the format and runtime pages: the parser should reproduce only the
runtime behavior needed to identify structures, payloads, and deterministic
system effects.

## Static-analysis boundary

A static reader can prove:

- archive and logical-block structure;
- catalog-selected string, variable, command, and payload routes;
- literal and symbolically resolvable command operands;
- reachable core commands within the supported virtual state;
- direct registry, file, association, extraction, and child-process evidence;
- language, architecture, and scope alternatives represented in compiled code.

It cannot generally prove the result of a native plug-in, a target-machine
query, a download, a child process, application first run, or arbitrary native
code added to a custom stub. Those effects must stay conditional, unresolved,
or delegated.

## Route selection

Detection should proceed from outer structure to semantic profile:

```text
PE and aligned archive start
`-- first-header route
    +-- standard 28-byte first header
    `-- NSISBI 36-byte first header
        +-- legacy high-bit flag route and optional <installer>.nsisbin
        `-- compact 3.12 flags and optional setupN.bin segment stream
        `-- logical-header compression route
            `-- block-offset width
                `-- string-control family
                    `-- command width and opcode profile
                        `-- variable layout
                            `-- payload and checksum route
```

Each route is independent. A Unicode string block does not prove official NSIS
3, and an NSISBI first header does not prove that every advertised MTW codec is
available. Candidate selection should score the complete command table against
source-defined opcode and arity rules. When candidates remain tied, compare the
canonical meaning each route assigns to every raw opcode the installer actually
uses. Equivalent mappings can proceed with generation ambiguity recorded;
different mappings must stop simulation. This catches known-profile ambiguity
without pretending that an arbitrary equal-arity source reorder can be inferred.

Operand validation includes command-specific invariants where arity alone is
insufficient. For example, Park3 normally uses the log-enabled layout, and an
all-zero record cannot be `FindProc`; that rule distinguishes its `LockWindow`
records from the otherwise plausible non-log interpretation.

Packed and solid header routes must also compete structurally. A solid LZMA
property prefix can look like a packed-size word with its compression bit set.
Accept a candidate only after it expands to the declared header length and its
block descriptors consume valid ranges.

The selected profile should expose an edition and ABI range. It should not guess
an exact compiler version that the output does not encode.

## Required validation

Before metadata projection, validate:

- an appropriate PE stub close to the aligned first header;
- first-header signature, flags, header length, archive length, and file bounds;
- compressed and expanded header limits;
- common-header size and every block offset/count pair;
- standard versus extended command width;
- string termination and control operands;
- language-table ranges and language-string indexes;
- command IDs, minimum arity, jump targets, and section/function ranges;
- payload offsets, packed lengths, expanded lengths, aliases, and timestamps;
- decompression completion, checksum policy, extraction paths, and total output;
- watchdog limits for recursion, steps, stack, branches, strings, and files.

Rejecting an unsupported profile is safer than interpreting a valid command as
a different opcode. Warnings are appropriate for opaque effects after structure
has been established; structural corruption should terminate the affected read.

## One analysis context

Open and decode the installer once per top-level operation. A useful context
contains:

```text
NSIS analysis context
+-- resolved path and PE layout
+-- first-header/archive ranges
+-- decompressed logical header
+-- block descriptors and common-header layout
+-- strings and language tables
+-- raw and normalized command records
+-- catalog profile and candidate evidence
`-- payload data range and compression route
```

Metadata simulation and extraction should share this context. Repeated calls to
individual product-name, version, and publisher readers otherwise repeat the
most expensive archive and command work and can select inconsistent fallback
routes.

## Opcode normalization

Keep three command identities when diagnosing a stream:

| Identity | Purpose |
| --- | --- |
| Raw opcode | Integer stored in the command record. |
| Layout opcode | Value after record-width or fork-specific field handling. |
| Canonical opcode | Official semantic command after Park, log-enabled, or NSISBI normalization. |

The emulator should consume canonical opcodes only. Retaining the other values
allows a malformed candidate or future catalog route to be explained without
re-reading the file.

## String evaluation

String resolution is an interpreter of its own. It must process literal spans,
escaped controls, variable references, shell constants, and language references
with the profile's character width and control codes.

Use separate concrete and symbolic forms:

- concrete resolution supplies a chosen architecture, scope, language, and
  virtual state;
- symbolic resolution preserves alternatives or unresolved expressions without
  importing values from the host machine.

Both forms need recursion and cycle bounds. ANSI text requires the code-page
semantics of the compiled runtime; decoding it with the analysis process's
default encoding is not a reliable substitute for non-ASCII installers.

## Virtual runtime state

The emulator needs one mutable state for variables, stack, error and reboot
flags, shell context, registry view, output directory, virtual files, virtual
registry values, virtual INI files, sections, and collected effects. INI and
registry reads observe only writes made earlier in that state; they never query
the parser host. Shortcut creation records its path, target, arguments, icon,
show command, hotkey, comment, and working-directory behavior without creating
a real shell link.

Branch predicates should use three-valued results where evidence is incomplete:

```text
true     follow the true edge
false    follow the false edge
unknown  preserve alternatives within the branch and step bounds
```

Treating an unsupported opcode or target-machine read as a successful no-op can
make later writes appear unconditional. The safer behavior is to mark affected
state unknown, retain already proved effects, and warn about the incomplete
path.

The bounded executor forks explicit alternatives for unresolved file, execution
flag, string, and integer predicates. Each path owns its variables, stack,
registry, INI data, virtual filesystem, handles, sections, and effect logs. It
allows at most 16 paths and eight nested forks, with an aggregate step budget.
At completion, recursive dictionaries and scalar values are retained only when
all paths agree. Divergent variables and flags become unknown; path-specific
effects retain their predicate provenance. A present or absent `IfFileExists`
premise is written into that path's virtual filesystem so repeated checks do not
fork again.

Host process environment variables, registry values, files, privileges, and OS
properties must not leak into simulation. They describe the parser host, not
the target selected by the caller.

## Metadata projection

Project Apps & Features evidence from explicit uninstall registry writes. Group
writes by root, view, and key, then apply `SystemComponent` visibility and
language alternatives. Architecture and scope parameters select a supported
compiled branch; they must not merely filter the final result after simulation.

Keep these evidence classes separate:

- visible outer NSIS ARP entries;
- hidden outer entries;
- nested payload execution and possible delegated ARP ownership;
- portable-launcher behavior with no installation effects;
- literal protocol and file-extension association writes;
- INI writes and decoded shortcut records that can corroborate installed state;
- unresolved plug-in, child, or application effects.

PE version resources are useful corroboration but do not establish an uninstall
key.

## Payload extraction

Resolve payload destinations by simulating output-directory and extraction
commands. Several commands can reference one data record, so extraction needs a
canonical output plus bounded aliases.

Non-solid records may be decoded independently. Solid streams require one
ordered decompression pass. Compact NSISBI 3.12 can place an MTW stream around
the complete solid stream or inside each compressed non-solid record. Its LZ4
codec has nested `uint16` record framing and a rolling inner-block dictionary.
Every output path must pass traversal checks and collision policy before data is
written. Caller-provided streams remain caller-owned, and bounded substreams
must not expose the remainder of the installer.

An external NSISBI sidecar is part of the package. Legacy builders commonly use
`<installer>.nsisbin`; NSISBI 3.12 uses ordered `setupN.bin` segments and stores
their count and nominal split size in the extended first header. Treat these as
one bounded seekable stream without concatenating them in memory. `ExtractFile`
reads the external stream while `ExtractStubFile` reads embedded stub data.
Select the checksum route from the ABI: legacy 3.03 verifies extracted bytes,
while compact 3.12 verifies the serialized record body plus its packed-size
field. Delete a partial or mismatched output.

## Performance and failure isolation

Header discovery should scan aligned candidates without materializing the whole
installer. Decompression should stream into bounded memory or temporary storage.
Use typed collections for command, payload, registry, and warning records rather
than emitting large pipelines.

One looping callback or unsupported section should not discard independent
literal ARP evidence. Report the callback or section in `UnresolvedFields` and
retain the entry range in the warning. Do not recover from malformed structural
data through arbitrary string probing.

The virtual target starts as a fresh installation. Files not supplied through
the filesystem input follow the ordinary missing-file/error path, while their
paths are retained as unresolved predicates in parser-version evidence. This
keeps `IfErrors` deterministic without consulting the parser host. Existing-
installation analysis should rerun the same format context with explicit file
records, versions, timestamps, and contents.

Feature flags affect runtime semantics. In particular, `SF_SELECTED` controls
execution only in a stub compiled with component-page support. Detect that
feature from the page table before skipping an unselected section. `SetCurInstType`
must update ordinary section flags from their install-type masks, matching
`SetInstType` in `components.c`.

## Implementation locations

| Responsibility | Location |
| --- | --- |
| Declarative ABI profiles | `Modules/InstallerParsers/Libraries/Installers/NSISFormatCatalog.psd1` |
| Header, profile, command, compression, and extraction routes | `Modules/InstallerParsers/Libraries/Installers/NSISFormat.psm1` |
| Strings, virtual state, command simulation, and evidence projection | `Modules/InstallerParsers/Libraries/Installers/NSISSimulation.psm1` |
| GPL public facade and operation composition | `Modules/InstallerParsers/Libraries/Installers/NSIS.psm1` |
| Apache-2.0 process bridge | `Modules/PackageModule/Libraries/Installers/NSIS.psm1` |
| Focused parser regressions | `Modules/InstallerParsers/Tests/NSIS.Tests.ps1` |
| Bridge and manifest integration | `Modules/PackageModule/Tests/InstallerBridge.Tests.ps1`, `Modules/PackageModule/Tests/WinGetManifest.Tests.ps1` |

The GPL parser crosses into PackageModule through JSON-safe CLI actions. Do not
copy its interpreter into the Apache-2.0 bridge.

## Regression evidence

Use synthetic fixtures for corrupt lengths, profile ambiguity, individual
opcode semantics, string controls, and codec framing. Use real fixtures for
compiler/fork transitions and generator behavior. A real installer proves only
the route it exercises; it does not establish the entire edition.

Persistent downloads belong under the sibling `Dumplings-TestFixtures` cache.
Do not depend on `Downloads`, `Temp`, `Sandbox`, or installer-submission folders.

## Source references

- [Official NSIS source](https://github.com/NSIS-Dev/nsis)
- [NSIS serialized structures](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.h)
- [NSIS runtime interpreter](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/exec.c)
- [7-Zip NSIS reader](https://github.com/ip7z/7zip/tree/main/CPP/7zip/Archive/Nsis)
- [Jim Park Unicode NSIS](https://sourceforge.net/projects/nsisu/)
- [NSISBI](https://sourceforge.net/projects/nsisbi/)
