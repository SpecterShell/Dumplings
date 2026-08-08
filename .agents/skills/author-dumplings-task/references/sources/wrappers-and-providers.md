# Redirects, wrappers, providers, and browser sources

See the [task example index](../example-index.md) for current implementations of these patterns.

## Redirected Installer URLs

Use redirect helpers to resolve the official target without downloading the installer. `360.360Ent` is the compact case:

```powershell
$this.CurrentState.Installer += [ordered]@{ InstallerUrl = Get-RedirectedUrl -Uri $DownloadEndpoint -Method GET }
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value
```

Reject an empty version and verify that the resolved host remains official. `Xmind.Xmind` resolves x64 and ARM64 separately, compares their versions, and uses `WinGetReplaceMode` when one architecture lags. `Anthropic.Claude` demonstrates separate redirect endpoints for EXE/MSIX and architectures.

## Custom EXE Wrappers With Nested MSI

Use this fallback when a proprietary or custom EXE wrapper is not supported by PackageModule and the nested MSI contains the authoritative version or ARP identity. First run the installer analyzer and the applicable family parser. Do not use 7z when Dumplings already has a source-backed extractor for that outer format. This narrow task-side fallback does not permit reusable installer parsers, bridges, analyzers, tests, or CI parser paths to depend on 7-Zip, NanaZip, or another external parser executable.

List the wrapper contents before writing the task, then select the exact nested file that the wrapper installs. A first `*.msi` match is unsafe when the wrapper contains prerequisites, language packs, or architecture-specific packages. Confirm the mapping from the wrapper configuration, archive layout, MSI summary information, and `Get-MsiInstallerInfo` evidence.

### 7-Zip parser-mode examples

Use quoted `'-t#'` only after ordinary listing or the installer analyzer shows that the proprietary wrapper needs 7-Zip's parser view. Parser mode scans for embedded supported streams and can expose positional names such as `2.msi`, `3.msp`, or `2.wrapper_jre_offline.exe`. Always list the exact current artifact first because these names can change between releases:

```powershell
7z.exe l -ba -slt '-t#' $OuterPath | Out-Host
```

`DuoSecurity.Duo2FAAuthenticationforWindows` demonstrates multiple architecture-specific MSI streams, and the Foxit tasks demonstrate an MSI plus an optional MSP:

```powershell
7z.exe e -aoa -ba -bd -y '-t#' -o"${ExtractedPath}" $OuterPath '2.msi' '3.msi' '4.msi' | Out-Host
7z.exe e -aoa -ba -bd -y '-t#' -o"${ExtractedPath}" $OuterPath '2.msi' '3.msp' | Out-Host
```

The Altova tasks extract a CAB through parser mode and then open the CAB with ordinary archive detection. `Oracle.JavaRuntimeEnvironment` performs two parser passes through an embedded EXE before reaching the MSI:

```powershell
7z.exe e -aoa -ba -bd -y '-t#' -o"${OuterDirectory}" $OuterPath '*.cab' | Out-Host
7z.exe e -aoa -ba -bd -y -o"${CabDirectory}" $CabPath '*.msi' | Out-Host
7z.exe e -aoa -ba -bd -y '-t#' -o"${OuterDirectory}" $OuterPath '2.wrapper_jre_offline.exe' | Out-Host
7z.exe e -aoa -ba -bd -y '-t#' -o"${InnerDirectory}" $NestedExePath '2.msi' | Out-Host
```

