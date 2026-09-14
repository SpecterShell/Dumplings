# Wise architecture

## Product families

Classic Wise Installation System and Wise InstallMaster compile procedural WiseScript projects into native setup executables. Wise for Windows Installer packages an MSI database behind a Wise PE launcher. Wise Package Studio and later Symantec releases contain other tooling, but their product names alone do not identify the layout of a distributed setup.

The parser reports physical routes instead of treating the marketing version as dispatch authority. An NE-hosted WiseScript installer and a PE-hosted WiseScript installer can share the same script and payload framing. A WiseScript wrapper can also contain a Wise for Windows Installer payload.

## Runtime layers

```text
outer process
+-- DOS/NE or DOS/PE loader
+-- command-line parser and elevation policy
+-- WiseScript interpreter
|   +-- variables and event blocks
|   +-- file and registry actions
|   +-- process and DLL calls
|   `-- install-log and uninstaller generation
`-- optional nested process
    +-- Wise `.WISE` MSI launcher
    `-- Windows Installer service and MSI database
```

The outer executable's machine type describes the bootstrapper. It does not prove the installed payload architecture. The MSI template and extracted application binaries are stronger architecture evidence.

## Identity domains

Wise media can contain several identifiers with different purposes:

| Identity | Source | Use |
| --- | --- | --- |
| Wise project title | WSE global data or script variables | UI and possible custom ARP display name |
| WiseScript uninstall-key suffix | literal registry actions | candidate EXE ProductCode |
| Resume or Run-key token | temporary script registry action | setup continuation only, never ProductCode |
| MSI ProductCode | nested MSI Property table | Windows Installer product and MSI ARP identity |
| MSI UpgradeCode | nested MSI Property table | Windows Installer upgrade family |
| PE ProductVersion | launcher version resource | outer runtime or vendor launcher version, not automatically package version |

## Trust boundaries

The parser does not execute WiseScript. It decodes bounded records and projects deterministic operands. External DLL calls, downloaded files, environment-dependent branches, user choices, and generated uninstaller behavior remain runtime evidence.

The MIT SabreTools reader supplies typed NE and WiseScript records. Dumplings owns route detection, stream bounds, Deflate and CRC validation, metadata authority, diagnostics, and WinGet projection. The parser never invokes WiseUnpacker or another extractor executable.
