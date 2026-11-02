# $Prefix = 'https://download.qoder.com/qoder-app/releases/'
$Prefix = 'https://download.qoder.com.cn/qoder-app/releases/'
# User
$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml
# Machine
$Object2 = Invoke-RestMethod -Uri "${Prefix}latest-system.yml" | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("Inconsistent versions: user: $($Object1.version), machine: $($Object2.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'user'
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'machine'
  InstallerUrl = Join-Uri $Prefix $Object2.files[0].url
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
