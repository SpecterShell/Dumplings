# Paquet Builder architecture

## Producer and runtime layers

Paquet Builder compiles project data into a native Windows launcher. The launcher owns startup, command-line handling, elevation, dialogs, catalog interpretation, extraction, and uninstaller setup. Application files remain data until a catalog record maps them to an installed destination or an execution command starts them.

```text
builder project
`-- compiler
    +-- launcher PE
    +-- runtime engine
    +-- package program or controller
    +-- application payload
    `-- optional uninstaller and nested setup

launcher process
+-- identify physical generation
+-- initialize built-in variables
+-- evaluate package conditions and dialogs
+-- extract or copy selected files
+-- apply registry, shortcut, and file operations
+-- create uninstall support
`-- optionally execute packaged programs
```

Classic 2.6 delegates installed-file copying to a packed `SETUP.EXE` controller and an ordered `SETUP1.GAF` stream. Versions 2.7 through 2.9 carry a text `GINFOS` program in a compressed named-resource table. Version 3 and later compile equivalent behavior into the launcher and call exported `PBCore*.dll` functions. These representations are separate parser routes even when they implement similar user-visible behavior.

## Identity domains

The launcher PE identifies the distributed executable and often carries the builder product name because the fixture is the Paquet Builder installer itself. Installed application identity can instead come from explicit uninstall registry writes, `UNINSTKEY` plus `UNINSTALLINFO`, a literal modern uninstall-key path, or a nested MSI that the package program installs. The parser does not substitute PE ProductName for ProductCode.

```text
launcher identity              installed-package identity
---------------------------    --------------------------------------
PE ProductName                 uninstall-key suffix
PE ProductVersion              nested MSI ProductCode and UpgradeCode
PE CompanyName                 ARP DisplayName, DisplayVersion, Publisher
requestedExecutionLevel        selected registry hive and scope
```

## Container ownership

Archive membership alone does not prove ownership. A 2.7 or 2.8 wrapper with one MSI is a verified MSI bootstrapper route. A 2.9 MSI is selected only when `GINFOS` invokes `PBExecMSI` for that exact payload-relative path. Modern payload archives may contain MSI files as ordinary application data, so the parser never selects them by wildcard search.

Runtime and payload archives in Split3 media are classified by content. An archive containing `pbfprop.dat` or `PBCore.dll`, `PBCore64.dll`, or `PBCoreA64.dll` is runtime material. The largest remaining validated 7z archive is the application payload. Physical order is not used as the classifier.

## Trust boundaries

The outer file, every offset, every declared length, compressed data, decoded record count, resource name, destination path, and nested archive is untrusted. Detection requires mutually supporting structure rather than marker strings. Parser output distinguishes direct records from runtime conclusions, and unknown numeric fields remain `ObservedField` values.

The parser never loads a recovered PE as an assembly, calls a packaged DLL, or executes setup code. Managed decoders receive bounded streams. Extraction resolves every output below the requested destination and applies collision policy only after a collision occurs.

## Memory ownership

The installer is opened once for PE and generation-specific resource parsing. Large 7z, ZIP, cabinet, and GAF payloads are streamed through bounded ranges. The largest intentional in-memory objects are the mapped file-backed PE region used for native call-site scanning, a bounded configuration table, or one selected classic controller record set. Installer overlays are not materialized as one byte array.
