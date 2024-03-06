$Prefix = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/'
$Headers = @{
  platform     = 'win32'
  buildversion = '0'
  version      = '0.0.0'
  uid          = ''
}

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" -Headers $Headers | ConvertFrom-Yaml

if ($Object1.version -eq '0.0.0') {
  $this.Log('The endpoint returned an invalid response', 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri "${Prefix}$($Object1.files[0].url)" -Headers $Headers
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.releaseNotes | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
