# x64
$Prefix1 = 'https://presono-desktop-app.s3-eu-west-1.amazonaws.com/'
$Object1 = Invoke-RestMethod -Uri "${Prefix1}latest.yml" | ConvertFrom-Yaml
# arm64
$Prefix2 = 'https://presono-desktop-app-arm.s3-eu-west-1.amazonaws.com/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml" | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("x64 version: $($Object1.version)")
  $this.Log("arm64 version: $($Object2.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri $Prefix1 $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri $Prefix2 $Object2.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $Prefix1 $Object1.files[0].url "presono-Setup.$($this.CurrentState.Version).msi"
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
