$Prefix = 'https://public-cdn.cloud.unity3d.com/hub/prod/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# RealVersion
# Since 3.21.0, Unity Hub encodes the release channel in the fourth field of the MSIX Identity/@Version, mapping GA to 65535 (earlier releases shipped X.Y.Z.0).
# WinGet requires PackageVersion to agree with the MSIX identity, so the manifest version is the four-part encoding while the ARP entries below keep the three-part product version.
if ($Object1.version -match '^\d+\.\d+\.\d+$' -and [System.Version]$Object1.version -ge [System.Version]'3.21.0') {
  $this.CurrentState.RealVersion = "$($Object1.version).65535"
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'nullsoft'
  InstallerUrl           = $InstallerUrl = Join-Uri $Prefix $Object1.files.Where({ $_.url.Contains('x64') }, 'First')[0].url
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName    = "Unity Hub $($Object1.version)"
      DisplayVersion = $Object1.version
      ProductCode    = 'Unity Technologies - Hub'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'arm64'
  InstallerType          = 'nullsoft'
  InstallerUrl           = $InstallerUrl.Replace('x64', 'arm64')
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName    = "Unity Hub $($Object1.version)"
      DisplayVersion = $Object1.version
      ProductCode    = 'Unity Technologies - Hub'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msix'
  InstallerUrl  = $InstallerUrl -replace '\.exe$', '.msix'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msix'
  InstallerUrl  = $InstallerUrl.Replace('x64', 'arm64') -replace '\.exe$', '.msix'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
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
