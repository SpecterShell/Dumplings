$ProgressPreference = 'SilentlyContinue'

$VCLibsUri = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
$VCLibsPath = New-TemporaryFile
Write-Host "Downloading ${VCLibsUri}"
Invoke-WebRequest -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $VCLibsPath

$UILibsUri = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
$UILibsPath = New-TemporaryFile
Write-Host "Downloading ${UILibsUri}"
Invoke-WebRequest -Uri $UILibsUri -OutFile $UILibsPath

$Params = @{
  Uri         = 'https://api.github.com/repos/microsoft/winget-cli/releases/tags/v1.8.1911'
  Headers     = @{ Accept = 'application/vnd.github+json' }
  ContentType = 'application/json'
}
if ($Env:GITHUB_TOKEN) {
  Write-Host 'GITHUB_TOKEN detected'
  $Params.Headers['Authorization'] = "Bearer ${Env:GITHUB_TOKEN}"
}
$WinGetRelease = Invoke-RestMethod @Params

$WinGetUri = $WinGetRelease.assets.Where({ $_.name.EndsWith('.msixbundle') }, 'First')[0].browser_download_url
$WinGetPath = New-TemporaryFile
Write-Host "Downloading ${WinGetUri}"
Invoke-WebRequest -Uri $WinGetUri -OutFile $WinGetPath

$WinGetLicenseUri = $WinGetRelease.assets.Where({ $_.name.EndsWith('_License1.xml') }, 'First')[0].browser_download_url
$WinGetLicensePath = New-TemporaryFile
Write-Host "Downloading ${WinGetLicenseUri}"
Invoke-WebRequest -Uri $WinGetLicenseUri -OutFile $WinGetLicensePath

Write-Host 'Installing WinGet'
Add-AppxProvisionedPackage -Online -PackagePath $WinGetPath -DependencyPackagePath $VCLibsPath, $UILibsPath -LicensePath $WinGetLicensePath | Out-Null

Write-Host 'Cleaning environment'
Remove-Item -Path @($VCLibsPath, $UILibsPath, $WinGetPath, $WinGetLicensePath) -Force
