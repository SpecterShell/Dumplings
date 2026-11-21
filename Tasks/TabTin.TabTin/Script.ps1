$Object1 = Invoke-RestMethod -Uri 'https://api.tabtin.com/api/updates/check' -Method Post -Body (
  @{
    current_version = $this.Status.Contains('New') ? '1.0.0' : $this.LastState.Version
    platform        = 'win'
    arch            = 'x64'
    channel         = 'stable'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if (-not $Object1.data.has_update) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.file_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.release_date.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.release_notes | Format-Text
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
