# InstallShield parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [InstallShield workflow](../../families/installshield/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

InstallShield generations use different outer containers, media catalogs, and execution models. Open only the page for the detected variant:

- [Outer containers](containers.md): PE overlays, PackageForTheWeb, streams, and sibling MSI selection.
- [Proprietary media and cabinets](media-cabinets.md): `data1.hdr`, file groups, components, registry sets, and shortcuts.
- [InstallScript bytecode](installscript-bytecode.md): INX catalogs, opcodes, conditions, dialogs, and static effects.
- [MSI custom actions](msi-custom-actions.md): `ISSetup.dll`, `IsConfig.ini`, MSI action dispatch, and embedded InstallScript.
- [Advanced UI](advanced-ui.md): suite XML, parcels, outer ARP identity, operations, and conditions.

Each variant must pass the same content-based detection and bounds checks.

## Binary structure

The parser consumes the format structures described below. Offsets use the bases stated in each diagram.

## Detection invariants

Accept the family only when the surrounding headers, ranges, counts, and relationships described above validate. Treat an isolated marker as a routing hint and preserve conditional values as unresolved evidence.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/InstallShield.psm1
- Modules/PackageModule/Libraries/Installers/InstallShieldContainer.psm1
- Modules/PackageModule/Libraries/Installers/InstallShieldInstallScript.psm1
- Modules/PackageModule/Libraries/Installers/InstallShieldMsi.psm1
- Modules/PackageModule/Libraries/Installers/InstallShieldAdvancedUI.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [ISx](https://github.com/lifenjoiner/ISx)
- [Revenera SetupIni.exe and embedded Setup.ini](https://docs.revenera.com/installshield26helplib/helplibrary/SetupIniExe.htm)
- [Revenera Setup.ini reference](https://docs.revenera.com/installshield/helplibrary/SetupIni.htm)
- [Revenera Setup.ini Startup section](https://docs.revenera.com/installshield/helplibrary/StartupSection.htm)
- [Revenera Advanced UI and Suite/Advanced UI overview](https://docs.revenera.com/installshield26helplib/helplibrary/SteOverview.htm)
- [Revenera Advanced UI and Suite condition model](https://docs.revenera.com/installshield26helplib/helplibrary/SteBuildingConditions.htm)
- [Revenera package and transaction order](https://docs.revenera.com/installshield26helplib/helplibrary/SteInstallOrder.htm)
- [Revenera InstallShield Prerequisite Editor reference](https://docs.revenera.com/installshield26helplib/helplibrary/SetupPrereqEditor.htm)
- [Revenera prerequisite administrative-privilege setting](https://docs.revenera.com/installshield27helplib/helplibrary/SetupPrereqEditorAdminPrivs.htm)
- [Revenera required execution level](https://docs.revenera.com/installshield26helplib/helplibrary/SpecifyingRequiredExecution.htm)
- [Microsoft MSI Word Count summary property](https://learn.microsoft.com/en-us/windows/win32/msi/word-count-summary)
- [Revenera AddSuitePackage automation method](https://docs.revenera.com/installshield26helplib/helplibrary/AddSuitePackage-Ste.htm)
- [Revenera MaintenanceStart](https://docs.revenera.com/installshield/LangRef/LangrefMaintenanceStart.htm)
- [Revenera PRODUCT_GUID](https://docs.revenera.com/installshield/LangRef/LangrefPRODUCT_GUID.htm)
- [Revenera special registry functions and ARP values](https://docs.revenera.com/installshield/LangRef/RegSpecialFuncs.htm)
- [Revenera RegDBSetDefaultRoot](https://docs.revenera.com/installshield28helplib/LangRef/LangrefRegDBSetDefaultRoot.htm)
- [Revenera RegDBSetKeyValueEx](https://docs.revenera.com/installshield28helplib/LangRef/LangrefRegDBSetKeyValueEx.htm)
- [Revenera CreateRegistrySet](https://docs.revenera.com/installshield/LangRef/LangrefCreateRegistrySet.htm)
- [Revenera CreateShellObjects](https://docs.revenera.com/installshield/LangRef/LangrefCreateShellObjects.htm)
- [Revenera LaunchAppAndWait](https://docs.revenera.com/installshield/LangRef/LangrefLaunchAppAndWait.htm)
- [Revenera UNINSTALL_DISPLAYNAME](https://docs.revenera.com/installshield/LangRef/LangrefUNINSTALL_DISPLAYNAME.htm)
- [Revenera creating response files](https://docs.revenera.com/installshield30helplib/helplibrary/CreatetheResponseFile.htm)
- [Revenera response-file dialog sequence](https://docs.revenera.com/installshield27helplib/helplibrary/ResponseFileDialogBoxSequence.htm)
- [Revenera response-file dialog data](https://docs.revenera.com/installshield/helplibrary/ResponseFileDialogBoxData.htm)
- [darknesswind/IsDcc](https://github.com/darknesswind/IsDcc) (behavioral comparison only; source is not incorporated)
- [incognitte/isDcc](https://github.com/incognitte/isDcc) (legacy INS behavioral reference)
- [pawstas80/IsDccSharp](https://github.com/pawstas80/IsDccSharp) (modern INX behavioral comparison only)
- [Unshield](https://github.com/twogood/unshield) (MIT InstallShield cabinet format and Deflate behavior)
- [Microsoft SetupIterateCabinet](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupiteratecabinetw)
- [Microsoft FILE_IN_CABINET_INFO](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/ns-setupapi-file_in_cabinet_info_w)
