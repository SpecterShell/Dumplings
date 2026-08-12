# InstallShield versions and format generations

[Back to InstallShield internals](overview.md).

InstallShield media contains several unrelated version domains. They often have similar-looking integers, which makes version-based format detection unreliable. Identify the structure that owns a value before interpreting it.

## Product lineage

InstallShield began as a proprietary script-driven installer and later added Windows Installer authoring, suites, prerequisites, virtualization, and other deployment systems. Runtime version resources can carry company names from InstallShield Corporation, Macrovision, Acresso, Flexera, or Revenera eras.

The product naming also changed:

```text
InstallShield 3 / 5 / Professional 6
  -> InstallShield Developer 7 / 8
  -> InstallShield DevStudio 9
  -> InstallShield X / 10.5 / 11 / 11.5 / 12
  -> year-named releases (2007, 2008, ...)
  -> annual and R-numbered modern releases
```

Product lineage helps date an artifact but does not define its byte layout. New builders retain compatibility runtimes and can emit several release forms.

Commercial SKUs such as Express, Professional, Premier, or Standalone Build are authoring-tool editions. They control which project types and build features are available, but their SKU name normally does not survive in distributed media. Project type, runtime release, and structural format can often be identified; the exact commercial SKU usually cannot.

## Version domains

| Domain | Stored in | What it identifies |
| --- | --- | --- |
| Application version | MSI ProductVersion, suite ARP XML, InstallScript variables, or publisher metadata | The installed product. |
| Builder product version | InstallShield release metadata and trusted runtime resources | Commercial authoring-system release. |
| `.ism` schema version | `InstallShield.SchemaVersion` in an authored project | Project database schema. |
| Runtime engine version | Trusted `Setup.exe`, `Setup.dll`, ISRT, or structured `Setup.ini EngineVersion` | Launcher/runtime binary generation. |
| Cabinet raw version | uint32 after `ISc(` in `data*.hdr` | Proprietary media encoding family and catalog generation. |
| Cabinet normalized major | Derived from the raw cabinet value | Descriptor/string profile used by the media reader. |
| InstallScript header kind | Magic and catalog framing in INS/INX/OBL | Compiled bytecode family. |
| MSI Summary Creating Application | MSI Summary Information | Builder identity recorded when the MSI database was produced. |
| Advanced UI namespace release | `installshield/<year>[.<revision>]/bootstrap` | Suite catalog generation; the optional revision is part of the structured namespace. |
| Package/MSI code version | MSI package code, transforms, patch metadata | One built package revision, not InstallShield itself. |

These values can disagree without corruption. A builder can use an older setup stub, an upgraded `.ism`, a legacy-compatible cabinet layout, and a current application version in the same release.

## Early InstallShield 3 media

InstallShield 3 predates `ISc(` cabinet catalogs. A reusable `setup32.exe` engine loads external Setup30 package media. Package members are indexed by a footer catalog and compressed with TTCOMP/PKWARE Implode framing. `setup.ins` contains the compiled setup program.

Some distributions embed Setup30 members in PE resources, while others ship `Setup.pkg`, `_setup.lib`, `data.z`, or numbered media separately. The engine's 3.x PE version identifies the runtime but says nothing about a missing external package.

## InstallShield 5 media

InstallShield 5 introduced the proprietary header/cabinet model handled by two legacy descriptor profiles:

- Early single-file `data1.cab` catalogs with an `ISc(` common header, family-1 major `0`, 0x2A-byte file descriptors, and no descriptor digest.
- Later `data1.hdr` catalogs with 0x3A-byte file descriptors and a trailing 16-byte MD5.
- 40-byte volume headers.
- Raw-Deflate payload streams separated by legacy end markers.

The later registry, setup-type, component, and shell pointer graphs are not present in this profile.

## InstallShield 6 and later cabinets

Later media uses 0x57-byte file descriptors and 64-byte volume headers. ANSI catalog strings are used by earlier members of this family; normalized major 17 and later use Unicode strings in the supported layouts.

The modern descriptor can include:

- Split and linked file records.
- File-group and component hash tables.
- Locale-specific setup types.
- Registry-set graphs.
- Shell-folder and shortcut records.

The file descriptor family remains broadly recognizable across many builder releases, while optional metadata tables and version encoding evolve. Dumplings projects the optional registry and shell pointer graphs directly for source-backed cabinet majors 30 and 32 and transactionally for validated Unicode major-17-through-29 media, including a real major-22 fixture. ANSI majors 6 through 16 retain complete bounded file-catalog and payload support without assigning modern meanings to generation-specific optional offsets.

## Cabinet raw-version encoding

The `ISc(` common header begins:

```text
Offset  Size  Field
------  ----  -------------------------------------
0x00       4  49 53 63 28  "ISc("
0x04       4  RawVersion, uint32 little-endian
0x08       4  Reserved/observed
0x0C       4  CabinetDescriptorOffset
0x10       4  CabinetDescriptorSize
```

The high byte of `RawVersion` selects an encoding family:

```text
family = RawVersion >> 24
```

Family 1 describes a legacy cabinet-format generation. The archived InstallShield 5 Professional media uses `0x01000004`, whose normalized major is `0` and whose descriptor omits MD5. Official InstallShield 11.5 media uses `0x01009500`, representing media format 9.5; it does not mean the builder is InstallShield 9.5.

Modern families 2 and 4 use a builder-aligned value divided by 100 in validated recent output. Official examples include `0x04000C1C` for InstallShield 2025 and `0x04000C80` for 2026. This relationship should not be projected backward onto family-1 media.

## InstallScript generations

Compiled InstallScript has its own format history:

