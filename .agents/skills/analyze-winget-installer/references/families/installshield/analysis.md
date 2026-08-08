# InstallShield ARP and silent behavior

[Back to the InstallShield workflow](workflow.md)

## Identify the visible ARP owner

For Basic MSI or InstallScript MSI, use the extracted MSI values for installer-level `ProductCode` and `AppsAndFeaturesEntries.UpgradeCode`. Set `AppsAndFeaturesEntries.InstallerType` to `msi` or `wix` only when the visible ARP entry comes from that MSI/WiX payload.

If the MSI hides its native ARP entry and writes a custom one, use `$Info.AppsAndFeaturesInstallerType` and `$Info.AppsAndFeaturesProductCode` from MSI parsing. Validate in a VM when the wrapper controls visibility.

For InstallScript-only media, use `$Info.InstallScriptInfo.AppsAndFeaturesEntries` as ARP evidence. Explicit uninstall registry writes and complete `RegDBSetItem` values are stronger than `Setup.ini` defaults. Preserve existing `DisplayVersion`, `Scope`, and `DefaultInstallLocation` when the returned fields remain null. Custom assignments to `IFX_*`, `UNINSTALL_*`, `ALLUSERS`, `TARGETDIR`, or `ADDREMOVE_SYSTEMCOMPONENT` can still change or hide the entry, so never turn unresolved values into stronger claims than the parser returns.

For Advanced UI, use `$Info.AdvancedUiInfo.ProductCode` (the `SuiteId`) for the outer EXE entry. Nested MSI `ProductCode`/`UpgradeCode` values are relevant only when the nested MSI owns a visible ARP entry. When a parcel operation contains `ARPSYSTEMCOMPONENT=1`, the nested MSI entry is intentionally hidden and the suite's EXE ARP entry remains the visible owner.

## Validate silent support and nested behavior

If no MSI can be extracted and the installer is InstallScript-only, inspect `$Info.InstallScriptInfo`. Accept `Supported` when the media embeds a valid default response file. Block `ResponseFileRequired`; validate `Indeterminate` in the VM. Do not infer support merely because `/s`, dialog names, or response-runtime strings occur in the compiled script.

For deep analysis or future response-file authoring, reuse the extracted `setup.inx` path and inspect the IR separately:

```powershell
$Program = Read-InstallShieldInstallScriptProgram -Path $Info.InstallScriptInfo.CompiledScriptPath
$Traces = @(Get-InstallShieldInstallScriptDialogTrace -Program $Program)
$FreshInstall = $Traces | Where-Object Scenario -EQ 'FreshInstall'

$Template = New-InstallShieldResponseFileTemplate `
  -Trace $FreshInstall `
  -ProductCode $Info.InstallScriptInfo.ProjectProductCode

$Template.Content
$Template.Warnings
```

The template generator fills only documented generic keys such as `Result`, `szDir`, `bOpt1`, `bOpt2`, and `BootOption`. Feature-tree/custom dialogs and unresolved branches are emitted as TODO evidence. Never remove those warnings or invent project-specific values. Validate a recorded or reviewed file structurally before VM use:

```powershell
Test-InstallShieldResponseFile -Path .\setup.iss -Trace $FreshInstall
```

These helpers assist analysis and authoring; they do not make response-file-dependent installers acceptable to winget-pkgs today.
