<#
.SYNOPSIS
  Installs the Windows Package Manager (WinGet) from the latest release or a specific version.
.PARAMETER WinGetVersion
  The version of WinGet to use
.PARAMETER Prerelease
  Use the latest prerelease version of WinGet
.NOTES
  Part of the codes in this file were referenced from https://github.com/microsoft/winget-pkgs/blob/master/Tools/SandboxTest.ps1 under the MIT License

  MIT License

  Copyright (c) Microsoft Corporation. All rights reserved.

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE
#>
[CmdletBinding()]
Param(
  [Parameter(HelpMessage = 'The version of WinGet to use')]
  [string] $WinGetVersion,
  [Parameter(HelpMessage = 'Use the latest prerelease version of WinGet')]
  [switch] $Prerelease
)

# Enable strict mode to avoid non-existent or empty properties from the API
Set-StrictMode -Version 3.0

# In CI, hide the progress bar to avoid pollutions to console output
$ProgressPreference = 'SilentlyContinue'
if (Test-Path -Path Env:\CI) { $ProgressPreference = 'SilentlyContinue' }

# Force stop on error
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

#region Get GitHub token
$GitHubParams = @{
  Headers     = @{ Accept = 'application/vnd.github.v3+json' }
  ContentType = 'application/json'
}
if (Test-Path -Path Env:\GITHUB_TOKEN) {
  Write-Host -Object 'GITHUB_TOKEN detected'
  $GitHubParams.Headers.Authorization = "Bearer ${Env:GITHUB_TOKEN}"
}
#endregion

#region Get WinGet releases
if ($WinGetVersion) {
  $WinGetVersion = $WinGetVersion.TrimStart('v')
  $WinGetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/tags/v${WinGetVersion}" @GitHubParams
} elseif ($Prerelease) {
  $WinGetReleases = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases' @GitHubParams
  $WinGetRelease = $WinGetReleases.Where({ $_.prerelease -eq $true }, 'First')[0]
} else {
  $WinGetRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' @GitHubParams
}
#endregion

#region Download WinGet dependencies
$DependenciesPath = @()
$AppInstallerParsedVersion = [System.Version]($WinGetRelease.tag_name -replace '(^v)|(-preview$)')
if ($AppInstallerParsedVersion -ge [System.Version]'1.9.25180') {
  # As of WinGet 1.9.25180, VCLibs no longer publishes to the public URL and must be downloaded from the WinGet release
  $DependenciesArchiveUri = $WinGetRelease.assets.Where({ $_.name -eq 'DesktopAppInstaller_Dependencies.zip' }, 'First')[0].browser_download_url
  $DependenciesArchivePath = Join-Path ([System.IO.Path]::GetTempPath()) 'DesktopAppInstaller_Dependencies.zip'
  Write-Host -Object "Downloading ${DependenciesArchiveUri}"
  Invoke-WebRequest -Uri $DependenciesArchiveUri -OutFile $DependenciesArchivePath

  $DependenciesTempPath = Join-Path ([System.IO.Path]::GetTempPath()) 'DesktopAppInstaller_Dependencies'
  Expand-Archive -Path $DependenciesArchivePath -DestinationPath $DependenciesTempPath -Force
  $DependenciesPath += Join-Path $DependenciesTempPath 'x64' | Get-ChildItem -Include '*.appx' -Recurse -File | Select-Object -ExpandProperty 'FullName'
} else {
  $VCLibsUri = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
  $VCLibsPath = New-TemporaryFile
  Write-Host "Downloading ${VCLibsUri}"
  Invoke-WebRequest -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $VCLibsPath
  $DependenciesPath += $VCLibsPath

  # As of WinGet 1.7.10514 (https://github.com/microsoft/winget-cli/pull/4218), the dependency on uiLibsUwP was bumped from version 2.7.3 to version 2.8.6
  if ($AppInstallerParsedVersion -lt [System.Version]'1.7.10514') {
    $UILibsUri = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx'
  } else {
    $UILibsUri = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
  }
  $UILibsPath = New-TemporaryFile
  Write-Host "Downloading ${UILibsUri}"
  Invoke-WebRequest -Uri $UILibsUri -OutFile $UILibsPath
  $DependenciesPath += $UILibsPath
}
#endregion

#region Download WinGet
$WinGetUri = $WinGetRelease.assets.Where({ $_.name -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle' }, 'First')[0].browser_download_url
$WinGetPath = New-TemporaryFile
Write-Host "Downloading ${WinGetUri}"
Invoke-WebRequest -Uri $WinGetUri -OutFile $WinGetPath
#endregion

#region Download WinGet license
$WinGetLicenseUri = $WinGetRelease.assets.Where({ $_.name.EndsWith('_License1.xml') }, 'First')[0].browser_download_url
$WinGetLicensePath = New-TemporaryFile
Write-Host "Downloading ${WinGetLicenseUri}"
Invoke-WebRequest -Uri $WinGetLicenseUri -OutFile $WinGetLicensePath
#endregion

#region Install WinGet
Write-Host 'Installing WinGet'
$null = Add-AppxProvisionedPackage -Online -PackagePath $WinGetPath -DependencyPackagePath $DependenciesPath -LicensePath $WinGetLicensePath
#endregion

#region Clean up
Write-Host 'Cleaning up'
Remove-Item -Path @($WinGetPath, $WinGetLicensePath, $DependenciesArchivePath) -Force -ErrorAction 'Continue'
#endregion
