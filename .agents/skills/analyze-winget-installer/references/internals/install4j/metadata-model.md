# install4j metadata model

[Back to install4j internals](overview.md).

## Configuration document

`i4jparams.conf` is the runtime description of the packaged application. Modern files have a `config` root with builder version/build attributes, application metadata, installer applications, launchers, variables, styles, and media settings. Historical files use related but smaller schemas.

The file is configuration, not a transaction log. It records what the builder authored, while target-state conditions decide what executes.

## General application identity

Important application properties include:

| Property | Meaning |
| --- | --- |
| `applicationId` | Stable install4j application identity and usual uninstall-key name. |
| `applicationName` | Product name used by installer and launcher UI. |
| `applicationVersion` | Publisher-controlled application version. |
| `publisherName` / `publisherURL` | Publisher display and link values. |
| `defaultInstallationDirectory` | Runtime expression for the initial target directory. |
| `uninstallerFilename` / `uninstallerDirectory` | Installed maintenance launcher location. |
| `jreVersion` / `minJavaVersion` | Bundled or required Java evidence. |
| `bitness` | Media/application bitness selected by the builder. |

The application ID is not an MSI ProductCode. install4j IDs commonly use four groups of four decimal digits.

## Installer applications

A project can define installer, uninstaller, add/remove-program, response-file, or custom installer applications. Each application owns an ordered graph of screens and actions. Object class names identify standard runtime beans; object properties configure them.

GUI, console, and unattended paths can visit the same graph differently. Screens and form components may skip UI work in unattended mode while actions still execute.

## Standard actions relevant to installed state

| Action | Static significance |
| --- | --- |
| `RegisterAddRemoveAction` | Requests a Windows uninstall entry and supplies display values. |
| `RequestPrivilegesAction` | Describes when elevation is attempted and whether failure aborts. |
| `CreateFileAssociationAction` | Describes a Windows extension association. |
| File and directory actions | Contribute installed paths when their operands are literal. |
| Registry actions | Can add product state beyond the standard ARP action. |
| Run executable or script actions | Cross into child-process behavior. |

Action elevation, rollback, failure, and condition properties matter as much as the bean class. A class name alone does not prove that the action is reachable.

## Compiler variables

Compiler variables are resolved during media construction. Modern project and configuration files store their names and values separately. Literal references can therefore be expanded when all inputs are present.

Installer variables are runtime state. Common values include installation and response-file paths, media information, and values produced by earlier actions. Custom code can add or replace variables.

## Media and architecture

Media-set metadata controls architecture, platform, runtime bundling, output name, compression, and update behavior. One application ID can appear in multiple media files. The outer PE machine, configured bitness, bundled runtime, and installed native files are separate architecture evidence.

## Associations and protocols

File-association actions can expose extension, description, launcher, icon, and selection properties. Protocol registration can also be implemented through registry or custom code. Applications may defer either kind of registration to first run, outside install4j.

## Historical schemas

Generation 3 can omit explicit builder-version attributes and represents some associations as direct XML elements. Generation 4 is transitional. Later generations use Java-bean/XMLDecoder-style object properties for standard actions. Schema routes should be selected as a whole instead of mixing fields from different generations.
