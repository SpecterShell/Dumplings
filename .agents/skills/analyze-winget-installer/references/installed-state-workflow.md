# Installed-State And Association Workflow

Use installed-state evidence to determine what WinGet will match after installation and which protocol or file-extension associations are safe to place in a manifest.

## ARP Collection

Scan all three uninstall locations:

```text
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\
```

WinGet ignores entries without a string `DisplayName` and entries with `SystemComponent=1`. Preserve hidden entries as wrapper/MSI evidence, but do not treat them as visible Apps & Features entries. WinGet classifies an entry as MSI when `WindowsInstaller=1`; otherwise it is an EXE-style entry unless WinGet itself registered a portable package.

HKLM normally indicates machine scope and HKCU normally indicates user scope. MSI is exceptional: its visible ARP entry can be in HKLM despite per-user installation behavior. Use MSI properties and `Installer\UserData` evidence as supporting scope evidence. Never infer installed architecture from `WOW6432Node`.

PackageModule can collect both ARP and AppX/MSIX installed entries:

```powershell
. .\Modules\PackageModule\Index.ps1
$Entries = Get-WinGetInstalledEntry -IncludeSystemComponent
$Delta = Compare-WinGetInstalledEntrySnapshot -Before $Before -After $After
```

For MSI user-data context:

```powershell
Resolve-WinGetMsiARPInstallContext -ProductCode '{PRODUCT-CODE}'
```

`S-1-5-18` is machine-context evidence, the current user SID is current-user evidence, and another SID indicates another user's registration. WinGet does not currently use this additional context for matching.

## WinGet Matching Model

WinGet correlates manifests with installed entries through exact keys and normalized name/publisher evidence:

- `ProductCode` matches the ARP uninstall key.
- `UpgradeCode` expands to products registered for that MSI upgrade code.
- `PackageFamilyName` matches AppX/MSIX packages.
- Normalized `DisplayName`/`PackageName` plus `Publisher` provides fallback identity.

`Publisher` is not required in every ARP entry. If absent, WinGet can still match through ProductCode, UpgradeCode, or PackageFamilyName; a default-locale publisher does not manufacture missing registry evidence.

Check a manifest against collected entries:

```powershell
$Manifest = Read-WinGetManifest -Path C:\Path\To\ManifestDirectory

Find-WinGetManifestInstalledEntryMatch -Manifest $Manifest -InstalledEntry $Entries
```

For new packages, keep installer-level `ProductCode` when useful but do not duplicate it inside `AppsAndFeaturesEntries`. Add an Apps & Features entry only when visible ARP type, name, publisher, or display version differs materially from what WinGet derives from the manifest.

## Protocol And File-Extension Evidence

Static parser evidence is preferred. Format parsers return literal registry writes and normalized association information through their main `Get-*Info` result. Call the parser once and reuse that object instead of reparsing with individual `Read-*` helpers.

Dynamic registration can appear under:

- `HKLM\Software\Classes` or `HKCU\Software\Classes`.
- `HKLM\Software\RegisteredApplications` or `HKCU\Software\RegisteredApplications`, pointing to `Capabilities\FileAssociations` and `Capabilities\URLAssociations`.
- AppX/MSIX manifest extension declarations.

A protocol requires a literal scheme name, registration evidence such as `URL Protocol`, and an open command or package declaration. A file extension requires a literal extension and ProgID/capability evidence. Preserve the ProgID, command, icon, hive, registry view, and source path so another agent can audit the conclusion.

Many applications register associations only on first run. Compare these phases separately:

1. Before installation to after installation.
2. After installation to after first application run.

Ignore `UserChoice`, Explorer caches, recent-file state, and ambient shell changes. Do not add a protocol or extension merely because its text appears in a binary.

`Protocols` and `FileExtensions` are not currently indexed like `Commands`, but include them when literal evidence exists because they document package behavior and may become useful to clients later.

## Dynamic Evidence Script

Use the staged scripts documented in [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md). Their comparison output separates:

- Visible ARP changes.
- Hidden or incomplete ARP changes.
- Protocol changes.
- File-extension changes.

Every change includes `Before` and `After` objects with stable registry identities. A change is evidence, not automatically a manifest field: verify that its command resolves to the installed application and that it is not an unrelated dependency or runtime registration.

## Failure Patterns

- Outer EXE classified as MSI because it embeds an MSI: classify the visible ARP entry, not the payload container.
- Hidden MSI plus visible custom EXE entry: retain both as evidence and model the visible EXE entry.
- Version included in `DisplayName`: do not add redundant `AppsAndFeaturesEntries.DisplayName` when WinGet normalization already removes the version and matching remains stable.
- Protocol registered only after first run: record it from the second delta and label the phase.
- Architecture inferred from registry view: reject the inference and inspect installed binaries or package metadata.

## Source Trace

The helper behavior follows winget-cli's installed source, ARP correlation, manifest comparator, and AppX inventory implementations in [microsoft/winget-cli](https://github.com/microsoft/winget-cli). Dumplings implements auditable PowerShell equivalents in `WinGetARP.psm1` and `RegistryAssociations.psm1`.
