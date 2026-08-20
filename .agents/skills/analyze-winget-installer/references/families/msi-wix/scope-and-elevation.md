# MSI scope and elevation

[Back to the MSI and WiX workflow](workflow.md)

## Architecture support

Use these `$Info` properties together:

- `Template` is the MSI summary template and primary package-platform evidence.
- `SupportedArchitectures` reports operating-system architectures on which the package can run.
- `UnsupportedArchitectures` reports explicit incompatibilities suitable for review against `UnsupportedOSArchitectures`.

Set manifest `Architecture` from the MSI package and installed payload architecture, not merely from the downloader filename. An x64 MSI remains `Architecture: x64` even when Windows on ARM can run it through x64 emulation; do not create an arm64 installer entry from compatibility alone. For a nominally x86 MSI that installs x64 files or uses architecture conditions, inspect component and payload evidence. Never use `neutral` when the package contains binary files.

Route missing or contradictory template, condition, and payload evidence to the canonical [VM validation workflow](../../workflows/vm-validation.md). Known unsupported-architecture examples include `Talkdesk.Talkdesk`, `PaloAltoNetworks.PrismaAccessBrowser`, `BelgianGovernment.eIDmiddleware`, and `LastPass.LastPass`.

## Scope and elevation

MSI can perform per-user or per-machine installation, but even per-user MSI products commonly register through system-level Windows Installer ARP data. This can cause WinGet to perceive a per-user MSI as machine-wide.

Apply the project convention:

- `$Info.AllUsers` is `1`: `Scope: machine` is safe.
- `$Info.AllUsers` is absent, empty, `2`, or another value: omit `Scope`; do not infer `user` from the property alone.
- Custom Registry-table ARP entries under HKCU or conditional scope actions: record the evidence, but validate actual Windows Installer product registration before asserting scope.

For dynamic validation, inspect the corresponding product registration under `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products` for machine context and under a user SID for user context. This supplements ARP location, which is not reliable enough for MSI scope by itself.

Evaluate elevation separately from scope. `$Info.ElevationRequirement` is `elevationRequired` only when the parser finds an explicit launch condition, effective Chromium enterprise product-tag and silent-command evidence, a scheduled restart-as-admin action, or the exact early InstallShield context-action layout observed to stop quiet non-elevated installation. Inspect every item in `$Info.ElevationRequirementEvidence`; `Confidence: Explicit` comes from authored behavior, while `Confidence: Observed` identifies a source-backed vendor layout whose practical effect was confirmed in VM testing.

Do not infer `ElevationRequirement` from `ALLUSERS=1`, `Scope: machine`, writes to HKLM/Program Files, services, drivers, no-impersonate deferred actions, or `AllowsInstallWithoutElevation: false` alone. Windows Installer defines a clear Summary Information Word Count bit 3 only as "elevated privileges can be required," not proof that the current package rejects a non-elevated launch.

Known distinct layouts include:

- `CatoNetworks.CatoClient`: a custom SCM-access probe feeds an explicit elevation `LaunchCondition`.
- `Cribl.CriblEdge`: an elevation launch condition plus a scheduled `RestartAsAdmin` action. The action proves an attempted restart, not that an unattended invocation survives it.
- `PaloAltoNetworks.PrismaAccessBrowser`: Chromium enterprise MSI actions plus a no-UI-only plain `--silent` modifier. Its embedded updater is tagged `needsadmin=Prefers`, but the outer MSI signature is not; the MSI command therefore retains its authored default `needsAdmin=True`.
- `Cisco.NetworkRecordingPlayer` and `CrisisGo.CrisisGo`: an early InstallShield `ISSetAllUsers` action; treat its `Observed` evidence distinctly because Revenera defines the action itself as upgrade-scope synchronization, not a general elevation declaration.

If the parser returns no elevation requirement but immediate custom actions run before the normal install transaction, compare quiet standard-user and elevated invocations from the same VM checkpoint. Record both exit codes and the failing action; do not execute the MSI on the host.

Do not use `ElevationRequirement: elevatesSelf` merely because `/passive` displays a UAC prompt. The elevated continuation must complete unattended from the original standard-user invocation. Current VM observations demonstrate why this distinction matters:

