# InstallShield coverage and remaining gaps

[Back to InstallShield internals](overview.md).

InstallShield coverage is compositional. A setup is understood only when each physical layer has a route. Recognizing the builder release does not make an unsupported media or bytecode profile readable.

## Structural coverage

| Layer | Covered structures | Current boundary |
| --- | --- | --- |
| Classic media | InstallShield 3 reusable engine, Setup30 footer catalogs, TTCOMP/Implode members, multipart media | An engine without its external package has no payload or product metadata to recover. |
| Proprietary cabinets | InstallShield 5 major-0 descriptors without digests and major-5 descriptors with MD5; version 6-16 ANSI catalogs; version 17-32 Unicode catalogs; split volumes, links, and Deflate | Core file catalogs and payloads are covered through major 32. Optional registry and shell graphs are source-backed for majors 22, 30, and 32; other Unicode profiles publish them only after complete transactional validation. Major versions above 32 remain future profiles. |
| Bootstrap containers | External media, transformed InstallShield and ISSetupStream overlays, optional zlib payloads, PackageForTheWeb cabinets | Downloaded or generated child payloads remain outside the static file. |
| InstallScript | Old INS event/action records, OBS, aLuZ, kUtZ, bounded scrambling, function catalogs, typed instructions | Unknown actions and runtime calls remain opaque instead of receiving guessed semantics. |
| OBL and OBS | `pOdA` member catalogs; bounded member ranges; OBS headers, prototypes, external variables, member-local address fixups, basic blocks, and selected-member decoding | OBL is a build-time library and carries no catalog-level symbol-linkage map. Analyze the final linked INX for installer behavior. |
| Windows Installer | Basic MSI, InstallScript MSI, embedded ISSetup custom actions, package selection from Setup.ini | Windows Installer runtime behavior, native custom actions, and target-machine conditions still need VM evidence. |
| Advanced UI | Suite identity, package and parcel catalogs, operations, conditions, transactions, nested command lines | Custom extensions, downloaded parcels, runtime callbacks, and interactive choices remain unresolved. |
| Prerequisites | PRQ metadata, typed install-condition clauses, three-valued evaluation over caller-supplied registry/file/package facts, OS `All`/`Any` aggregation, command lines, privilege settings, ordered references | Unknown comparison codes, locale-sensitive CSD ordering, and prerequisite payload behavior remain dynamic. |

## Release evidence

Runtime resources, structured `EngineVersion`, MSI Summary Information, Advanced UI namespaces, and structured `.ism` schemas can identify a release. Schema coverage intentionally has gaps where no official project has established a value. An unmapped schema is returned as evidence rather than assigned to the nearest year.

Exact commercial editions such as Premier, Professional, Express, or Standalone Build usually do not survive in shipped media. The installation model and runtime release are useful; guessing the purchased SKU is not.

## InstallScript semantic coverage

The bounded interpreter follows source-backed assignments, arithmetic, calls, branches, handlers, references, selected registry and shell APIs, process and file operations, response-backed dialogs, and MaintenanceStart defaults. It does not invoke imported code.

The remaining semantic gaps are:

- Old INS is sequential, so an action whose source-backed framing table marks it as generation-dependent stops the affected event rather than allowing a guessed resynchronization. The archived InstallShield 5 Professional setup decodes all 4,510 actions without taking this fallback.
- Native DLL exports, COM objects, runtime properties, and target-state queries can change control flow or system effects. Those paths require inspection of the dependency or VM validation.
- Unknown modern actions and member-local OBS fixup types remain structural evidence when their runtime semantics have not been grounded.

## Other project outputs

InstallShield can author MSP patches, MST transforms, merge modules, QuickPatch projects, DIM repositories, objects, and web parcels. Their MSI/CFB or suite container can be identified and inspected by the corresponding generic parser. They do not currently receive a separate top-level InstallShield execution model unless a launcher or suite selects them.

Patch applicability, transform selection, merge-module consumption, and QuickPatch target baselines depend on an installed product or consuming build. Static parsing can report their metadata but cannot prove an installation route without that context.

## Fixture coverage

Regression fixtures currently exercise InstallShield 3 media, synthetic InstallShield 5 major-5 media, archived InstallShield 5 major-0 single-file media with bounded extraction, the InstallShield Developer 8 runtime MSI, complete 6.10 and 11.5 external media, InstallShield 2012 Spring's `2012.2` suite namespace, InstallShield 2013's year-only suite namespace, modern 2021, 2025, and 2026 output, Basic MSI, InstallScript MSI, standalone InstallScript, Advanced UI, PackageForTheWeb, prerequisites, official 11.5 and 2026 OBL/OBS libraries, and several real vendor installers. The large-media opt-in test retains the 430,184,928-byte AVer launcher and verifies bounded extraction of its 435,532,288-byte nested MSI.

The highest-value additions are controlled builder fixtures at structural transitions, not one installer for every marketing year. The remaining format-fixture gaps are an old INS stream that actually reaches an action marked with unresolved generation-dependent framing and a future cabinet major after 32. The parser does not assign semantics to either case without a source-backed record layout.

The archived InstallShield 5 Professional distribution grounds the pre-digest descriptor, single-file catalog, legacy compression, old INS, and runtime-stub transitions. The archived InstallShield Professional 6.10 media grounds uppercase external-media discovery, the family-1 ANSI catalog, numbered-volume resolution, selected payload extraction, and a complete aLuZ program while demonstrating that old optional descriptor fields must not be interpreted through the modern registry/shell layout. The InstallShield 8 item contains `ISScript.zip` rather than a complete builder and is therefore useful for runtime and custom-action comparison, not controlled project generation. The cached 2012 Spring and 2013 distributions ground the point-release and year-only Advanced UI namespace forms. The 2014 and 2015 distributions remain optional controlled-builder sources for matched outputs when a new structural difference is observed; marketing-year coverage alone does not justify adding fixtures.

Internet Archive items are community-uploaded fixture sources, not authoritative format specifications. Verify downloaded hashes, signatures, PE/MSI metadata, and generated output against source-backed structures. Cache only builder inputs and minimal generated fixtures needed by tests; exclude license keys, cracks, activation utilities, and unrelated archive contents.

## Sources

- [InstallShield documentation](https://docs.revenera.com/installshield/)
- [InstallShield 5 Professional archive](https://archive.org/details/IS5pro)
- [InstallShield Professional 2000 version 6.10 archive](https://archive.org/details/install-shield-professional-2000-v-6.10)
- [InstallShield 8 ISScript archive](https://archive.org/details/Installshield8)
- [InstallShield 2012 Spring archive](https://archive.org/details/install-shield-2012-sprpremier-comp)
- [InstallShield 2013 archive](https://archive.org/details/installshield-2013)
- [InstallShield 2014 archive](https://archive.org/details/installshield2014)
- [InstallShield 2015 archive](https://archive.org/details/is2015)
- [InstallScript Decompiler](https://github.com/jte/installscript-decompiler)
- [ISx](https://github.com/lifenjoiner/ISx)
- [Unshield](https://github.com/twogood/unshield)
- [setup30](https://github.com/ostrich/setup30)
