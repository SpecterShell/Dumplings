<#
.SYNOPSIS
  A script to download and extract WinGet with VC libs without installing them
.DESCRIPTION
  This script helps you download and extract WinGet client to a folder so you can run it directly
  It is useful when you can't install or use the MSIX package, e.g., in SYSTEM context or in Windows Server
  VC libs are also included so it is able to run under the environment where VCRedist is not globally installed
  Note that currently the executable can only run as administrator.

  Inspired by the WinGet manifest from scoop:
  https://github.com/ScoopInstaller/Main/blob/master/bucket/winget.json
  Great thanks to the contributors
.PARAMETER DestinationPath
  The directory the files are extracted to. Default to the WinGet folder in current directory
.PARAMETER Architecture
  The architecture of the WinGet client (Available options: x86, x64, arm, arm64)
#>

[CmdletBinding()]
param (
  [Parameter(Position = 0, HelpMessage = 'The directory the files are extracted to')]
  [string]
  $DestinationPath = (Join-Path $PWD 'WinGet'),

  [Parameter(Position = 1, HelpMessage = 'The architecture of the WinGet client')]
  [ArgumentCompletions('x86', 'x64', 'arm', 'arm64')]
  [string]
  $Architecture = 'x64'
)

$VCLibsUri = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'

#region Download VCLibs
Write-Host -Object 'Downloading VCLibs'

$VCLibsPath = Join-Path $env:TEMP 'VCLibs.appx'
Invoke-WebRequest -Uri $VCLibsUri -OutFile $VCLibsPath
#endregion

#region Locate WinGet
Write-Host -Object 'Locating the latest WinGet client'

$Params = @{
  Uri         = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
  Headers     = @{ Accept = 'application/vnd.github+json' }
  ContentType = 'application/json'
}
if ($Env:GITHUB_TOKEN) {
  Write-Host 'Detected the environment variable GITHUB_TOKEN'
  $Params.Headers['Authorization'] = "Bearer ${Env:GITHUB_TOKEN}"
}
$WinGetRelease = Invoke-RestMethod @Params
#endregion

#region Download WinGet
Write-Host -Object "Downloading WinGet $($WinGetRelease.tag_name)"

$InstallerUri = $WinGetRelease.assets.Where({ $_.name.EndsWith('.msixbundle') }, 'First')[0].browser_download_url
$InstallerPath = Join-Path $env:TEMP 'AppInstaller.msixbundle'
Invoke-WebRequest -Uri $InstallerUri -OutFile $InstallerPath
#endregion

#region Extract WinGet
Write-Host -Object 'Extracting WinGet'

# Obtain nested installer
$InstallerExtractedPath = Join-Path $env:TEMP "$(Get-Random).tmp"
Expand-Archive -Path $InstallerPath -DestinationPath $InstallerExtractedPath

# Extract VCLibs
Expand-Archive -Path $VCLibsPath -DestinationPath $DestinationPath -Force

# Extract WinGet
$NestedInstallerPath = Join-Path $InstallerExtractedPath "*${Architecture}.msix" -Resolve
Expand-Archive -Path $NestedInstallerPath -DestinationPath $DestinationPath -Force
#endregion

#region Clean environment
Write-Host 'Cleaning environment'
Remove-Item -Path @($VCLibsPath, $InstallerPath, $InstallerExtractedPath) -Recurse -Force
#endregion
