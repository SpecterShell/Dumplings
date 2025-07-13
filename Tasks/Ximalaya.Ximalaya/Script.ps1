$Prefix = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/'
$Headers = @{
  platform     = 'win32'
  buildversion = '0'
  version      = '0.0.0'
  uid          = ''
}

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" -Headers $Headers | ConvertFrom-Yaml

if ($Object1.version -eq '0.0.0') {
  $this.Log('The endpoint returned an invalid response', 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri "${Prefix}$($Object1.files[0].url)" -Headers $Headers
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseNotes | Format-Text
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
  }
  'Updated' {
    $this.Submit()
  }
}