- `CatoNetworks.CatoClient`, `Cribl.CriblEdge`, and the nested MSIs from `DisplayLink.GraphicsDriver` request elevation under `/passive` but still fail afterward; they succeed when `msiexec` is launched from an already elevated shell. Use `elevationRequired`.
- `CrisisGo.CrisisGo` requests elevation under `/passive`, then opens an interactive InstallShield window. Advertise only `interactive` and `silent`; overriding `SilentWithProgress` with the quiet command is a defensive fallback, not evidence that progress mode is supported.
- `Cisco.NetworkRecordingPlayer` and `PaloAltoNetworks.PrismaAccessBrowser` request elevation under `/passive` and complete after it is accepted. Their `/quiet` invocations still require an already elevated caller, so use `elevationRequired`, not `elevatesSelf`.

These are version-specific dynamic observations. Revalidate when the MSI's custom actions or project type change.

#### Chromium Enterprise MSI Wrappers

Chromium's enterprise MSI is a WiX wrapper around a nested Chromium Updater or standalone application installer. Inspect the parser's focused evidence instead of treating it as an ordinary MSI:

```powershell
$ChromiumMsi = $Info.ChromiumEnterpriseMsiInfo

$ChromiumMsi.IsDetected
$ChromiumMsi.ProductTagSource
$ChromiumMsi.EffectiveNeedsAdmin
$ChromiumMsi.InstallCommand
$ChromiumMsi.SilentModifierActions
$ChromiumMsi.IsSilentAtNoUi
$ChromiumMsi.IsSilentAtBasicUi
$ChromiumMsi.SilentElevationBehavior
$ChromiumMsi.HasImmediateTagExtraction
$ChromiumMsi.DeferredInstallerAction
$ChromiumMsi.Diagnostics
```

The source-defined action order first runs `ExtractTagInfoFromInstaller`, builds a default `ProductTag`, optionally replaces it with the appended `TAGSTRING`, builds `InstallCommand`, and finally runs `DoInstall` as a deferred, no-impersonate custom action. Therefore:

- `ProductTagSource: OuterMsiTag` means the signed/appended tag overrides the default `SetProductTagProperty` value. Use `EffectiveNeedsAdmin`, not the default string retained in the CustomAction table.
- `UILevel=2` is no UI (`/quiet`) and `UILevel=3` is basic UI (`/passive`). A vendor action conditioned only on `UILevel=2` can pass `--silent` for quiet installation while leaving the nested updater interactive under passive installation.
- Chromium Updater deliberately refuses to display UAC for plain `--silent`. Only `--silent=allow-uac` permits that prompt. When the effective `needsadmin` value is `true` or `prefers`, the parser reports `SilentElevationBehavior: RequiresPreElevation` for a plain-silent path.
- MSI `NoImpersonate` grants elevated context only to deferred execution custom actions. It does not elevate the immediate `ExtractTagInfoFromInstaller` action. A vendor-modified extractor can therefore fail before the deferred nested installer is reached.

Current Chrome enterprise MSI fixtures are untagged, retain the default `needsAdmin=True`, and include plain `--silent` in the base nested command for all MSI UI levels. A UAC prompt observed from a standard-user Chrome MSI launch can be Windows Installer elevating before `DoInstall`; it does not contradict the nested updater's rule against prompting in plain-silent mode.

Current Prisma Access Browser fixtures contain an embedded updater tagged `needsadmin=Prefers`, but the outer MSI's `DigitalSignature` stream has no non-empty Omaha tag. Raw whole-file string scanning would incorrectly treat the embedded tag as the MSI's `TAGSTRING`; the parser deliberately does not do that. The MSI command retains its authored default `needsAdmin=True`, while a vendor custom action appends plain `--silent` only when `UILevel=2`. Consequently, `/quiet` requires an already elevated MSI context and can fail in its immediate tag-extraction path, while `/passive` leaves the nested updater non-silent and may display UAC. This explains the observed difference without treating the product name as a parser rule.

During VM validation, record which process owns the UAC prompt and the last MSI action reached in a verbose log. A prompt from `msiexec.exe` before deferred execution, a prompt from the nested updater, and a prompt followed by an unattended failure are different behaviors. Use `elevationRequired` unless the original standard-user invocation completes unattended after elevation; a UAC dialog by itself is not evidence for `elevatesSelf`.
