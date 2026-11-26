$Object1 = Invoke-RestMethod -Uri 'https://api.ishell.cc/versions/0'

# Version
$this.CurrentState.Version = $Object1.data.vers

# Installer
# The API hands out a signed OSS URL whose Expires and Signature change on every request. Keep only the
# object path so an unchanged installer is not reported as a URL change on every check.
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.downUrl.Split('?')[0]
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
