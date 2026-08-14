# Compiler and output

## Build selection

One project can contain several builds. Each build chooses package type, architecture, resources, compression, prerequisite placement, signing, language, and output path. The same application version may therefore have several EXEs with different physical layouts.

## Direct MSI

Direct MSI output stores package identity in the Property table and authoring evidence in MSI tables, actions, and Summary Information. `CreatingApp: Advanced Installer 10.3` is exact builder-version evidence. A customized `CreatingApp` value such as an application name is not.

## Embedded EXE

Single-EXE output appends payload ranges and a file catalog to the native bootstrapper, followed by a self-describing footer. Catalog entries can identify the configuration INI, direct MSI, compressed main archive, cabinets, prerequisites, UI resources, and application-file archives.

## External resources

An EXE can keep the bootstrapper INI, main MSI archive, application-file archive, and other resources beside the launcher. The footer remains in the EXE and its external-resource table declares each sibling by role and relative name. Static extraction resolves those names beneath the setup directory and must not replace missing external media with a similarly named embedded file.

## Web media

Web media records `MainAppURL` in configuration. The runtime follows that URL before the embedded main-package branch. The local EXE may still contain prerequisites or UI resources, but they do not establish the downloaded MSI identity.

## Compressed media

Advanced Installer can place the MSI and installation files in an LZMA-backed 7z archive. The catalog identifies the archive; its nested paths identify the MSI selected after extraction. Password-protected media uses AES-256 and requires `/aespassword`. During nested-archive inspection, Dumplings reads the 7z coder metadata and reports encrypted entries or an encrypted header, but it does not decrypt password-protected content.

## Prerequisites

Prerequisites can be embedded, stored beside the EXE, or downloaded. Their own detection rules, command lines, privilege requirements, and result handling are separate from the main MSI. A bootstrapper can therefore require elevation or fail silent installation before the main package starts.
