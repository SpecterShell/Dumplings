---
name: analyze-winget-installer
description: Analyze Windows installers for WinGet manifests and Dumplings automation. Use when the agent needs to identify EXE/MSI/MSIX/ZIP/portable installer technologies, inspect static metadata, decide InstallerType, ProductCode, UpgradeCode, Scope, InstallerSwitches, AppsAndFeaturesEntries, detect embedded MSI behavior, or plan VM-only dynamic installer testing without executing installers on the host.
---

# Analyze WinGet installers

## Workflow

1. Read [Installer analysis](references/workflows/installer-analysis.md), run `Get-WinGetInstallerAnalysis`, and select one family from its route table.
2. Read that family's `workflow.md`. Open its linked internals page only when implementing or debugging a parser.
3. Follow [Wrapper installers](references/workflows/wrapper-installers.md) when an outer executable selects, downloads, or launches another installer.
4. Read [Installed state](references/workflows/installed-state.md) when ARP matching, protocols, or file extensions matter.
5. Use [VM validation](references/workflows/vm-validation.md) only for facts static parsing cannot prove.
6. Persist large records through [Transient evidence](references/workflows/evidence.md).
7. Use [`$use-dumplings-functions`](../use-dumplings-functions/SKILL.md) when analysis needs shared networking, file, archive, content, feed, browser, HTML, or YAML helpers.
8. Read [Parser development](references/parser-development/workflow.md) before changing parser code.

Use `winget search` before scanning a winget-pkgs checkout. Once an identifier is known, navigate directly to its manifest and Dumplings task.

When installer analysis is part of manifest authoring, work against the current manifest draft. As soon as the manifest has the minimum required identity and installer fields, create and save it through `$author-winget-manifest`. Apply each conclusive parser or VM result to that working manifest before moving to the next unresolved question; do not retain all proven metadata for one final write at the end.

## Safety

Never execute an unknown installer or extracted payload on the host. Dynamic installation belongs in a checkpointed Windows Sandbox or Hyper-V VM.

Agents may use external static tools such as 7-Zip, NanaZip, Detect It Easy, or Exeinfo PE to investigate a format. Dumplings parsers, bridges, analyzers, tests, and CI must not invoke or depend on them. Treat their output as supporting evidence rather than the implementation or sole regression oracle.

Do not invent package metadata, registry values, format fields, silent switches, or installer behavior. Return unresolved facts as warnings and escalate only the affected decisions to VM validation.

## Required result

Report the detected family and decisive evidence; outer and installed architecture; static metadata and visible ARP owner; scope and elevation evidence; switches, modes, exit codes, and WinGet defaults; nested payload selection; external dependency evidence; protocols and extensions when proven; unresolved warnings; and whether VM validation is required.

Do not author `UnsupportedOSArchitectures` at present. Do not duplicate a localized ARP identity in `AppsAndFeaturesEntries` when the corresponding locale manifest can represent it.

## Implementation boundaries

Shared Apache-2.0 or MIT-compatible infrastructure belongs in PackageModule. GPL parser logic remains in InstallerParsers and crosses through the JSON child-process bridge. Keep mirrored common sources byte-identical.

Use these entry points:

- `Modules/PackageModule/Libraries/Infrastructure/InstallerBridge.psm1`
- `Modules/PackageModule/Libraries/Infrastructure/Runtime.psm1`, `Binary.psm1`, `Archive.psm1`, and `PE.psm1`
- `Modules/PackageModule/Libraries/Installers/*.psm1`
- `Modules/InstallerParsers/Cli.ps1` and `Modules/InstallerParsers/Libraries/Installers/*.psm1`