| Family | Identifying header | General structure |
| --- | --- | --- |
| Old INS | `B8 C9 0C 00` and related legacy framing | Length-prefixed catalogs followed by event/action records. Known actions can be normalized to the later analysis model; generation-dependent actions remain opaque. |
| OBS | `48 4F F3 C9` | Build-time object module with a fixed header, prototypes, external variables, member-local linker fixups, and basic blocks. |
| aLuZ | ASCII `aLuZ` | Packed header and modern tagged instruction records. |
| kUtZ | ASCII `kUtZ` | Related compiled-program family with its own header/profile. |
| OBL | ASCII `pOdA` wrapper | Build-time object library containing named script members at offset/length pairs; the catalog is not a runtime loader. |

Some INX files are scrambled. Decoding depends on the absolute byte position, then the decoded copyright/header and catalog must validate. The outer launcher or cabinet version does not select the bytecode decoder.

Compiler evolution also changes opcode sets, operand framing, debug information, runtime library calls, and generated framework code. Two builders can emit the same broad header kind with different extension opcodes.

## Project schema mapping

Known `.ism` schema values include:

| Schema | Builder release |
| ---: | --- |
| 755 | DevStudio 9 |
| 761 | InstallShield 11 |
| 763 | InstallShield 11.5 |
| 765 | InstallShield 12 |
| 766-767 | InstallShield 2008 variants |
| 768 | InstallShield 2009 |
| 769-770 | InstallShield 2010 aliases |
| 771 | InstallShield 2011 |
| 772 | InstallShield 2012 |
| 773 | InstallShield 2012 Spring |
| 774-780 | InstallShield 2013 through 2019 |
| 783-784 | InstallShield 2020 revisions |
| 787 | InstallShield 2022 R2 |
| 789 | InstallShield 2023 R2 |
| 791 | InstallShield 2025 R1 |
| 792 | InstallShield 2026 R1 |

The gaps are intentional. Some point releases and hotfixes did not change the schema, and not every schema has been grounded in an official project. Values 769/770 and 783/784 must retain their known alias ambiguity rather than being forced to one invented release.

Schema mappings apply only when the authored project database is available. They should not be inferred from raw strings in a shipped installer.

## Runtime version resources

Trusted InstallShield runtime PE files can carry product and file versions. A runtime is considered trustworthy when its own product name, file description, or company identity names InstallShield/InstallScript and the historical vendor, not merely because an application setup contains an InstallShield copyright string.

Runtime versions can include build and service-pack information. A compatibility stub can be older than the project that selected it. Canonical nested files such as `Setup.exe` or `Setup.dll` can therefore provide useful runtime evidence while remaining independent from the outer application executable.

## Setup.ini engine version

Modern external media can record `[Startup] EngineVersion`. This value describes the setup runtime expected by that media. It is stronger than an application- owned PE version and weaker than the actual authored project schema.

Older configurations omit it or use other startup fields. Absence is normal and must not be filled from a nearby version string.

## MSI builder identity

InstallShield-built MSI databases often record a `Creating Application` value in Summary Information. Depending on release, the value may name InstallShield, an edition, and a product version.

Summary identity can date the MSI database, but it does not distinguish Basic MSI from InstallScript MSI. Project type comes from InstallScript-specific tables and actions. A later tool can also post-process an MSI without changing every InstallShield-authored table.

## Advanced UI namespace

Advanced UI `Setup.xml` uses a namespace such as:

```text
installshield/2026/bootstrap
```

Early Suite/Advanced UI catalogs can include a point release, such as `installshield/2012.2/bootstrap`; later catalogs commonly use only the year, such as `installshield/2013/bootstrap`. Preserve the complete release token for structural evidence and use its leading year for the release catalog. Nested parcels can be built by other tools or older InstallShield releases, so the namespace applies to the outer suite only.

## Compatibility combinations

Valid releases can combine layers that appear historically inconsistent:

- New PackageForTheWeb wrapper around an older InstallScript setup image.
- New `.ism` schema with a release configured to use an older setup launcher.
- Modern Advanced UI suite containing an old MSI or EXE parcel.
- Current installer using a legacy family-1 cabinet format.
- Basic MSI with an InstallScript custom action compiled by another runtime generation.

For this reason, structural decoding follows each layer's bytes. Release identity is explanatory metadata, not a decoder switch.

## Structural profile vocabulary

These references use short profile names to keep mixed generations visible:

| InstallShield structure | Profile name |
| --- | --- |
| Reusable 3.x engine | `Classic3/Engine` |
| Setup30 package | `Classic3/Package` |
| PackageForTheWeb wrapper | `Wrapper/PackageForTheWeb` |
| External launcher/media set | `Media/External` |
| Legacy or streamed PE overlay | `Overlay/InstallShield`, `Overlay/ISSetupStream` |
| InstallShield 5 pre-digest or digest cabinet | `Cabinet5/LegacyDescriptor` |
| ANSI modern cabinet | `Cabinet6/AnsiCatalog` |
| Unicode modern cabinet | `Cabinet17/UnicodeCatalog` |
| Compiled script | `Script/INS-Old`, `Script/OBS`, `Script/aLuZ`, `Script/kUtZ`; `Script/OBL` is reserved for explicit build-library analysis and is not an outer installer execution route |
| Windows Installer model | `MSI/Basic`, `MSI/InstallScript` |
| Advanced UI suite | `Suite/AdvancedUI` |

These names describe physical or execution structures, not InstallShield editions. A single setup can legitimately carry several profiles.

## Sources

Release mappings and historical references are collected in [the overview](overview.md#source-references). Structural details are grounded in official builder output and the format references listed there.
