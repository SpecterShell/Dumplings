---
name: analyze-winget-installer
description: Analyze Windows installers for WinGet manifests and Dumplings automation. Use when Codex needs to identify EXE/MSI/MSIX/ZIP/portable installer technologies, inspect static metadata, decide InstallerType, ProductCode, UpgradeCode, Scope, InstallerSwitches, AppsAndFeaturesEntries, detect embedded MSI behavior, or plan VM-only dynamic installer testing without executing installers on the host.
---

# Analyze WinGet Installer

## Workflow

Use this skill before writing manifest installer fields or Dumplings task parsing logic:

1. Read `references/workflow.md`, run the analyzer, and use its single route table to select one focused installer-family page.
2. Read `references/installed-state-workflow.md` when ARP matching, `Protocols`, or `FileExtensions` matter.
3. Read `references/vm-validation-workflow.md` only for facts static parsing cannot prove.
4. Read `references/parser-development-workflow.md` only when implementing or refactoring parser code.

The focused family page owns its parser commands, manifest shapes, defaults, exceptions, examples, and implementation sources. Shared manifest field placement and ordering live in the authoring skill's `manifest-workflow.md`.

Never execute unknown installers on the host. Prefer static parsing. Use dynamic installation only in Windows Sandbox or a Hyper-V VM with checkpoint/restore.

When resolving an existing package identifier or finding package examples, use `winget search` first. After WinGet returns an identifier, navigate directly to that package's manifest path. Do not recursively scan the complete winget-pkgs tree unless the public source and scoped direct lookup cannot provide the required evidence.

For a quick static pass inside Dumplings, call `Get-WinGetInstallerAnalysis -Path <installer>` after loading `Modules\PackageModule\Index.ps1`. The analyzer uses magic bytes and structured evidence before extensions and invokes already-loaded parsers without launching the installer. Route the resulting family through `references/workflow.md`. For JSON output, use `scripts\Analyze-WinGetInstaller.ps1 -Path <installer>`.

Agents may use external static tools such as 7-Zip, NanaZip, Detect It Easy, or Exeinfo PE to investigate or cross-check a file. Dumplings parser modules, bridges, analyzers, tests, and CI paths must not invoke or depend on those executables. Treat tool output as supporting evidence and keep installer or payload execution off the host.

For staged Hyper-V evidence capture, use `scripts\Invoke-WinGetVMInstalledState.ps1`. It stages `Get-WinGetVMInstalledState.ps1` and captures named checkpoints but never launches the installer or application.

## Required Output

Return installer evidence, not just a guessed `InstallerType`:

- Installer family and confidence level.
- Static parser/tool used and exact metadata extracted.
- Installer architecture and installed application architecture.
- `ProductVersion`, `UpgradeCode`, `PackageFamilyName`, visible ARP evidence from HKLM/HKCU uninstall keys, and optional `ProductCode` evidence when useful.
- Whether the EXE writes an EXE ARP entry, an MSI ARP entry, both, or hides one with `SystemComponent`.
- Literal protocol and file-extension association evidence, or an explicit statement that the parser cannot prove it statically.
- Required `InstallerSwitches`, `InstallModes`, `InstallerSuccessCodes`, `ExpectedReturnCodes`, `Scope`, `ElevationRequirement`, and `AppsAndFeaturesEntries`.
- Which switch and mode values are WinGet defaults for the effective installer type, so the authoring step can omit redundant fields such as NSIS `/S`.
- Unsupported-architecture evidence for selecting valid installer entries; do not turn this evidence into `UnsupportedOSArchitectures` at the moment.
- Whether dynamic VM validation is required before manifest submission.

## Decision Rules

Use specific WinGet installer types when supported: `inno`, `nullsoft`, `burn`, `wix`, `msi`, `msix`, `appx`, `zip`, and `portable`. Use generic `exe` only when the installer is not a supported known type and silent behavior is known.

For known installer types, distinguish required overrides from WinGet defaults. Do not recommend manifest keys that merely repeat the defaults. For a ZIP, apply this rule using the effective `NestedInstallerType`.

When an EXE wraps an MSI, do not assume `AppsAndFeaturesEntries.InstallerType` matches manifest `InstallerType`. Model the visible ARP entry WinGet will see.

When a release serves both an InstallShield or Advanced Installer EXE and a direct MSI, compare the direct MSI with the exact MSI selected by the wrapper. If version, architecture, scope, features, and visible ARP identity are equivalent, recommend the MSI only. Report any wrapper-only prerequisites, transforms, chained payloads, or custom ARP behavior that prevents this simplification.

Map evidenced localized ARP `DisplayName` and `Publisher` values to `PackageName` and `Publisher` in the corresponding locale manifests. Retain them in `AppsAndFeaturesEntries` only when that locale manifest does not exist.

For new packages, avoid adding `AppsAndFeaturesEntries.ProductCode` unless the package policy or an existing manifest style specifically requires it. Keep product codes as useful evidence for MSI correlation, not as a default Apps & Features field.

When an Inno or NSIS installer supports both user and machine scopes, create duplicate installer entries with distinct `Scope` and custom switches such as `/CURRENTUSER` vs `/ALLUSERS` or lowercase variants, matching the installer’s actual parser or VM evidence.

Block InstallShield InstallScript-only installers when no MSI can be extracted and silent install requires a response file. Response-file installation is not supported by WinGet validation for winget-pkgs.

Reject an installer when VM validation stalls at the Windows Security **Would you like to install this device software?** driver-publisher consent dialog. Record the dialog and process state, then restore the checkpoint. Do not approve the prompt, pre-trust the publisher certificate, pre-stage the driver, or change driver policy to manufacture an unattended result. Follow [VM-Only Dynamic Validation Workflow](references/vm-validation-workflow.md#reject-blocking-driver-trust-prompts) for the evidence and rejection procedure.

## Local Implementation Pointers

Use these repository-relative sources for deeper implementation details. Upstream format references are recorded in each focused installer page and parser module header.

- Dumplings parser bridge: `Modules\PackageModule\Libraries\Infrastructure\InstallerBridge.psm1`
- Dumplings shared core: `Modules\PackageModule\Libraries\Infrastructure\Runtime.psm1`, `Binary.psm1`, `Archive.psm1`, `PE.psm1`, and `InstallerEvidence.psm1`
- Portable analysis: `Modules\PackageModule\Libraries\Infrastructure\PEArchitecture.psm1` and `PEDependency.psm1`
- Dumplings parser wrappers: `Modules\PackageModule\Libraries\Installers\*.psm1`
- GPL parser module: `Modules\InstallerParsers\Cli.ps1`, `Libraries\Installers\NSIS.psm1`, `Inno.psm1`, `AdvancedInstaller.psm1`, and `QtInstallerFramework.psm1`
- [WinGet manifest examples](https://github.com/microsoft/winget-pkgs/tree/master/manifests): search for installer family comments and `AppsAndFeaturesEntries`.
