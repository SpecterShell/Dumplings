# Installer dependencies

## Evidence threshold

Author `Dependencies.PackageDependencies` only when the selected installer or installed application has a hard external prerequisite that WinGet should install separately. Prefer explicit publisher requirements, structured bootstrapper prerequisite records, MSI launch conditions coupled to AppSearch or registry searches, deployment metadata, or a VM result from a clean checkpoint. A filename, product description, imported document format, optional integration, registry association, or arbitrary binary string is not sufficient.

Do not add a package dependency when the selected outer installer already carries, downloads, or installs that prerequisite. If a publisher offers an EXE wrapper that installs prerequisites and a direct nested MSI that does not, either retain the wrapper or use the MSI with every separately required package dependency. Record this decision in transient evidence.

## Common dependency mappings

| Proven requirement | WinGet dependency entry |
| --- | --- |
| Visual C++ 2005, 2008, 2010, 2012, or 2013 runtime with known binary architecture | Matching `Microsoft.VCRedist.<version>.<architecture>` package |
| Visual C++ 2015 or later runtime with known binary architecture | `Microsoft.VCRedist.2015+.x86`, `Microsoft.VCRedist.2015+.x64`, or `Microsoft.VCRedist.2015+.arm64` |
| Framework-dependent .NET 5 or later application | Matching `Microsoft.DotNet.Runtime.<major>`, `Microsoft.DotNet.DesktopRuntime.<major>`, or `Microsoft.DotNet.AspNetCore.<major>` package |
| MSIX/AppX desktop VC framework identity `Microsoft.VCLibs.140.00.UWPDesktop` or `Microsoft.VCLibs.Desktop.14` | `Microsoft.VCLibs.Desktop.14` |
| MSIX/AppX VC framework identity `Microsoft.VCLibs.140.00` or `Microsoft.VCLibs.14` | `Microsoft.VCLibs.14` |
| MSIX/AppX Windows App Runtime framework identity | Matching `Microsoft.WindowsAppRuntime.<major>.<minor>` package; normalize `Microsoft.WindowsAppRuntime.2` to `Microsoft.WindowsAppRuntime.2.0` |
| MSIX/AppX Microsoft UI XAML framework identity | Matching `Microsoft.UI.Xaml.<major>.<minor>` package |
| Visual Studio Tools for Office Runtime | `Microsoft.VSTOR` |
| Installed Microsoft Office desktop suite or an Office host such as Outlook, Word, Excel, or PowerPoint | `Microsoft.Office` |
| Windows .NET Framework 3.5 optional component | `WindowsFeatures: [NetFx3]` |

Use `Get-PEDependencyInfo` for VC runtime imports and .NET deployment metadata. It does not infer VSTO Runtime or Office requirements because those dependencies are normally expressed by installer conditions, prerequisite catalogs, add-in deployment manifests, or publisher documentation rather than PE imports.

## Packaged app framework dependencies

For MSIX/AppX packages, use the dependencies declared in `AppxManifest.xml` or the nested package manifests of a bundle. `Get-MSIXInfo` performs the supported identity mapping and returns manifest-ready entries in `Dependencies`; `Read-DependenciesFromMSIX` provides the same dependency projection when only that field is needed. Prefer one `Get-MSIXInfo` call during full installer analysis so the package is not parsed repeatedly.

```powershell
$Info = Get-MSIXInfo -Path $InstallerFile
$Dependencies = $Info.Dependencies
$UnknownDependencies = $Info.UnknownPackageDependencies
$Diagnostics = $Info.Diagnostics
```

The module maps `Microsoft.VCLibs.140.00.UWPDesktop` to `Microsoft.VCLibs.Desktop.14`, `Microsoft.VCLibs.140.00` to `Microsoft.VCLibs.14`, and the major-only `Microsoft.WindowsAppRuntime.2` identity to `Microsoft.WindowsAppRuntime.2.0`. Versioned `Microsoft.WindowsAppRuntime.<major>.<minor>` and `Microsoft.UI.Xaml.<major>.<minor>` identities already match their WinGet package identifiers and pass through unchanged. Preserve the package manifest's `MinVersion` as `MinimumVersion`.

