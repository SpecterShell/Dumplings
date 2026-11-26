$Object1 = Invoke-RestMethod -Uri 'https://api.ishell.cc/versions/0'

# Version
$this.CurrentState.Version = $Object1.data.vers

# Installer
# downUrl is a signed OSS address that changes on every request. Use the stable download endpoint instead; it
# redirects to the current build, so an unchanged installer is no longer reported as a URL change.
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://api.ishell.cc/download/0/cn'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.createAt | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.note | Format-Text
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
