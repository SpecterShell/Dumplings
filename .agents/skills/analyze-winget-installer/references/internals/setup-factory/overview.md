# Setup Factory internals

This reference describes the Indigo Rose Setup Factory structures consumed by Dumplings. Use the [Setup Factory workflow](../../families/setup-factory/workflow.md) for package analysis and WinGet manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Mental model

Setup Factory 3.1 and Setup Factory 4-10 are two distribution architectures. Version 3.1 uses a 16-bit launcher, a Crusher ARQ bootstrap archive, and separate compressed payload files. Versions 4-10 use a native PE launcher followed by a generation-specific overlay whose `irsetup.dat` member contains the compiled project model.

```text
Setup Factory 3.1 directory
+-- SETUP.EXE: 16-bit MZ/NE launcher
+-- IRDATA.IRD: Crusher ARQ bootstrap catalog
|   +-- IRDATA.DAT: project and installed-file records
|   +-- IRSETUP.EXE: setup runtime
|   +-- IRUNIN31.EXE: uninstaller runtime
|   `-- optional bootstrap records
`-- companion payload streams named by IRDATA.DAT

Setup Factory 4-10 executable
+-- native PE launcher and resources
`-- overlay
    +-- structural header
    +-- setup runtime
    +-- outer bootstrap catalog
    |   `-- irsetup.dat
    +-- optional prerequisites
    `-- installed payload streams
```

A parser must keep the physical container, compiled project, and runtime state separate. Container records identify bytes and bounds. Project records describe intended installation behavior. Runtime state supplies environment values, selected components, user choices, external code results, and conditional effects. Static analysis reports unresolved runtime state instead of substituting values from the analysis host.

## Evidence vocabulary

| Evidence | Establishes | Does not establish |
| --- | --- | --- |
| Structural invariant | Format route, record bounds, payload identity, and extraction | Runtime effects absent from the compiled records |
| Controlled builder comparison | Meaning of a changed project option or field | Compatibility with an untested generation |
| Builder help | Intended switches, variables, and policy | Exact byte placement in every release |
| Runtime inspection | Control flow and decoding behavior for that runtime | Installed state for an arbitrary project |
| VM installed-state comparison | Files, ARP, registry view, scope, and exit behavior for that fixture | A generation-wide rule without corroborating media |

Structural route selection is authoritative. Version resources and embedded runtime identity provide release evidence, but they cannot select a different record reader after the physical format has been validated.

## Reading path

1. [Architecture](architecture.md) explains builders, runtime layers, identity domains, and trust boundaries.
2. [Format history](format-history.md) records the verified generations and route changes.
3. [Binary format](binary-format.md) defines SF3.1 companion media and SF4-10 overlay records.
4. [Metadata model](metadata-model.md) covers project objects, installed-file records, variables, actions, and conditions.
5. [Setup runtime](setup-runtime.md) describes phases, switches, silent policy, prerequisites, and external effects.
6. [Uninstaller and ARP](uninstaller-and-arp.md) describes uninstall identity, visibility, hives, views, and registry-derived associations.
7. [Parser implementation](parser-implementation.md) records detection, extraction, diagnostics, limits, and performance rules.
8. [Coverage](coverage.md) lists fixtures, validated behavior, and unresolved gaps.

## Current structural routes

| Route | Verified releases | Physical form | Metadata route | Installed payload route |
| --- | --- | --- | --- | --- |
| `MultiFile31` | 3.1.0 | MZ/NE launcher plus `IRDATA.IRD` and companion files | `irdat-v3.1` | independent Crusher LH5 extended streams |
| `Classic4` | 4.x and one observed early 5.x runtime | seven-byte overlay signature with count in byte 7 | `irdat-v4` | PKWARE records |
| `Legacy5` | 5.x | eight-byte signature, 32-bit count, 16-byte names | `irdat-v5` | PKWARE records |
| `Legacy6` | 6.x | eight-byte signature, 32-bit count, 260-byte names | `irdat-v6` | PKWARE records |
| `Modern7` | 7.x | signature, optional header byte, transformed runtime, 260-byte names | `irdat-v7` | PKWARE records |
| `Modern8Plus` | 8.x-10.x | doubled signature, transformed runtime, optional Lua runtime, 264-byte names | `irdat-v8-plus` | LZMA, LZMA2, or PKWARE records |

`SetupFactoryFormatCatalog.psd1` stores these physical routes. Add a route only when bounded fixture evidence proves a different layout.

## Source references

- [Indigo Rose Setup Factory](https://www.indigorose.com/products/setup-factory/)
- [Setup Factory command-line options](https://www.indigorose.com/docs/suf/program_reference_command_line_options.htm)
- [Setup Factory release notes](https://www.indigorose.com/customers/release_notes/suf-release-notes.html)
- [Internet Archive captures of the official Setup Factory trial](https://web.archive.org/web/*/http://www.indigorose.com/files/setup-factory-trial.exe)
- [Lhasa LH5 decoder](https://github.com/fragglet/lhasa)
- [sfextract](https://github.com/CybercentreCanada/sfextract)
- [SFUnpacker](https://github.com/Puyodead1/SFUnpacker)
- [defactory](https://codeberg.org/CYBERDEV/defactory)
- [zlib blast](https://github.com/madler/zlib/tree/develop/contrib/blast)
