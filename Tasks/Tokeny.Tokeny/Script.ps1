$Object1 = Invoke-RestMethod -Uri 'https://tokeny-ai.com/app-api/version/latest?softwareCode=tokeny&platform=windows&arch=x86_64'

# Version
$this.CurrentState.Version = $Object1.data.latestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://tokeny-ai.com/app-api/version/download?softwareCode=tokeny&platform=windows&arch=x86_64'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetimeoffset]::FromUnixTimeMilliseconds([long]$Object1.data.publishTime).UtcDateTime

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.changelog | Convert-MarkdownToHtml | Get-TextContent | Format-Text
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
