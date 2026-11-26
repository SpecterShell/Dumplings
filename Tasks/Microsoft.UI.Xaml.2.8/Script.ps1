$PackageLine = '2.8'
$NestedAppxPattern = 'tools/AppX/*/Release/*.appx'
$Architectures = @('x64', 'x86', 'arm', 'arm64')

# Version
$NuGetVersions = (Invoke-RestMethod -Uri 'https://api.nuget.org/v3-flatcontainer/microsoft.ui.xaml/index.json').versions |
  Where-Object -FilterScript { $_ -match "^$([regex]::Escape($PackageLine))\.\d+$" }
$NuGetVersion = [string]($NuGetVersions | Sort-Object -Property { [ChunkVersion]$_ } -Bottom 1)
if ([string]::IsNullOrWhiteSpace($NuGetVersion)) {
  $this.Log("No stable Microsoft.UI.Xaml ${PackageLine} package found on nuget.org.", 'Error')
  return
}
$this.CurrentState.Version = $NuGetVersion

$InstallerUrl = "https://api.nuget.org/v3-flatcontainer/microsoft.ui.xaml/${NuGetVersion}/microsoft.ui.xaml.${NuGetVersion}.nupkg"

# Installer
# One entry per architecture; each selects a different nested AppX inside the same .nupkg archive.
foreach ($Architecture in $Architectures) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture         = $Architecture
    InstallerType        = 'zip'
    NestedInstallerType  = 'appx'
    NestedInstallerFiles = @(
      [ordered]@{
        RelativeFilePath = "tools\AppX\$Architecture\Release\Microsoft.UI.Xaml.2.8.appx"
      }
    )
    InstallerUrl         = $InstallerUrl
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
    $ExtractedPath = Expand-TempArchive -Path $InstallerFile -Name $NestedAppxPattern -CollisionAction Error
    try {
      # RealVersion
      $AppxInfo = for ($Index = 0; $Index -lt $Architectures.Count; $Index++) {
        $Architecture = $Architectures[$Index]
        $AppxDirectory = Join-Path $ExtractedPath "tools\AppX\$Architecture\Release"
        $AppxFile = @(Get-ChildItem -LiteralPath $AppxDirectory -Filter '*.appx' -File -ErrorAction 'SilentlyContinue')[0]
        if (-not $AppxFile) {
          $this.Log("The nested AppX for $Architecture is missing from $InstallerUrl.", 'Error')
          return
        }

        $Info = Get-MSIXInfo -Path $AppxFile.FullName -InstallerTypeHint 'appx'
        if ($Info.Architecture -ne $Architecture) {
          $this.Log("The nested AppX at tools\AppX\$Architecture\Release\$($AppxFile.Name) reports architecture $($Info.Architecture).", 'Error')
          return
        }

        # SignatureSha256 of a nested AppX is the hash of its own AppxSignature.p7x.
        $this.CurrentState.Installer[$Index].SignatureSha256 = Get-MSIXSignatureHash -Path $AppxFile.FullName

        $Info
      }

      $IdentityNames = @($AppxInfo.IdentityName | Sort-Object -Unique)
      $IdentityVersions = @($AppxInfo.IdentityVersion | Sort-Object -Unique)
      $PackageFamilyNames = @($AppxInfo.PackageFamilyName | Sort-Object -Unique)
      $ExpectedIdentifier = [string]$this.Config.WinGetIdentifier
      if ($IdentityNames.Count -ne 1 -or $IdentityVersions.Count -ne 1 -or $PackageFamilyNames.Count -ne 1) {
        $this.Log("Inconsistent nested AppX identity: name $($IdentityNames -join ','), version $($IdentityVersions -join ','), family $($PackageFamilyNames -join ',').", 'Error')
        return
      }
      if ($IdentityNames[0] -ne $ExpectedIdentifier) {
        $this.Log("The nested AppX identity name $($IdentityNames[0]) does not match $ExpectedIdentifier.", 'Error')
        return
      }

      $this.CurrentState.RealVersion = [string]$IdentityVersions[0]
    } finally {
      Remove-Item -LiteralPath $ExtractedPath -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

    try {
      # ReleaseTime
      $Registration = Invoke-RestMethod -Uri "https://api.nuget.org/v3/registration5-semver1/microsoft.ui.xaml/${NuGetVersion}.json"
      $this.CurrentState.ReleaseTime = [System.DateTimeOffset]::Parse($Registration.published, [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