Review every entry in `UnknownPackageDependencies` and the related warnings. Do not copy an unknown package identity into a WinGet manifest until an accepted WinGet package and a compatible version relationship are established. The allowlist is deliberately narrow because MSIX/AppX manifests may name framework, optional, resource, or publisher-specific packages that winget-pkgs cannot install as package dependencies.

These mappings are authoritative only for dependency identities declared by MSIX/AppX package metadata. For unpackaged EXE, MSI, archive, or portable applications, require structured installer metadata or publisher evidence before adding Windows App Runtime, VCLibs, or Microsoft UI XAML dependencies. Do not infer them from filenames or arbitrary binary strings. Follow the [MSIX and AppX workflow](../../../analyze-winget-installer/references/families/msix-appx/workflow.md) for bundle traversal, signatures, and unknown-dependency handling.

## Visual Studio Tools for Office Runtime

Add `Microsoft.VSTOR` when a VSTO solution or Office add-in requires the separately installed Visual Studio Tools for Office Runtime. Strong evidence includes an explicit prerequisite named Visual Studio Tools for Office Runtime, a VSTO deployment manifest or `VSTOInstaller.exe` route accompanied by a runtime requirement, or an MSI launch condition that blocks installation until the VSTO runtime is detected.

The presence of `.vsto` files, `Microsoft.Office.Tools.*` assemblies, or VSTO registry keys identifies the technology but does not by itself prove that the runtime is absent from the selected installer. Check the outer bootstrapper or chain first. If it installs `vstor_redist.exe` itself, omit `Microsoft.VSTOR` for that wrapper. If the manifest intentionally uses only the nested MSI and the MSI expects VSTO to exist, add the dependency.

## Microsoft Office

Add `Microsoft.Office` when installation or normal operation unconditionally requires the installed Office desktop suite or one of its host applications, including Outlook, Word, Excel, or PowerPoint. Typical evidence is an explicit launch condition, a prerequisite check tied to an Office registry or AppSearch signature, publisher documentation that names the required Office host, or clean-VM validation showing that the installer refuses to continue without Office.

Do not add `Microsoft.Office` merely because an application opens Office document formats, exports to Office formats, offers optional Office integration, or registers an add-in only when Office is present. If only one optional feature needs Office while the main application works without it, record the optional integration in the package description or documentation rather than forcing installation of the full Office package.

A VSTO add-in may require both dependencies: `Microsoft.VSTOR` supplies the add-in runtime, while `Microsoft.Office` supplies the host application. Prove each requirement independently.

## .NET Framework 3.5 Windows feature

Add the Windows feature dependency `NetFx3` when the selected installer or application requires the Windows .NET Framework 3.5 optional component. Strong evidence includes an MSI launch condition or AppSearch check for .NET Framework 3.5, an explicit prerequisite record, publisher system requirements, or clean-VM validation showing that installation or normal startup fails until the feature is enabled.

```yaml
Dependencies:
  WindowsFeatures:
  - NetFx3
```

`NetFx3` covers the Windows component for .NET Framework 2.0, 3.0, and 3.5. Do not use it for .NET Framework 4.x, framework-dependent .NET 5 or later applications, or an arbitrary managed executable. If the selected wrapper enables the Windows feature itself, confirm that behavior and omit the dependency rather than requesting the same prerequisite twice.

## Field placement

Keep dependency arrays at installer level while authoring complete entries. When every installer has the same dependency array, logical-model serialization can move the common value to manifest level. Arrays are atomic: an installer-level `PackageDependencies` or `WindowsFeatures` array replaces rather than extends the corresponding root array.

```yaml
Dependencies:
  PackageDependencies:
  - PackageIdentifier: Microsoft.VSTOR
  - PackageIdentifier: Microsoft.Office
```

Add `MinimumVersion` only when the publisher requirement or structured installer condition provides a lower bound that maps to the WinGet dependency package's version scheme. Do not use the newest available dependency version, the analysis host's installed version, or an unrelated Office build as the minimum.

Dependencies remain author-controlled during Dumplings updates. Parser or VM evidence can justify an intentional change, but the update pipeline must not add, remove, or rewrite `Dependencies` automatically.
