# x86
$Prefix1 = 'https://downloads.zohocdn.com/notebook32-desktop/'
$Object1 = Invoke-RestMethod -Uri "${Prefix1}latest.yml" | ConvertFrom-Yaml
# x64
$Prefix2 = 'https://downloads.zohocdn.com/notebook-desktop/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml" | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("x86 version: $($Object1.version)")
  $this.Log("x64 version: $($Object2.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix1 + $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix2 + $Object2.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
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
