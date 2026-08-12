# InstallShield project and build model

[Back to InstallShield internals](overview.md).

InstallShield separates authoring from release media. The `.ism` project stores logical installation data, scripts, build configurations, and source references. The build process converts one selected project configuration into MSI tables, InstallScript media, a suite catalog, or a combination of these outputs.

## Project database forms

Modern InstallShield projects occur in two structured representations:

```text
binary .ism
  -> OLE Compound File / Windows Installer database
  -> relational tables and streams

XML .ism
  -> <msi> root
  -> <summary>, <table>, <col>, <row>, and <td> records
  -> relational data equivalent to the authoring database
```

The XML form is common for source control and InstallScript sample projects. The binary form uses the same database machinery as MSI but contains authoring tables that are not copied wholesale into the built package.

The project database is not the installation database. It can contain several releases, product configurations, unused source paths, language variants, virtualization settings, and builder-only metadata.

## Table families

InstallShield reuses standard MSI table names where the concept maps directly, then adds `IS*` authoring tables.

| Table family | Examples | Purpose |
| --- | --- | --- |
| Standard MSI model | `Property`, `Directory`, `Feature`, `Component`, `File`, `Registry`, `Shortcut`, `CustomAction` | Product resources and Windows Installer behavior. |
| Project identity | `InstallShield`, `ISProductConfiguration`, `ISProductConfigurationProperty` | Schema and product-configuration metadata. |
| Releases and media | `ISRelease`, `ISReleasePro`, `ISReleaseProperty`, `ISReleaseProDataAsFiles`, `ISReleaseProPreviousMedias` | Output type, compression, disk layout, previous media, and release-specific settings. |
| Source resolution | `ISPathVariable`, `ISDynamicFile`, `ISDisk1File`, `ISSetupFile` | Build-time source locations and setup support files. |
| InstallScript media | `ISSetupType`, `ISSetupTypeFeatures`, `ISFeatureExtended`, `ISComponentExtended`, `ISRegistrySet`, `ISRegistrySetComponents`, `ISShortcutComponents` | Setup types, feature/component extensions, registry sets, and shell associations. |
| InstallScript code | `ISScriptFile`, `ISLinkerLibrary`, `Binary` | Script source/compiled artifacts, libraries, and runtime content. |
| Prerequisites | `ISSetupPrerequisites`, `ISFeatureSetupPrerequisites` | Release- or feature-selected prerequisite references. |
| Languages and strings | `ISLanguage`, `ISString`, localized dialog/control tables | Build languages and localized resources. |
| Suites and virtualization | Suite-specific project data, `ISVirtual*`, package-support tables | Advanced UI parcels and virtual-package output. |

Table availability depends on project type and builder generation. An `IS` prefix does not mean that a table survives into a shipped MSI or proprietary cabinet.

## Schema version

The `InstallShield` table contains `SchemaVersion`, an integer that describes the authoring database schema expected by a builder release. It is useful when an `.ism` project is available because it identifies which product generation can open or upgrade the project.

Schema version is not:

- The packaged application's version.
- The PE runtime version.
- The `ISc(` cabinet version.
- The InstallScript bytecode header version.
- An MSI database schema number.

Builders can upgrade a project schema while retaining older release settings or runtime compatibility. A shipped setup normally does not contain the complete `.ism`, so raw string searches for `SchemaVersion` are unreliable.

## Product configurations and releases

A project can have several product configurations. Each configuration can alter product code, package code, languages, transforms, instance identity, and other build properties. Releases then define how one configuration is packaged.

```text
project
+-- product configuration A
|   +-- release CompressedExe
|   `-- release NetworkImage
`-- product configuration B
    +-- release X64
    `-- release PatchBase
```

This explains why two installers built from one `.ism` can have different ProductCodes, languages, architectures, compression layouts, or prerequisite sets. Product configuration and release name are build dimensions, not display metadata for the installed application.

Release flags can select files, features, or prerequisites. A definition present in the project or builder repository is not necessarily emitted into every release.

## Source resolution

Project rows refer to source files through absolute paths, relative paths, path variables, dynamic-file links, merge modules, and object repositories. Build-time source layout does not survive as a reliable path map in distributed media.

The linker resolves these references into logical directories, components, file groups, and media entries. Dynamic file links can make the built catalog differ between builds without changing every authored row.

## InstallScript compilation

InstallScript source uses `.rul` files plus include files and object libraries. The build pipeline performs these broad steps:

```text
Setup.rul + included .rul/.h files
  -> parse types, prototypes, globals, handlers, and functions
  -> resolve built-in and imported runtime functions
  -> compile functions and control flow to InstallScript bytecode
  -> link referenced OBL libraries
  -> emit setup.inx/setup.ins and localized resources
