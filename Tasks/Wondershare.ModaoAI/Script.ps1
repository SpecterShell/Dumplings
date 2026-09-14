# The stable release index of the Modao AI client
$Object1 = Invoke-RestMethod -Uri 'https://modao.cc/ai/static/aiclient/release-index.json'

# Version
$this.CurrentState.Version = $Object1.platforms.win32.x64.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.platforms.win32.x64.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.publishedAt
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
