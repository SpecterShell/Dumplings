$Object1 = (
  Invoke-WebRequest -Uri 'https://api.xtool.com/efficacy/v1/package/version/latest' -Method Post -Body (
    @{
      domain         = 'atomm'
      region         = 'en'
      contentId      = 'xTool_win'
      contentVersion = $this.Status.Contains('New') ? '1.0.14' : $this.LastState.Version
      deviceId       = ''
    } | ConvertTo-Json -Compress
  ) -ContentType 'application/json'
).Content | ConvertFrom-Json -AsHashtable

if ($Object1.data.Count -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.contents.Where({ $_.url.EndsWith('.exe') }, 'First')[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.publishTime | ConvertFrom-UnixTimeSeconds

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.description.en | Format-Text
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.description.zh | Format-Text
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
