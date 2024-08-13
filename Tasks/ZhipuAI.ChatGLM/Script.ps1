$Prefix = 'https://sfile.chatglm.cn/apk/xinyu/windows/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object1.files.Where({ $_.url.Contains('ia32') }, 'First')[0].url.Replace('.exe', '_default_full.exe')
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   InstallerUrl = $Prefix + $Object1.files.Where({ $_.url.Contains('x64') }, 'First')[0].url.Replace('.exe', '_default_full.exe')
# }

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