```

Generated framework projects link InstallShield's IFX and ISRT libraries around the user's event handlers. `program ... endprogram` projects can provide their own top-level flow. Function presence therefore does not prove reachability.

Compiled OBL files can carry runtime libraries such as ISRT, IIS, SQL, XML, or suite support. The builder may link some functions into the final program and retain others as library members, depending on the generation.

## InstallScript media projection

For proprietary InstallScript media, the linker converts authoring tables into several connected structures:

```text
Directory/File/Component authoring
  -> cabinet directory strings and file descriptors
  -> file-group index ranges
  -> component-to-file-group topology

ISSetupType + ISSetupTypeFeatures
  -> locale-specific setup types
  -> feature-path selections

ISRegistrySet + ISRegistrySetComponents
  -> registry-set pointer graph
  -> root/key/value records
  -> optional component associations

Shortcut authoring
  -> shell-folder and packed shortcut records
  -> optional component associations
```

The build output stores these records in `data1.hdr`; compressed file bytes live in numbered `data*.cab` volumes. The runtime combines the media topology with script calls and user selection to decide which records take effect.

## MSI projection

Basic MSI projects turn standard authoring rows into a normal MSI database. InstallShield-specific authoring may also produce:

- Setup bootstrap configuration and prerequisites outside the MSI.
- Custom actions and helper binaries.
- InstallScript custom-action payloads in `Binary.ISSetup.dll`.
- Release-selected transforms and language packages.
- Tables used by the InstallShield runtime or build system.

InstallScript MSI adds runtime-verification and script-action table/action families. Basic MSI can still contain one or more compiled InstallScript custom actions.

## Advanced UI projection

Advanced UI builds a suite-level catalog rather than flattening every package into one MSI. Product and parcel authoring becomes `Setup.xml`, localized suite resources, transaction records, operation command lines, and staged or remote package files.

The suite's selection tree and condition model survive as runtime XML. Nested MSI, EXE, and prerequisite packages keep their own formats and identities.

## Media forms

The same logical setup can be emitted in several forms:

| Release form | Typical result |
| --- | --- |
| Compressed single executable | Launcher with an embedded overlay or wrapper archive. |
| Network image / uncompressed | `Setup.exe`, `Setup.ini`, scripts, headers, cabinets, and packages as sibling files. |
| CD/DVD or multi-disk | Numbered disk directories and split cabinet volumes. |
| PackageForTheWeb | Outer Microsoft Cabinet self-extractor containing a nested setup image. |
| MSI without bootstrapper | Direct MSI when no launcher-only behavior is required. |
| Suite | Advanced UI launcher plus suite catalog and parcels. |

Compression form does not change the authored installation model. It changes where the runtime finds its configuration, scripts, and payloads.

## What survives into shipped media

Some authoring evidence survives directly, while other information is compiled or discarded:

| Authoring evidence | Shipped representation |
| --- | --- |
| Product and company defaults | `Setup.ini`, MSI properties, suite ARP XML, or InstallScript runtime variables. |
| Files and directories | MSI tables or proprietary cabinet catalog. |
| Features and components | MSI tables or InstallShield media topology. |
| Registry and shortcuts | MSI tables or proprietary media records. |
| InstallScript source | Compiled INX/INS bytecode; source names/debug data depend on build settings. |
| Release settings | Launcher layout, media flags, package selection, compression, and prerequisites. |
| SchemaVersion | Usually absent unless the authored project itself is distributed. |
| Source paths and unused configurations | Normally omitted or reduced to incidental build metadata. |

This boundary matters during reverse engineering. A missing authoring row cannot be reconstructed merely because the builder once had it.

## Sources

Source grounding for this page includes official InstallShield 11.5 and 2026 builder projects, XML project samples, InstallShield framework and runtime source distributed with the builder, and the links collected in [the overview](overview.md#source-references).
