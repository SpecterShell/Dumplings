# InstallShield workflow

## When to use

Use `InstallerType: exe # InstallShield` when WinGet invokes an InstallShield EXE wrapper. Direct InstallShield-authored MSI packages are covered in the [MSI and WiX workflow](../msi-wix/workflow.md).

InstallShield Advanced UI is a separate EXE family with different switches. Do not apply Basic MSI switches to Advanced UI unless package-specific evidence proves they work.

## Detection
Route here when `Get-InstallShieldInfo` succeeds, static strings contain `InstallShield`, `ISSetup.dll`, `InstallScript`, `setup.inx`, or package history strongly suggests InstallShield.

Classify the variant before writing manifest fields. The presence of an MSI is not sufficient by itself because Advanced UI and Suite/Advanced UI can carry MSI parcels:

- Basic MSI: the selected MSI is InstallShield-authored but lacks the InstallScript MSI runtime verifier/tables. A Basic MSI may still contain individual compiled InstallScript custom actions in `Binary.ISSetup.dll`; those actions do not change the project type.
- InstallScript MSI: the selected MSI contains `ISInstallScriptAction`, `ISScriptFile`, `ISInstallScript*`, or `ISVerifyScriptingRuntime` evidence.
- InstallScript-only: no MSI payload; often requires response-file replay.
- Advanced UI or Suite/Advanced UI: extracted `Setup.xml` uses the `installshield/<year>/bootstrap` namespace and contains `ARPInfo`/`Parcels`.

Block InstallScript-only installers when silent installation requires a response file, because response-file replay is not accepted by winget-pkgs validation.

## Static analysis
1. Use [Classification](classification.md) to separate Basic MSI, InstallScript MSI, InstallScript, PackageForTheWeb, Advanced UI, and Suite/Advanced UI.
2. Select the corresponding [manifest shape](manifest-shapes.md).
3. Resolve visible ARP ownership and silent behavior through [ARP and silent analysis](analysis.md).
4. Read [InstallShield internals](../../internals/installshield/overview.md) when
   the setup's project model, runtime lifecycle, media generation, or nested
   package ownership is unclear.

## Manifest shape

Select the [Basic MSI, InstallScript MSI, InstallScript-only, or Advanced UI shape](manifest-shapes.md) established by classification. Project only fields supported by parser or VM evidence into the installer entry.

## WinGet defaults and overrides

WinGet supplies no InstallShield-specific defaults for outer `InstallerType: exe`. Treat each shown switch as a complete override for the proven InstallShield variant. Preserve no-reboot arguments in silent modes, and do not apply Basic MSI forwarding switches to InstallScript-only or Advanced UI packages.

## Apps & Features

Use [ARP and silent analysis](analysis.md) to identify the visible Apps & Features owner. Do not substitute metadata from a hidden parcel or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use the [variant classification](classification.md) and selected MSI or payload evidence for scope and installed architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation
Follow [VM validation](../../workflows/vm-validation.md) and the variant-specific checks in [ARP and silent analysis](analysis.md). InstallScript media without source-backed fileless silent support normally requires a response or message file and is not currently suitable for WinGet.

## Known examples

- `Celsys.ClipStudioPaint`: InstallScript-only exception with usable silent behavior.
- `Trimble.SketchUp`: Advanced UI suite.
- `NorconsultDigital.ISYLinker`: prerequisite and elevation-sensitive InstallShield wrapper.
- `Thorlabs.ThorlabsDeviceSDK`: bundled prerequisites and silent-install elevation behavior.
