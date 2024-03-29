$Prefix = 'https://he3-1309519128.cos.accelerate.myqcloud.com/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest/latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $this.CurrentState.Version + '/' + $Object1.files.Where({ $_.url.Contains('ia32') }, 'First')[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $this.CurrentState.Version + '/' + $Object1.files.Where({ $_.url.Contains('x64') }, 'First')[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

# ReleaseNotes (zh-CN)
if ($Object1.Contains('releaseNotes')) {
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object1.releaseNotes | Format-Text
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
