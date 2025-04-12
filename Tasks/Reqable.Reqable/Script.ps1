$Object1 = Invoke-RestMethod -Uri 'https://api.reqable.com/version/check?platform=windows&arch=x86_64'

# Version
$this.CurrentState.Version = $Object1.name

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://api.reqable.com/download?platform=windows&arch=x86_64' -Method GET -Headers @{ 'Accept-Language' = 'en' }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.changelogs.'en-US' | Format-Text
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.changelogs.'zh-CN' | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/reqable/reqable-app/releases/tags/$($this.CurrentState.Version)"

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.assets.Where({ $_.name -cmatch '\.exe$' }, 'First')[0].updated_at
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
