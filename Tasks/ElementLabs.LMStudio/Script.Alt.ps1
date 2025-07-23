$Prefix = 'https://updates.lmstudio.ai/'

# x64
$Object1 = Invoke-RestMethod -Uri "${Prefix}win32-x64-stable.yml" | ConvertFrom-Yaml
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+(-\d+)?)').Groups[1].Value

# arm64
$Object2 = Invoke-RestMethod -Uri "${Prefix}win32-arm64-stable.yml" | ConvertFrom-Yaml
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $Object2.files[0].url
}
$VersionARM64 = [regex]::Match($InstallerARM64.InstallerUrl, '(\d+(?:\.\d+)+(-\d+)?)').Groups[1].Value

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# RealVersion
$this.CurrentState.RealVersion = $Object1.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if ($Global:DumplingsStorage.Contains('LMStudio') -and $Global:DumplingsStorage.LMStudio.Contains($this.CurrentState.RealVersion)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.LMStudio[$this.CurrentState.RealVersion].ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