Check `$LASTEXITCODE` and each expected path after every command. Parse each MSI once with `Get-MsiInstallerInfo`, verify its `PackageArchitecture`, ProductCode, and UpgradeCode, and do not map architecture from parser-stream order alone. See the installer-analysis [7-Zip diagnostics](../../../analyze-winget-installer/references/workflows/installer-analysis.md#2-run-static-analysis) for the parser boundary and safety rules.

For one named MSI payload, keep the outer installer in PackageTask's cache and parse the extracted database once:

```powershell
$Installer = $this.CurrentState.Installer[0]
$Url = $Installer.InstallerUrl
$this.InstallerFiles[$Url] = $OuterPath = Get-TempFile -Uri $Url
$ExtractedPath = New-TempFolder

try {
  & 7z.exe e -aoa -ba -bd -y "-o$ExtractedPath" $OuterPath 'ProductSetup.msi' | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "7z failed to extract ProductSetup.msi with exit code $LASTEXITCODE."
  }

  $MsiPath = Join-Path $ExtractedPath 'ProductSetup.msi'
  if (-not (Test-Path -LiteralPath $MsiPath -PathType Leaf)) {
    throw 'The expected nested MSI was not extracted.'
  }

  $MsiInfo = Get-MsiInstallerInfo -Path $MsiPath
  $this.CurrentState.RealVersion = $MsiInfo.DisplayVersion

  # Write parser-owned fields only when the unsupported outer wrapper prevents manifest generation from reaching the MSI and the reference manifest needs those values refreshed.
  $Installer.ProductCode = $MsiInfo.ProductCode
  $Installer.AppsAndFeaturesEntries = @(
    [ordered]@{
      UpgradeCode   = $MsiInfo.UpgradeCode
      InstallerType = $MsiInfo.InstallerType
    }
  )
} finally {
  Remove-Item -LiteralPath $ExtractedPath -Recurse -Force -ErrorAction SilentlyContinue
}
```

Use `DisplayVersion` for the MSI product version. The same result also exposes `DisplayName`, `Publisher`, `ProductCode`, `UpgradeCode`, `InstallerType`, `PackageArchitecture`, install-location evidence, ARP behavior, and registry associations. Reuse these properties instead of calling several `Read-*FromMsi` functions. Omit explicit state fields that the normal manifest updater can refresh from the outer installer.

Extraction rules:

- Check `$LASTEXITCODE` and the expected file after every 7z invocation.
- Use `e` only when flattening one exact file is safe. Use `x` when preserving nested paths avoids collisions or proves which payload was selected.
- Use `-t#` only for a verified raw-section layout where 7z exposes numbered streams such as `2.msi`; those numbers are format observations, not stable MSI identities.
- When several MSIs exist, map each exact payload to its WinGet architecture and compare `PackageArchitecture` with that mapping. Do not infer architecture from extraction order.
- For a nested EXE chain, make a separate bounded extraction directory for each layer and validate every intermediate file before continuing.
- Pass an extracted MSP through `Get-MsiInstallerInfo -PatchPath` when the patch changes the effective ProductVersion or ProductCode represented by the wrapper.
- Remove temporary extraction directories in `finally`. Do not remove the outer file registered in `$this.InstallerFiles`; PackageTask owns that file.
- Keep 7z in task-specific discovery only. Installer parsers and CI-critical static analysis must not invoke or depend on 7-Zip, NanaZip, or another external parser executable.

Open these concrete tasks according to the wrapper layout being analyzed. Their archive paths are useful evidence, but several retain legacy individual readers or manual manifest mutation and should not be copied line for line:

| Wrapper layout | Task examples |
| --- | --- |
| One named MSI | `ALTEC.DataPrint`, `Cisco.WebexWRFtoWMV`, `Cjwdev.ADInfo.Free`, `Texthelp.Equatio` |
| Architecture-specific MSI payloads | `Apple.iTunes`, `dotPDN.PaintDotNet`, `Plenom.kuandoHUB`, `Plenom.kuandoBusylight.Webex` |
| Numbered raw-section MSI streams | `Maximus5.ConEmu`, `DuoSecurity.Duo2FAAuthenticationforWindows`, `Google.EarthPro`, `UCBerkeley.BOINC` |
| Nested EXE followed by MSI | `Siemens.JT2Go`, `Oracle.JavaRuntimeEnvironment`, `PTC.CreoView.Express` |
| Cabinet followed by MSI | `Altova.Authentic.Enterprise`, `Altova.DatabaseSpy.Enterprise`, `Altova.XMLSpy.Professional` |
| MSI with an optional MSP projection | `Foxit.FoxitReader`, `Foxit.PhantomPDF`, `Foxit.PhantomPDF.Subscription.MSI` |

## Shared Provider Tasks

Use a provider when at least three tasks would otherwise fetch the same source. The threshold applies to a shared response or catalog, not merely to tasks from the same publisher. With one or two consumers, keep retrieval in the package tasks. `#Argente` fetches x86, x64, and ARM64 catalogs, and consumers such as `Argente.Utilities` and `Argente.DataShredder` select their own product rows. Consumers verify that architecture variants agree on version before populating installer entries.

`#JetBrains` demonstrates batching many product codes by channel and storing one catalog under `$Global:DumplingsStorage.JetBrainsApps`. Individual `JetBrains.*` tasks select one product/channel and add checksum data and architecture-specific URLs. Do not manually set parser-readable ProductCode or Apps & Features values in new consumers unless current static analysis cannot resolve them.

## Browser-Only Sources

Use browser automation only after ordinary HTTP, source inspection, and official APIs fail. Keep the lease block short and return detached data:

```powershell
$Url = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri $DownloadPage
  $null = Invoke-PlaywrightCloudflareChallenge -Page $Page
  Read-PlaywrightLocator -Page $Page -Selector 'a[href$=".exe"]' -Property Attribute -AttributeName href
}
```

`BLife.CustomCursor` is the current reference. Never return page, locator, or browser objects from `Use-PlaywrightPage`, and do not hold the lease while doing installer parsing or release-note formatting.
