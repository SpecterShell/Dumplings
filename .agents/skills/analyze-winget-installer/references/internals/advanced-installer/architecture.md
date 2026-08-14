# Architecture

## Authoring layer

An `.aip` file is the editable project. It stores product properties, files, components, dialogs, prerequisites, build definitions, launch conditions, signing settings, and package-output options. Its schema changes with the builder and can be upgraded when opened by a newer release.

Compiled media is not a copy of the project. The compiler lowers project data into MSI tables, bootstrapper configuration, resource catalogs, and nested payloads. Most authoring-only data and the commercial license edition disappear.

## Output layers

```text
application source files
  -> MSI compiler
      -> Property, Directory, Component, File, Registry, Upgrade, and AI_* tables
      -> cabinets or loose files
      `-> Summary Information
  -> optional EXE compiler
      -> PE launcher
      -> bootstrapper INI
      -> catalog records
      -> embedded archives/packages
      `-> footer
```

A direct MSI bypasses the EXE format completely. An EXE can carry one MSI, an architecture pair, an MSIX choice, an LZMA/7z archive containing the package, prerequisites, or only a URL to external media.

## Runtime ownership

The bootstrapper owns package discovery, prerequisite processing, architecture selection, language selection, extraction, and child invocation. Windows Installer owns the transaction and native MSI ARP registration after the selected MSI starts. A custom MSI Registry row can hide the native entry and create a visible EXE-style entry.

Suite Installer output uses another model. Its MSI contains a suite package graph and must stay under MSI analysis. A direct MSIX/AppX package stays under MSIX/AppX analysis. The presence of Advanced Installer strings does not turn those files into `ADVINSTSFX` media.

## Architecture domains

The PE stub architecture answers which native launcher starts. The selected MSI Summary Information answers the nested package architecture. Installed executables answer the application architecture. These values may differ.

Classic `AllPlatforms=true` media uses an x86 stub and a WOW64 test. The base MSI is selected on x86 Windows and a `.x64` filename is selected when the process runs under WOW64. An x86 process emulated on ARM64 also follows that branch, so the selected x64 MSI still needs independent architecture validation. Modern fixed-path media can carry an ARM64 MSI without making the outer stub ARM64.

## Edition attribution

Advanced Installer product pages associate some output features with paid editions, but a generated package normally records the selected feature and media shape, not the license that enabled it. The same physical output can also be rebuilt by a later edition or imported project. Dumplings reports media capabilities and leaves commercial edition unset.
