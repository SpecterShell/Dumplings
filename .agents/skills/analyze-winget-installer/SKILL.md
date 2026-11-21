---
name: analyze-winget-installer
description: Analyze Windows installers for WinGet manifests and Dumplings automation. Use when the agent needs to identify EXE/MSI/MSIX/ZIP/portable installer technologies, inspect static metadata, decide InstallerType, ProductCode, UpgradeCode, Scope, InstallerSwitches, AppsAndFeaturesEntries, detect embedded MSI behavior, or plan VM-only dynamic installer testing without executing installers on the host.
---

# Analyze WinGet installers

## Runtime

Run Dumplings module commands and host-side skill scripts with PowerShell 7.4 or later (`pwsh`). Windows PowerShell 5.1 is unsupported unless a specific self-contained guest collector says otherwise.

## Workflow

1. Read [Installer analysis](references/workflows/installer-analysis.md), run `Get-WinGetInstallerAnalysis`, and select one family from its route table.
2. Read that family's `workflow.md`. If a GUI executable remains unidentified, [inspect its interface in the VM](references/families/generic-exe/workflow.md#inspect-an-unidentified-gui-executable-in-the-vm) to distinguish a portable application from a custom installer. Open the linked internals page only when implementing or debugging a parser.
3. Follow [Wrapper installers](references/workflows/wrapper-installers.md) when an outer executable selects, downloads, or launches another installer.
4. Read [Installed state](references/workflows/installed-state.md) when ARP matching, protocols, or file extensions matter.
5. Use static evidence to select switches and narrow the test matrix. Complete [VM validation](references/workflows/vm-validation.md) for every distinct installer route before submission. Use [VM network capture](references/workflows/vm-network-capture.md) when runtime downloads or update sources need investigation.
6. Persist large records through [Transient evidence](references/workflows/evidence.md).
7. Use [`$use-dumplings-functions`](../use-dumplings-functions/SKILL.md) when analysis needs shared networking, file, archive, content, feed, browser, HTML, or YAML helpers.
8. Read [Parser development](references/parser-development/workflow.md) before changing parser code.

Use `winget search` before scanning a winget-pkgs checkout. Once an identifier is known, navigate directly to its manifest and Dumplings task.

Analyze against the current manifest draft. Create and save it through `$author-winget-manifest` once the required identity and installer fields are known. Apply each conclusive parser or VM result before investigating the next question.

## Safety

Never execute an unknown installer or extracted payload on the host. Dynamic installation belongs in a checkpointed Windows Sandbox or Hyper-V VM. An installer entry is incomplete until its exact artifact, switches, scope, and elevation route complete unattended without a blocking prompt or other manual action.

If host or VM security software flags an executable as a virus or malware, stop the affected package workflow immediately and warn the user. Follow [Stop on malware alerts](references/workflows/installer-analysis.md#stop-on-malware-alerts).

Agents may investigate formats with external static tools such as 7-Zip, NanaZip, Detect It Easy, or Exeinfo PE. Dumplings parsers, bridges, analyzers, tests, and CI must not invoke or depend on them. Corroborate their output with format sources or independent evidence.

Do not invent package metadata, registry values, format fields, silent switches, or installer behavior. Return unresolved facts as warnings and escalate only the affected decisions to VM validation.

## Required result

Report the family and decisive evidence, including outer and installed architecture, static metadata, ARP ownership, scope, and elevation. Record switches, modes, logs, exit codes, and relevant WinGet defaults. Include nested payload selection, dependencies, PATH changes, CLI commands, and proven protocols or extensions. Finish with unresolved warnings and the VM-validation outcome.

Do not author `UnsupportedOSArchitectures` at present. Do not duplicate a localized ARP identity in `AppsAndFeaturesEntries` when the corresponding locale manifest can represent it.

## Implementation boundaries

Shared Apache-2.0 or MIT-compatible infrastructure belongs in PackageModule. GPL parser logic remains in InstallerParsers and crosses through the JSON child-process bridge. Keep mirrored common sources byte-identical.

Implementation entry points:

- `Modules/PackageModule/Libraries/Infrastructure/InstallerBridge.psm1`
- `Modules/PackageModule/Libraries/Infrastructure/Runtime.psm1`, `Binary.psm1`, `Archive.psm1`, and `PE.psm1`
- `Modules/PackageModule/Libraries/Installers/*.psm1`
- `Modules/InstallerParsers/Cli.ps1` and `Modules/InstallerParsers/Libraries/Installers/*.psm1`
