# InstallBuilder internals

This reference set describes the compiled Windows installer structures and runtime behavior consumed by Dumplings. Use the [InstallBuilder workflow](../../families/installbuilder/workflow.md) for package analysis and WinGet manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Mental model

An InstallBuilder Windows installer is a native TclKit-derived PE launcher with an embedded Metakit virtual filesystem. The Metakit database owns the compiled `project.xml` and runtime support records. Older installers also keep application payload bytes in Metakit. Later installers use a separate CookFS2 store made of independently compressed pages, a file index, page integrity records, metadata, and a terminal `CFS0002` footer.

```text
distributed installer
+-- native Windows PE launcher
|   +-- requested-execution-level manifest
|   +-- Tcl/Tk and installer runtime
|   `-- optional UPX packing or Authenticode data
+-- one or more Metakit VFS databases
|   +-- project.xml
|   +-- origindist and manifest.txt control records
|   `-- runtime files or legacy package payloads
`-- optional CookFS2 package store
    +-- compressed pages
    +-- page integrity records and size table
    +-- compressed file index and metadata
    `-- CFS0002 footer

compiled project
+-- package identity and installation parameters
+-- components, folders, files, and platform selection
+-- built-in uninstaller and Windows ARP policy
+-- action lists, conditions, registry operations, and associations
+-- shortcuts, services, tasks, environment, ACL, and execution actions
`-- UI policy, command-line modes, requirements, and custom logic
```

The parser keeps three layers separate. Container structures prove which bytes belong to the installer and permit bounded extraction. `project.xml` describes intended behavior. The runtime supplies target-machine state, user choices, command-line values, downloaded resources, Tcl results, and external-process effects. Static analysis may resolve the first two layers but must not invent the third.

## Evidence vocabulary

| Evidence | Establishes | Does not establish |
| --- | --- | --- |
| Structural invariant | Family detection, range ownership, container dispatch, payload framing, and extraction | Runtime effects absent from the serialized project |
| Compiled project field | Intended identity, defaults, actions, parameters, and conditions | The final value of a runtime-mutated variable |
| Published builder documentation | Action semantics, variable names, switches, phase ordering, and feature boundaries | That every project enables the documented feature |
| Controlled builder comparison | Meaning of a changed option or generated record | Compatibility with an untested structural generation |
| Runtime inspection | Command-line and control-flow behavior of the inspected runtime | Installed state for another project using the same runtime |
| VM installed-state comparison | Actual files, ARP values, registry view, scope, and exit behavior for one fixture | A generation-wide rule without corroborating static evidence |

Physical structure selects the parser route. Branding, project schema, PE version resources, and changelog dates are secondary evidence and cannot override a validated container layout.

## Reading path

1. [Architecture](architecture.md) explains the builder, launcher, project, VFS layers, identity domains, and trust boundaries.
2. [Format history](format-history.md) records verified generations, product branding, feature boundaries, and unavailable historical media.
3. [Binary format](binary-format.md) defines Metakit boundaries, descriptors, CookFS pages, indexes, hashes, metadata, and compression records.
4. [Metadata model](metadata-model.md) covers project XML, defaults, variables, parameters, components, conditions, actions, associations, and requirements.
5. [Setup runtime](setup-runtime.md) describes action phases, command-line modes, scope, elevation, architecture, nested execution, and dynamic behavior.
6. [Uninstaller and ARP](uninstaller-and-arp.md) describes the built-in writer, custom registry operations, ProductCode selection, visibility, hives, views, and VM evidence.
7. [Parser implementation](parser-implementation.md) records detection, parsing, extraction, diagnostics, bounds, performance, and extension rules.
8. [Coverage](coverage.md) lists durable fixtures, validated capabilities, negative controls, and remaining gaps.

## Current structural routes

| Route | Verified media | Project ownership | Installed payload |
| --- | --- | --- | --- |
| `LegacyMetakit` | InstallBuilder 3.6.0, 3.7.0, and recovered 4.5.3 media | `project.xml` is a Metakit-owned zlib record | Metakit `dirs[name:S,parent:I,files[name:S,size:I,date:I,contents:B]]` rows below `origindist` |
| `CookFS2` | JXplorer 3.3.1.2 and InstallBuilder 7.2.5, 8.2.0, 9.5.5, 16.1.0, 23.1.0, and 26.8.0 research media | `project.xml` remains in the project-owning Metakit VFS | CookFS2 logical files backed by stored, Deflate, BZip2, or source-backed LZMA pages |
| `ProjectRecord` | Synthetic and incomplete research evidence only | Bounded RFC 1950 project candidate without a readable Metakit catalog | No authoritative payload route |

An executable may contain more than one valid Metakit database. InstallBuilder 8.2.0 builder media has two. The parser selects a database by ownership of the required `project.xml` or `origindist` entry, not by its physical position.

The `ProjectRecord` label preserves metadata recovered from a structurally valid project stream when the surrounding VFS cannot be decoded. It is not equivalent to a complete installer parse and must not be used to claim payload extraction.

## Source references

- [InstallBuilder downloads](https://installbuilder.com/download-step-2)
- [InstallBuilder changelog](https://installbuilder.com/changelog)
- [InstallBuilder user guide](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/)
- [Metakit format overview](https://www.equi4.com/metakit/format.html)
- [Metakit source repository](https://github.com/jcw/metakit)
- [MIT CookFS extraction research](https://github.com/vpetrigo/bitrock-unpacker)
- [Legacy InstallBuilder loader research](https://gist.github.com/mickael9/0b902da7c13207d1b86e)
- [Password-protected InstallBuilder extraction research](https://gist.github.com/NyaMisty/3d3b9a39fca463ca9e16628e96877b5c)
